

import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Selectthemescreenmain extends ConsumerStatefulWidget {
  const Selectthemescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SelectthemescreenmainState();
}

class _SelectthemescreenmainState extends ConsumerState<Selectthemescreenmain> {

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    return Scaffold(
      backgroundColor: const  Color.fromRGBO(249, 247, 247,1), 
      body: SafeArea(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
         Expanded(
          flex: 3,
           child: Container(
             
             color:const Color.fromRGBO(23, 21, 59,1) 
                   ,
             alignment: Alignment.center,

                   
             child:Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              
               GestureDetector(
                onTap: () => {
                  ref.read(darkTheme.notifier).state = true
                },
                child: Image.asset("assets/openingPageDT.png",width: 150,height: 150,)),
               Text(langMain == "tr" ?"Koyu Tema":"Dark Theme",style: const TextStyle(color:Colors.white)),
               Text(darkThemeMain ? langMain=="tr"?"[SEÇİLEN]": "[CHOOSED]":"",style: const TextStyle(color:Color.fromARGB(255, 205, 205, 6))),

               

             ],) ,
           ),
         ),
        
         Expanded(
          flex: 3,
           child: Container(
                color:const  Color.fromRGBO(249, 247, 247,1),
               alignment: Alignment.center,

               child:Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                 GestureDetector(
                  onTap: () => {
                     ref.read(darkTheme.notifier).state = false
                  },
                  child: Image.asset("assets/openingPageLT.png",width: 150,height: 150,)),
                 Text(langMain == "tr"?"Açık Tema":"Light Theme",style: TextStyle(color:Color.fromRGBO(23, 21, 59,1)),),
                 Text(darkThemeMain ? "":langMain=="tr"?"[SEÇİLEN]": "[CHOOSED]",style: const TextStyle(color:Color.fromARGB(255, 5, 126, 57) )),

               ],) ,
             ),
         ),

         Expanded(
           child: GestureDetector(
            onTap: () => Navigator.pushNamed(context,'/selectLangScreen'),
             child: Container(
                  color:const  Color.fromRGBO(249, 247, 247,1),
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