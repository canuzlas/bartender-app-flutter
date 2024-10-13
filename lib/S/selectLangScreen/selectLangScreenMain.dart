

import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Selectlangscreenmain extends ConsumerStatefulWidget {
  const Selectlangscreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SelectthemescreenmainState();
}

class _SelectthemescreenmainState extends ConsumerState<Selectlangscreenmain> {

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    return Scaffold(
      backgroundColor: darkThemeMain? Color.fromRGBO(23, 21, 59,1) : const  Color.fromRGBO(249, 247, 247,1), 
      body: SafeArea(child: Column(
          mainAxisAlignment:  MainAxisAlignment.center,
          children: [
         Expanded(
          flex: 3,
           child: Container(
             
             alignment: Alignment.center,             
             child:Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              
               GestureDetector(
                onTap: () => {
                  ref.read(lang.notifier).state = "tr"
                },
                child: Image.asset("assets/trLang.png",width: 250,height: 250,)),
               Text(darkThemeMain ? "TÜRKÇE":"TÜRKÇE",style:   TextStyle(color: darkThemeMain? Colors.white: Colors.black )),
               Text(langMain=="tr"?"[SEÇİLEN]": "",style: const TextStyle(color:Colors.red)),
             ],) ,
           ),
         ),
        
         Expanded(
          flex: 3,
           child: Container(
               alignment: Alignment.center,

               child:Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                 GestureDetector(
                  onTap: () => {
                     ref.read(lang.notifier).state = "en"
                  },
                  child: Image.asset("assets/enLang.png",width: 170,height: 170,)),
               Text(darkThemeMain ? "ENGLISH":"ENGLISH",style:   TextStyle(color: darkThemeMain? Colors.white: Colors.black )),
                 Text(langMain=="tr"?"":"[CHOOSED]",style: const TextStyle(color:Color.fromARGB(255, 5, 126, 57) )),

               ],) ,
             ),
         ),

         Expanded(
           flex: 1,
           child: GestureDetector(
             onTap: () => Navigator.pushNamed(context,'/selectLangScreen'),
             child: Container(
                  color:  darkThemeMain? Color.fromRGBO(23, 21, 59,1) : const  Color.fromRGBO(249, 247, 247,1), 
                 alignment: Alignment.center,
           
                 child:Column(
                  mainAxisAlignment: MainAxisAlignment.center,
           
                  children: [
                     Image.asset("assets/selectThemeNext.png",width: 70,height: 60,)
                 ],) ,
               ),
           ),
         )
            ],),
      ))
;
  }
}