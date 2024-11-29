import 'dart:convert';
import 'package:bartender/mainSettings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Loginscreencontroller{

  signInWithGoogle() async {
    SharedPreferences sss = await getSheredPrefs();

    await GoogleSignIn().signOut();
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
  
    if (googleUser != null) {
      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Once signed in, return the UserCredential
     UserCredential user = await FirebaseAuth.instance.signInWithCredential(credential);
     sss.setString("user",jsonEncode(user));
      return googleUser;
    } else {
      return false;
    }
  }

 

}
