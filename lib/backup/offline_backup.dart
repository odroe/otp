import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:hotp/hotp.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/key_derivators/argon2.dart';
import 'package:pointycastle/pointycastle.dart' hide Algorithm;

import '../entities/account.entity.dart';
import '../entities/parse_account.dart';

/// One stable account identity and its configuration in display order.
class BackupEntry(final String id, final AccountEntity account) {}

enum BackupProtection() {
  plaintext,
  password,
}

/// Version 1 wire format: 8-byte magic, 1-byte mode, 4-byte big-endian payload
/// length; encrypted mode then has a 16-byte salt and 12-byte nonce. The body is
/// UTF-8 JSON followed by SHA-256 (plaintext) or AES-256-GCM ciphertext and a
/// 16-byte tag (encrypted). The complete header is authenticated as GCM AAD.
/// Version 1 fixes Argon2id v1.3 at 32 MiB, 3 iterations and one lane; the
/// fixed parameters avoid accepting attacker-controlled work factors. Plaintext
/// checksums detect accidents, not malicious modification or sender identity.
/// The JSON payload is an array of ten-element arrays, in display order:
/// `[id, issuer, name, secret, type, algorithm, digits, period, counter, format]`.
/// `name` and `counter` may be null; `secret` is Base32 text; `type` is `TOTP`
/// or `HOTP`; `algorithm` is `sha1`, `sha256`, or `sha512`; `format` is
/// `decimal` or `steam`. `digits` and `period` are integers; `counter` is a
/// decimal string or null so large counters are not rounded by JSON consumers.
/// App-lock credentials
/// are not part of this format. Unknown versions and fields are rejected.
/// Password operations run outside the UI isolate.
abstract final class OfflineBackup() {
  /// Reads the declared mode and validates framing, but does not authenticate
  /// contents. Consumers must still call [decode] before trusting any data.
  static BackupProtection protection(Uint8List bytes) => _protection(bytes);

  static Future<Uint8List> encode(
    List<BackupEntry> entries, {
    String? password,
  }) => Isolate.run(() => _encode(entries, password));

  static Future<List<BackupEntry>> decode(
    Uint8List bytes, {
    String? password,
  }) => Isolate.run(() => _decode(bytes, password));
}

const _magic = [0x4f, 0x41, 0x42, 0x4b, 0x55, 0x50, 0x01, 0x00];
const _maxPayload = 2 * 1024 * 1024;
const _maxEntries = 1000;

Uint8List _encode(List<BackupEntry> entries, String? password) {
  final payload = _encodePayload(entries);
  if (payload.length > _maxPayload) {
    payload.fillRange(0, payload.length, 0);
    throw const FormatException('Backup is too large.');
  }
  final encrypted = password != null;
  final salt = encrypted ? _randomBytes(16) : Uint8List(0);
  final nonce = encrypted ? _randomBytes(12) : Uint8List(0);
  final header = Uint8List(_magic.length + 5 + salt.length + nonce.length);
  header.setRange(0, _magic.length, _magic);
  header[_magic.length] = encrypted ? 1 : 0;
  ByteData.sublistView(header).setUint32(_magic.length + 1, payload.length);
  header.setRange(_magic.length + 5, _magic.length + 5 + salt.length, salt);
  header.setRange(_magic.length + 5 + salt.length, header.length, nonce);
  try {
    if (!encrypted) {
      final checksum = hashes.sha256.convert([...header, ...payload]).bytes;
      return Uint8List.fromList([...header, ...payload, ...checksum]);
    }
    final key = _derive(password, salt);
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(key), 128, nonce, header));
      return Uint8List.fromList([...header, ...cipher.process(payload)]);
    } finally {
      key.fillRange(0, key.length, 0);
    }
  } finally {
    payload.fillRange(0, payload.length, 0);
  }
}

List<BackupEntry> _decode(Uint8List input, String? password) {
  final protection = _protection(input);
  final mode = protection == .password ? 1 : 0;
  final length = ByteData.sublistView(input).getUint32(_magic.length + 1);
  final headerLength = _magic.length + 5 + (mode == 1 ? 28 : 0);
  final header = Uint8List.sublistView(input, 0, headerLength);
  Uint8List payload;
  if (mode == 0) {
    if (password != null) {
      throw const FormatException('This backup is not password-protected.');
    }
    payload = Uint8List.sublistView(input, headerLength, headerLength + length);
    final expected = hashes.sha256.convert([...header, ...payload]).bytes;
    final actual = input.sublist(headerLength + length);
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ actual[i];
    }
    if (difference != 0)
      throw const FormatException('Backup checksum does not match.');
  } else {
    if (password == null)
      throw const FormatException('A backup password is required.');
    final salt = Uint8List.sublistView(
      input,
      _magic.length + 5,
      _magic.length + 21,
    );
    final nonce = Uint8List.sublistView(
      input,
      _magic.length + 21,
      headerLength,
    );
    final key = _derive(password, salt);
    try {
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), 128, nonce, header));
      payload = cipher.process(Uint8List.sublistView(input, headerLength));
    } on InvalidCipherTextException {
      throw const FormatException('Incorrect password or damaged backup.');
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
  try {
    return _decodePayload(payload);
  } finally {
    if (mode == 1) payload.fillRange(0, payload.length, 0);
  }
}

