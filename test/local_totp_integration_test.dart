import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/entities/parse_account.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:base32/base32.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:totp/totp.dart';

void main() {
  for (final secret in ['jbswy3dpehpk3pxp', 'mz======']) {
    testWidgets('account card preserves legacy decoding for $secret', (
      tester,
    ) async {
      // MZ has nonzero unused bits: legacy decoding accepts it, while the new
      // canonical Base32 factory rejects it. Existing records must still work.
      final account = AccountEntity()
        ..type = .TOTP
        ..issuer = 'Public test'
        ..secret = secret
        ..digits = 8
        ..period = 60;
      expect(() => validateAccount(account), returnsNormally);
      if (secret == 'mz======') {
        expect(() => Totp.fromBase32(secret: secret), throwsFormatException);
      }
      final expected = Totp(
        secret: base32.decode(secret.toUpperCase()),
        algorithm: .sha1,
        digits: 8,
        period: const Duration(seconds: 60),
      );
      final before = DateTime.now();
      await tester.pumpWidget(CupertinoApp(home: AccountCard(account)));
      final after = DateTime.now();
      String format(String value) => value.replaceAllMapped(
        RegExp(r'(.{3})'),
        (match) => '${match.group(0)} ',
      );
      final possibilities = {
        format(expected.generate(at: before)),
        format(expected.generate(at: after)),
      };
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && possibilities.contains(widget.data),
        ),
        findsOneWidget,
      );
      expect(find.text('Unable to generate code'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
