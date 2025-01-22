import 'package:bartender/S/startingPart/openingScreen/osController.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Openingscreenmain extends ConsumerStatefulWidget {
  const Openingscreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _OpeningscreenmainState();
}

class _OpeningscreenmainState extends ConsumerState<Openingscreenmain> {
  OsController osController = OsController();

  getFutureData() async {
    var set = await loadGeneralSettings(ref, context);
    set == true && osController.checkUserLoggedIn() == true
        ? setTimeout(
            () async => {Navigator.popAndPushNamed(context, '/botNavigation')},
            2000)
        : set == true && osController.checkUserLoggedIn() == false
            ? setTimeout(
                () async =>
                    {Navigator.popAndPushNamed(context, '/loginScreen')},
                2000)
            : setTimeout(
                () async =>
                    {Navigator.popAndPushNamed(context, '/selectThemeScreen')},
                2000);
  }

  @override
  void initState() {
    getFutureData();
    print(getFutureData());
    //print('$set ${osController.checkUserLoggedIn().toString()}');

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    return Scaffold(
      backgroundColor: darkThemeMain
          ? const Color.fromRGBO(23, 21, 59, 1)
          : const Color.fromRGBO(249, 247, 247, 1),
      body: SafeArea(
          child: Center(
        child: Image.asset(
          darkThemeMain
              ? "assets/openingPageDT.png"
              : "assets/openingPageLT.png",
          width: 150,
          height: 150,
        ),
      )),
    );
  }
}
