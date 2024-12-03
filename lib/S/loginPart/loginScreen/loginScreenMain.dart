
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:bartender/S/loginPart/loginScreen/loginScreenController.dart';
import 'package:neon_widgets/neon_widgets.dart';


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
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                 darkThemeMain? Image.asset("assets/openingPageDT.png",width: 100,height: 90,):Image.asset("assets/openingPageLT.png",width: 100,height: 90,)
                ],
            )),

            //Gif          
            Expanded(
              flex: 12,
              child: Image.asset("assets/login.gif")
              ),
               //gif bottom title
               Expanded(
                
                          flex: 2,
                          child:  NeonText(
              text: langMain == "tr"?"Yenilikçi bir maceraya hazır mısın?":"Are you ready for an innovative adventure?",
              spreadColor: Colors.purple,
              blurRadius: 20,
              textSize: 26,
              textColor: darkThemeMain? Colors.white : Colors.black,
            ),),
            //google sign in button
            Expanded( flex: 7,
              child:  Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(    
                    alignment: Alignment.center,
                    height: 40,
                    child: SignInButton(
                      darkThemeMain ? Buttons.Google : Buttons.GoogleDark,
                      text: langMain == "tr"?"Google ile giriş yap":"Sign in with Google",
                      onPressed: () {
                        loginscreencontroller.signInWithGoogle();
                      },
                    ),
                  ),
                  
                ],
              ),),
              
            
       ],),),
    );
  }
}