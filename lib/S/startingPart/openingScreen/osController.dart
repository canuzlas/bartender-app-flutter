

import 'dart:async';

import 'package:bartender/mainSettings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OsController {
  setTimeout(callback, time) {
    Duration timeDelay = Duration(milliseconds: time);
    return Timer(timeDelay, callback);
  }


}