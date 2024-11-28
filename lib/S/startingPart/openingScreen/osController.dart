

import 'dart:async';

class OsController {
  setTimeout(callback, time) {
    Duration timeDelay = Duration(milliseconds: time);
    return Timer(timeDelay, callback);
  }
}