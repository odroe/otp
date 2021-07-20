import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entities/account.entity.dart';
import 'widgets/account.card.dart';
import 'widgets/help.dart';

class HomeScreen extends StatelessWidget {
  final Box<AccountEntity> accountsBox = Hive.box(AccountEntity.entityName);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: CupertinoPageScaffold(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              automaticallyImplyTitle: true,
              automaticallyImplyLeading: true,
              backgroundColor:
                  CupertinoTheme.of(context).scaffoldBackgroundColor,
              middle: Text("Authenticator"),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Icon(CupertinoIcons.add),
                onPressed: () {
                  // TODO: Add a code.
                },
              ),
              // _kNavBarEdgePadding
              padding: EdgeInsetsDirectional.only(
                start: 16.0,
                end: 16.0,
              ),
              largeTitle: Padding(
                // See _kNavBarEdgePadding
                padding: EdgeInsets.only(right: 16.0),
                child: CupertinoSearchTextField(),
              ),
            ),
            SliverPadding(padding: EdgeInsets.only(top: 12.0)),
            SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: accountsBox.listenable(),
                builder:
                    (BuildContext context, Box<AccountEntity> box, _widget) {
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: box.length,
                    itemBuilder: (BuildContext context, int index) {
                      return AccountCard(box.values.elementAt(index));
                    },
                  );
                },
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              sliver: SliverToBoxAdapter(child: Help()),
            ),
          ],
        ),
      ),
    );
  }
}
