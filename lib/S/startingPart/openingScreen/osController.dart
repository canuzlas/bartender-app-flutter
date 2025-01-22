import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class OsController {
  setTimeout(callback, time) {
    Duration timeDelay = Duration(milliseconds: time);
    return Timer(timeDelay, callback);
  }

  checkUserLoggedIn() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return true;
    } else {
      return false;
    }
  }
}
