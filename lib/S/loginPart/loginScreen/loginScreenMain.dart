
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:bartender/S/loginPart/loginScreen/loginScreenController.dart';


class Loginscreenmain extends ConsumerStatefulWidget {
  const Loginscreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _LoginscreenmainState();
}

class _LoginscreenmainState extends ConsumerState<Loginscreenmain> {
  Loginscreencontroller loginscreencontroller = Loginscreencontroller();
  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    return Scaffold(
       backgroundColor: darkThemeMain? Color.fromRGBO(23, 21, 59,1) : const  Color.fromRGBO(249, 247, 247,1), 
       body: SafeArea(
        //main container
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // logo
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                 darkThemeMain? Image.asset("assets/openingPageDT.png",width: 100,height: 90,):Image.asset("assets/openingPageLT.png",width: 100,height: 90,)
                ],
            )),

            //google sign in button
            Expanded(child:  Container(
            alignment: Alignment.bottomCenter,
            margin: EdgeInsets.only(bottom: 50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  alignment: Alignment.center,
                  margin: EdgeInsets.only(top: 200),
                  height: 40,
                  child: SignInButton(
                    Buttons.Google,
                    text: "Google ile giriş yap",
                    onPressed: () {
                      loginscreencontroller.signInWithGoogle();
                    },
                  ),
                )
              ],
            ),
          ),)
            
       ],),),
    );
  }
}