BackupProtection _protection(Uint8List input) {
  if (input.length < _magic.length + 5 + 16 ||
      input.length > _maxPayload + 128) {
    throw const FormatException('Invalid backup size.');
  }
  for (var i = 0; i < _magic.length; i++) {
    if (input[i] != _magic[i])
      throw const FormatException('Unsupported backup version.');
  }
  final mode = input[_magic.length];
  if (mode != 0 && mode != 1)
    throw const FormatException('Unsupported backup mode.');
  final length = ByteData.sublistView(input).getUint32(_magic.length + 1);
  if (length > _maxPayload) throw const FormatException('Backup is too large.');
  final headerLength = _magic.length + 5 + (mode == 1 ? 28 : 0);
  final trailerLength = mode == 1 ? 16 : 32;
  if (input.length != headerLength + length + trailerLength) {
    throw const FormatException('Invalid backup length.');
  }
  return mode == 1 ? .password : .plaintext;
}

Uint8List _derive(String password, Uint8List salt) {
  final input = Uint8List.fromList(utf8.encode(password));
  if (input.isEmpty || input.length > 1024) {
    input.fillRange(0, input.length, 0);
    throw const FormatException(
      'Backup password must contain 1 to 1024 UTF-8 bytes.',
    );
  }
  final params = Argon2Parameters(
    Argon2Parameters.ARGON2_id,
    Uint8List.fromList(salt),
    desiredKeyLength: 32,
    memory: 32768,
    iterations: 3,
    lanes: 1,
    version: Argon2Parameters.ARGON2_VERSION_13,
  );
  try {
    return (Argon2BytesGenerator()..init(params)).process(input);
  } finally {
    input.fillRange(0, input.length, 0);
    params.salt.fillRange(0, params.salt.length, 0);
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

Uint8List _encodePayload(List<BackupEntry> entries) {
  if (entries.length > _maxEntries)
    throw const FormatException('Too many accounts.');
  final ids = <String>{};
  final records = <List<Object?>>[];
  for (final entry in entries) {
    _validateEntry(entry, ids);
    final a = entry.account;
    records.add([
      entry.id,
      a.issuer,
      a.name,
      a.secret,
      a.type.name,
      a.algorithm.name,
      a.digits,
      a.period,
      a.counter?.toString(),
      a.format.name,
    ]);
  }
  // Fixed-position arrays avoid ambiguous duplicate object keys. List order is
  // the portable account ordering; whitespace and equivalent escapes are valid.
  return Uint8List.fromList(utf8.encode(jsonEncode(records)));
}

List<BackupEntry> _decodePayload(Uint8List payload) {
  try {
    final text = utf8.decode(payload);
    _checkJsonDepth(text);
    final decoded = jsonDecode(text);
    if (decoded is! List || decoded.length > _maxEntries) {
      throw const FormatException('Invalid backup payload.');
    }
    final result = <BackupEntry>[];
    final ids = <String>{};
    for (final record in decoded) {
      if (record is! List ||
          record.length != 10 ||
          record[0] is! String ||
          record[1] is! String ||
          (record[2] != null && record[2] is! String) ||
          record[3] is! String ||
          record[4] is! String ||
          record[5] is! String ||
          record[6] is! int ||
          record[7] is! int ||
          (record[8] != null && record[8] is! String) ||
          record[9] is! String) {
        throw const FormatException('Invalid account record.');
      }
      final account = AccountEntity()
        ..issuer = record[1] as String
        ..name = record[2] as String?
        ..secret = record[3] as String
        ..type = AccountType.values.byName(record[4] as String)
        ..algorithm = Algorithm.values.byName(record[5] as String)
        ..digits = record[6] as int
        ..period = record[7] as int
        ..counter = _parseCounter(record[8] as String?)
        ..format = OtpFormat.values.byName(record[9] as String);
      final entry = BackupEntry(record[0] as String, account);
      _validateEntry(entry, ids);
      result.add(entry);
    }
    return List.unmodifiable(result);
  } catch (_) {
    // A decoder exception can contain the original data, including secrets.
    throw const FormatException('Invalid or unsupported backup payload.');
  }
}

int? _parseCounter(String? value) {
  if (value == null) return null;
  if (value.length > 19 || !RegExp(r'^[0-9]+$').hasMatch(value)) {
    throw const FormatException('Invalid counter.');
  }
  final parsed = BigInt.parse(value);
  if (parsed > BigInt.from(Hotp.maxCounter))
    throw const FormatException('Unsupported counter.');
  return parsed.toInt();
}

void _checkJsonDepth(String text) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (final char in text.codeUnits) {
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == 0x5c) {
        escaped = true;
      } else if (char == 0x22) {
        inString = false;
      }
    } else if (char == 0x22) {
      inString = true;
    } else if (char == 0x5b) {
      if (++depth > 2) throw const FormatException('Invalid backup nesting.');
    } else if (char == 0x5d) {
      if (--depth < 0) throw const FormatException('Invalid backup nesting.');
    } else if (char == 0x7b || char == 0x7d) {
      throw const FormatException('Invalid backup structure.');
    }
  }
  if (inString || depth != 0)
    throw const FormatException('Invalid backup structure.');
}

void _validateEntry(BackupEntry entry, Set<String> ids) {
  final a = entry.account;
  if (entry.id.isEmpty ||
      entry.id.length > 1024 ||
      !_validUnicode(entry.id) ||
      !ids.add(entry.id) ||
      a.issuer.length > 1024 ||
      !_validUnicode(a.issuer) ||
      (a.name?.length ?? 0) > 1024 ||
      (a.name != null && !_validUnicode(a.name!)) ||
      (a.issuer.isEmpty && (a.name?.isEmpty ?? true)) ||
      a.secret.length > maxSecretLength ||
      !RegExp(r'^[A-Za-z2-7]+={0,6}$').hasMatch(a.secret) ||
      (a.type == .TOTP && a.counter != null) ||
      (a.type == .HOTP && a.counter == null)) {
    throw const FormatException('Invalid account record.');
  }
  try {
    validateAccount(a);
  } catch (_) {
    throw const FormatException('Invalid account record.');
  }
}

bool _validUnicode(String value) {
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff)
        return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}
