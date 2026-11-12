import 'package:authenticator/entities/account.entity.dart';
import 'package:authenticator/home/home.screen.dart';
import 'package:authenticator/home/scan.screen.dart';
import 'package:authenticator/home/widgets/account.card.dart';
import 'package:authenticator/home/widgets/help.dart';
import 'package:authenticator/home/widgets/progress-timer.indicator.dart';
import 'package:authenticator/main.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// These remain generative, extendable constructors, not factories.
class const DerivedHome({super.key}) extends HomeScreen;
class const DerivedScan({super.key}) extends ScanScreen;
class const DerivedHelp({super.key}) extends Help;
class const DerivedStartup({super.key}) extends Startup;
class const DerivedProgress({super.key, required super.period})
    extends ProgressTimerIndicator;
class const DerivedCard(super.account, {super.key, super.accountKey})
    extends AccountCard;

void main() {
  test(
    'constant constructors and inherited key parameters remain available',
    () {
      const key = ValueKey('constructor API');
      const widgets = <Widget>[
        HomeScreen(key: key),
        ScanScreen(key: key),
        Help(key: key),
        Startup(key: key),
        ProgressTimerIndicator(key: key, period: 30),
        DerivedHome(key: key),
        DerivedScan(key: key),
        DerivedHelp(key: key),
        DerivedStartup(key: key),
        DerivedProgress(key: key, period: 30),
      ];
      for (final widget in widgets) {
        expect(widget.key, same(key));
      }
      expect(const DerivedProgress(period: 60).period, 60);
    },
  );

  test('account positional and optional named parameters retain their API', () {
    final account = AccountEntity();
    const key = ValueKey('account');
    final card = DerivedCard(account, key: key, accountKey: 'stored-key');
    expect(card.account, same(account));
    expect(card.key, same(key));
    expect(card.accountKey, 'stored-key');
    expect(AccountCard(account).accountKey, isNull);
    expect(AccountCard(account).key, isNull);
  });
}
