import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../entities/origin.entity.dart';
import 'widgets/help.dart';
import 'widgets/origin.card.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Box<OriginEntity> entityBox;

  @override
  void initState() {
    entityBox = Hive.box<OriginEntity>(OriginEntity.entityName);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // CupertinoPageRoute();
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            automaticallyImplyTitle: false,
            backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
            middle: Text("Authenticator"),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.add),
              onPressed: () {},
            ),
            largeTitle: CupertinoSearchTextField(),
          ),
          SliverPadding(padding: EdgeInsets.only(top: 12.0)),
          SliverToBoxAdapter(
            child: ValueListenableBuilder(
              valueListenable: entityBox.listenable(),
              builder: (BuildContext context, Box<OriginEntity> box, _widget) {
                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: box.length,
                  itemBuilder: (BuildContext context, int index) {
                    final entity = box.values.elementAt(index);
                    return OriginCard();
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
    );
  }
}
