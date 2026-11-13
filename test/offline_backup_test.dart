import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:authenticator/backup/offline_backup.dart';
import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/entities/account_code.dart';
import 'package:authenticator/entities/parse_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotp/hotp.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:pointycastle/key_derivators/argon2.dart';
import 'package:pointycastle/pointycastle.dart' hide Algorithm;

void main() {
  Uint8List plainFixture(Object payload) {
    final body = utf8.encode(jsonEncode(payload));
    final header = Uint8List.fromList([
      0x4f,
      0x41,
      0x42,
      0x4b,
      0x55,
      0x50,
      1,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    ByteData.sublistView(header).setUint32(9, body.length);
    return Uint8List.fromList([
      ...header,
      ...body,
      ...hashes.sha256.convert([...header, ...body]).bytes,
    ]);
  }

  test('Argon2id implementation matches RFC 9106 section 5.3', () {
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      Uint8List.fromList(List.filled(16, 2)),
      desiredKeyLength: 32,
      iterations: 3,
      memory: 32,
      lanes: 4,
      secret: Uint8List.fromList(List.filled(8, 3)),
      additional: Uint8List.fromList(List.filled(12, 4)),
    );
    final result = (Argon2BytesGenerator()..init(parameters)).process(
      Uint8List.fromList(List.filled(32, 1)),
    );
    expect(
      result.map((x) => x.toRadixString(16).padLeft(2, '0')).join(),
      '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
    );
  });
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  List<BackupEntry> fixtures() => [
    BackupEntry(
      'legacy-key',
      accountFromFields(
        type: .TOTP,
        issuer: 'Acme',
        name: 'alice',
        secret: secret,
        algorithm: 'SHA256',
        digits: '8',
        period: '60',
      ),
    ),
    BackupEntry(
      'hotp-key',
      accountFromFields(
        type: .HOTP,
        issuer: 'Acme',
        name: 'bob',
        secret: secret,
        counter: '7',
      ),
    ),
    BackupEntry(
      'steam-key',
      accountFromFields(
        type: .TOTP,
        issuer: 'Steam',
        name: 'carol',
        secret: secret,
        format: .steam,
      ),
    ),
  ];
  for (final password in <String?>[null, 'correct horse battery staple']) {
    test(
      'round trips all formats and order (${password == null ? 'plaintext' : 'encrypted'})',
      () async {
        final original = fixtures();
        final bytes = await OfflineBackup.encode(original, password: password);
        expect(
          OfflineBackup.protection(bytes),
          password == null
              ? BackupProtection.plaintext
              : BackupProtection.password,
        );
        final decoded = await OfflineBackup.decode(bytes, password: password);
        expect(decoded.map((e) => e.id), [
          'legacy-key',
          'hotp-key',
          'steam-key',
        ]);
        final instant = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
        for (var i = 0; i < original.length; i++) {
          expect(
            accountCode(decoded[i].account, at: instant),
            accountCode(original[i].account, at: instant),
          );
          expect(decoded[i].account.counter, original[i].account.counter);
          expect(decoded[i].account.format, original[i].account.format);
        }
        if (password != null)
          expect(
            utf8.decode(bytes, allowMalformed: true),
            isNot(contains(secret)),
          );
      },
    );
  }
  for (final (name, password) in [
    ('plaintext', null),
    ('encrypted', 'fixture-password'),
  ]) {
    test('reads portable version 1 $name fixture', () async {
      final encoded = await File('test/fixtures/backup_v1_$name.b64')
          .readAsString();
      final entries = await OfflineBackup.decode(
        base64.decode(encoded.trim()),
        password: password,
      );
      expect(entries.single.id, 'fixture');
      expect(entries.single.account.issuer, 'RFC fixture');
      expect(
        accountCode(
          entries.single.account,
          at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
        ),
        '287082',
      );
    });
  }
  test('wrong password and tampering fail without returning data', () async {
    final bytes = await OfflineBackup.encode(
      fixtures(),
      password: 'right password',
    );
    await expectLater(
      OfflineBackup.decode(bytes, password: 'wrong password'),
      throwsFormatException,
    );
    await expectLater(OfflineBackup.decode(bytes), throwsFormatException);
    for (final index in [13, 28, 41, bytes.length - 1]) {
      final changed = Uint8List.fromList(bytes)..[index] ^= 1;
      await expectLater(
        OfflineBackup.decode(changed, password: 'right password'),
        throwsFormatException,
      );
    }
  });
  test('plaintext checksum detects accidental changes', () async {
    final bytes = await OfflineBackup.encode(fixtures());
    await expectLater(
      OfflineBackup.decode(bytes, password: 'expected password'),
      throwsFormatException,
    );
    final changed = Uint8List.fromList(bytes)..[15] ^= 1;
    await expectLater(OfflineBackup.decode(changed), throwsFormatException);
  });
  test(
    'rejects duplicate identities, bad account records and empty password',
    () async {
      final first = fixtures().first;
      await expectLater(
        OfflineBackup.encode([first, first]),
        throwsFormatException,
      );
      await expectLater(
        OfflineBackup.encode(fixtures(), password: ''),
        throwsFormatException,
      );
      final invalid = AccountEntity()
        ..type = .TOTP
        ..issuer = 'X'
        ..secret = 'bad!'
        ..digits = 6
        ..period = 30;
      await expectLater(
        OfflineBackup.encode([BackupEntry('invalid', invalid)]),
        throwsFormatException,
      );
    },
  );
  test(
    'preserves legacy Base32 and Unicode labels without normalization',
    () async {
      final legacy = AccountEntity()
        ..type = .TOTP
        ..issuer = '服务 🐇'
        ..name = '用户'
        ..secret = 'mz======'
        ..digits = 6
        ..period = 30;
      final decoded = await OfflineBackup.decode(
        await OfflineBackup.encode([BackupEntry('旧键', legacy)]),
      );
      expect(decoded.single.id, '旧键');
      expect(decoded.single.account.issuer, '服务 🐇');
      expect(decoded.single.account.secret, 'mz======');
      final instant = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
      expect(
        accountCode(decoded.single.account, at: instant),
        accountCode(legacy, at: instant),
      );
    },
  );
  test(
    'preserves identities generated from maximum-length escaped labels',
    () async {
      final issuer = List.filled(1024, '\n').join();
      final name = List.filled(1024, '\t').join();
      final id = jsonEncode([issuer, name]);
      final account = accountFromFields(
        type: .TOTP,
        issuer: issuer,
        name: name,
        secret: secret,
      );
      final restored = await OfflineBackup.decode(
        await OfflineBackup.encode([BackupEntry(id, account)]),
      );
      expect(restored.single.id, id);
      expect(restored.single.account.issuer, issuer);
      expect(restored.single.account.name, name);
    },
  );
  test('large HOTP counters are encoded as decimal strings', () async {
    final account = accountFromFields(
      type: .HOTP,
      issuer: 'Acme',
      secret: secret,
      counter: Hotp.maxCounter.toString(),
    );
    final bytes = await OfflineBackup.encode([BackupEntry('large', account)]);
    final length = ByteData.sublistView(bytes).getUint32(9);
    final json =
        jsonDecode(utf8.decode(bytes.sublist(13, 13 + length))) as List;
    expect((json.single as List)[8], Hotp.maxCounter.toString());
    final restored = await OfflineBackup.decode(bytes);
    expect(restored.single.account.counter, Hotp.maxCounter);
  });
  test('rejects truncated, oversized and unknown envelopes', () async {
    final bytes = await OfflineBackup.encode(fixtures());
    await expectLater(
      OfflineBackup.decode(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
      throwsFormatException,
    );
    final changed = Uint8List.fromList(bytes)..[6] = 99;
    await expectLater(OfflineBackup.decode(changed), throwsFormatException);
    await expectLater(
      OfflineBackup.decode(Uint8List(2 * 1024 * 1024 + 129)),
      throwsFormatException,
    );
  });
  test(
    'rejects malformed account structures even with a valid checksum',
    () async {
      const publicSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
      final valid = [
        'id',
        'Acme',
        'alice',
        publicSecret,
        'TOTP',
        'sha1',
        6,
        30,
        null,
        'decimal',
      ];
      for (final payload in [
        [valid.sublist(0, 9)],
        [
          [...valid, 'unknown'],
        ],
        [valid, valid],
        [
          [...valid.take(4), 'UNKNOWN', ...valid.skip(5)],
        ],
        {
          'accounts': [valid],
        },
      ]) {
        await expectLater(
          OfflineBackup.decode(plainFixture(payload)),
          throwsFormatException,
        );
      }
    },
  );
}
