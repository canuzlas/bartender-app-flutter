import 'package:bartender/mainSettings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Profilescreenmain extends ConsumerStatefulWidget {
  const Profilescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ProfilescreenmainState();
}

class _ProfilescreenmainState extends ConsumerState<Profilescreenmain> {
  
 
  @override
  Widget build(BuildContext context) {
  final darkThemeMain = ref.watch(darkTheme);
  final langMain = ref.watch(lang);

    return Scaffold(
      body: SafeArea(
        //main container
        child: Container(
          padding: EdgeInsets.all(10),
          //main column
          child: Column(
            children: [
              //profile top bar
              Row(
                children: [
                  Text("🍸 canuzlas",style: TextStyle(fontSize: 18),),
                  Spacer(),
                  IconButton(
                        iconSize: 20,
                        color: darkThemeMain? Colors.white:Colors.black,
                        icon: const Icon(Icons.add_box_outlined),
                        onPressed: () {
                          return null;
                        },
                      ),
                  IconButton(
                          iconSize: 20,
                          color: darkThemeMain? Colors.white:Colors.black,
                          icon: const Icon(CupertinoIcons.settings),
                          onPressed: () {
                            return null;
                          },
                        ),
                ],
              ),
              SizedBox(
                height: 10,
              ),
              //photo, posts and followers vs.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  SizedBox(
                           width: 70,
                           height: 70,
                           child: CircleAvatar(
                             backgroundImage: AssetImage("assets/openingPageDT.png"),
                           ),
                         ),
                  Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr"?"gönderi":"post"),
                      
                    ],
                  ),
                  Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr"?"takipçi":"follower"),
                      
                    ],
                  ),Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr"?"takip":"follow"),
                    ],
                  ),
                ],
              ),
              // name, biografi and buttons
              Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //name
                        Text("Can Uzlaş"),
                        //bio
                        Text(
                          "asdasd    sadasdasdasdsasdasdasdasdasdadasdadasdasdsadasds asdadasd",
                          
                           softWrap: true,
                           style: const TextStyle(
                               fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                      ],
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}