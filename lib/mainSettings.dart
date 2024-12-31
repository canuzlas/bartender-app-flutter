import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

//sessions local state
final sharedPreferences =
    Provider<SharedPreferences>((_) => throw UnimplementedError());

//theme state
final darkTheme = StateProvider((ref) => false);
//lang state
final lang = StateProvider((ref) => "tr");
final themeChangeState = Provider.autoDispose((ref) {
  //
});

getSheredPrefs() async {
  SharedPreferences sss = await SharedPreferences.getInstance();

  return sss;
}

setTimeout(callback, time) {
  Duration timeDelay = Duration(milliseconds: time);
  return Timer(timeDelay, callback);
}

//loadSettings
loadGeneralSettings(ref, context) async {
  SharedPreferences sss = await getSheredPrefs();
  bool? sssDarkTheme = sss.getBool("darkTheme");
  String? sssLang = sss.getString("lang");
  bool? set = sss.getBool("set");
  //setting language and theme
  ref.read(darkTheme.notifier).state = sssDarkTheme == true ? true : false;
  ref.read(lang.notifier).state = sssLang == "tr" ? "tr" : "en";

  set == true
      ? setTimeout(
          () async => {Navigator.popAndPushNamed(context, '/loginScreen')},
          2000)
      : setTimeout(
          () async =>
              {Navigator.popAndPushNamed(context, '/selectThemeScreen')},
          2000);
}
