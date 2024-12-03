import 'dart:convert';
import 'package:bartender/S/loginPart/loginScreen/loginScreenModel.dart';
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
     UserCredential resultUser = await FirebaseAuth.instance.signInWithCredential(credential);
     GoogleUser loggedUser =  GoogleUser(resultUser.user?.displayName,resultUser.user?.email,resultUser.user?.photoURL,resultUser.user?.uid);
     //saving user on the local storege
     sss.setString("user",jsonEncode(loggedUser.toObject()));
      return googleUser;
    } else {
      return false;
    }
  }

 

}
