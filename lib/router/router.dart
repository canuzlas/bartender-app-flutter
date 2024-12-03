
import 'package:bartender/S/loginPart/loginScreen/loginScreenMain.dart';
import 'package:bartender/S/mainPart/botNavigation.dart';
import 'package:bartender/S/startingPart/openingScreen/openingScreenMain.dart';
import 'package:bartender/S/startingPart/selectLangScreen/selectLangScreenMain.dart';
import 'package:bartender/S/startingPart/selectThemeScreen/selectThemeScreenMain.dart';
import 'package:flutter/material.dart';

class GeneratedRouter {
  static Route? router(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      return MaterialPageRoute(builder: (context) =>  Botnavigation());
        //return MaterialPageRoute(builder: (context) => const Openingscreenmain());
        //return MaterialPageRoute(builder: (context) => const Loginscreenmain());
      case '/selectThemeScreen':
        return MaterialPageRoute(builder: (context) => const Selectthemescreenmain());
      case '/selectLangScreen':
        return MaterialPageRoute(builder: (context) => const Selectlangscreenmain());
      case '/loginScreen':
        return MaterialPageRoute(builder: (context) => const Loginscreenmain());
      case '/botNavigation':
        return MaterialPageRoute(builder: (context) =>  Botnavigation());

    }
    return null;
  }
}
