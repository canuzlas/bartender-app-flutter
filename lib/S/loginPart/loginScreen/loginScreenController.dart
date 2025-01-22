import 'dart:convert';
import 'package:bartender/S/loginPart/loginScreen/loginScreenModel.dart';
import 'package:bartender/S/loginPart/firestore/firestore.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class Loginscreencontroller {
  FirebaseFirestore fbs = FirebaseFirestore.instance;

  signInWithGoogle(context) async {
    SharedPreferences sss = await getSheredPrefs();

    // productta kalkacak unutma
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
      UserCredential resultUser =
          await FirebaseAuth.instance.signInWithCredential(credential);
      //create model object for logged user
      GoogleUser loggedUser = GoogleUser(
        resultUser.user?.displayName,
        resultUser.user?.email,
        resultUser.user?.photoURL,
        resultUser.user?.uid,
      );
      //saving user on the local storege
      sss.setString("user", jsonEncode(loggedUser.toObject()));
      //saving user to firestore
      var fbsuser =
          await Fbfs().getDataByDocumentId("users", resultUser.user?.uid);

      if (fbsuser?.length == null) {
        bool result = await Fbfs().setDataWithDocumentId(
            "users", resultUser.user?.uid, loggedUser.toObject());
        result
            ? print("ft gelecek login data set basarili")
            : print("ft gelecek login data set basarisiz");
      }
      Navigator.pushNamedAndRemoveUntil(
          context, '/botNavigation', (route) => false);

      return true;
    } else {
      return false;
    }
  }
}
