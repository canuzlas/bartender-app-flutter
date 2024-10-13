
import 'package:bartender/S/openingScreen/openingScreenMain.dart';
import 'package:bartender/S/selectLangScreen/selectLangScreenMain.dart';
import 'package:bartender/S/selectThemeScreen/selectThemeScreenMain.dart';
import 'package:flutter/material.dart';

class GeneratedRouter {
  static Route? router(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (context) => const Openingscreenmain());
      case '/selectThemeScreen':
        return MaterialPageRoute(builder: (context) => const Selectthemescreenmain());
      case '/selectLangScreen':
        return MaterialPageRoute(builder: (context) => const Selectlangscreenmain());
    }
    return null;
  }
}
