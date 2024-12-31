import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Light Theme
  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color.fromRGBO(219, 226, 239, 1),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    // appBarTheme: AppBarTheme(
    //   color: Colors.grey[850],
    // ),
    scaffoldBackgroundColor: const Color.fromRGBO(23, 21, 59, 1),
  );
}
