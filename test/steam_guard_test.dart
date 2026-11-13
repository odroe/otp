import 'dart:io';

import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/entities/account_code.dart';
import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  for (final (seconds, expected) in [
    (0, 'GG5F5'),
    (59, 'PV9M4'),
    (60, 'B26KJ'),
    (1111111111, '5PP3V'),
    (20000000000, 'R5DMB'),
  ]) {
    test('Steam Guard fixture at $seconds seconds', () {
      final account = accountFromFields(
        type: .TOTP,
        issuer: 'Steam',
        secret: secret,
        format: .steam,
      );
      final instant = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      );
      expect(accountCode(account, at: instant), expected);
      expect(accountCode(account, at: instant.toLocal()), expected);
      expect(
        accountCode(account, at: instant),
        matches(RegExp(r'^[23456789BCDFGHJKMNPQRTVWXY]{5}$')),
      );
    });
  }
  test('Steam label never changes an ordinary TOTP account', () {
    final account = parseAccount('otpauth://totp/Steam:user?secret=$secret');
    expect(account.format, OtpFormat.decimal);
    expect(
      accountCode(
        account,
        at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      ),
      '287082',
    );
  });
  test('invalid Steam settings or credentials are rejected', () {
    expect(() => steamSecretFromBase64('bad!'), throwsFormatException);
    expect(() => steamSecretFromBase64(''), throwsFormatException);
    expect(
      () => accountFromFields(
        type: .HOTP,
        issuer: 'Steam',
        secret: secret,
        format: .steam,
        counter: '0',
      ),
      throwsFormatException,
    );
    expect(
      () => accountFromFields(
        type: .TOTP,
        issuer: 'Steam',
        secret: secret,
        format: .steam,
        algorithm: 'SHA256',
      ),
      throwsFormatException,
    );
    expect(
      () => accountFromFields(
        type: .TOTP,
        issuer: 'Steam',
        secret: 'bad!',
        format: .steam,
      ),
      throwsFormatException,
    );
  });
  testWidgets('manual Steam account survives restart with its format', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('steam-test-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${dir.path}/accounts.sqlite3',
          legacyDirectory: dir.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.tap(find.bySemanticsLabel('Add account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steam'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Service / issuer'),
      'Steam',
    );
    await tester.enterText(
      find.widgetWithText(CupertinoTextField, 'Steam shared secret (Base64)'),
      'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=',
    );
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Steam Guard'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.values.single.format, OtpFormat.steam);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    final reopened = (await tester.runAsync(
      () => AccountStore.open(
        sqlitePath: '${dir.path}/accounts.sqlite3',
        legacyDirectory: dir.path,
        legacyLoader: () async => {},
      ),
    ))!;
    expect(reopened.values.single.format, OtpFormat.steam);
    expect(
      accountCode(
        reopened.values.single,
        at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      ),
      'PV9M4',
    );
    reopened.close();
    await tester.runAsync(() => dir.delete(recursive: true));
  });
}
