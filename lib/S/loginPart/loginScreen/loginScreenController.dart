import 'dart:convert';
import 'dart:ffi';
import 'package:bartender/S/loginPart/loginScreen/loginScreenModel.dart';
import 'package:bartender/firestore/firestore.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Loginscreencontroller{
  FirebaseFirestore fbs = FirebaseFirestore.instance;

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
     //saving user to firestore

     var userContains = await fbs.collection("users").doc(resultUser.user?.uid).get();
     
      if(userContains.data()?.length == null){
          await fbs.collection("users").doc(resultUser.user?.uid).set(loggedUser.toObject()).then(( doc) =>
          print('**************************flutter toast will come'));
      }else{
        print("***************************var");
      }

      return googleUser;
    } else {
      return false;
    }
  }

 

}
