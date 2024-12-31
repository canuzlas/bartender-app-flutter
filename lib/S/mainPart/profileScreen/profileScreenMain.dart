import 'package:bartender/mainSettings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Profilescreenmain extends ConsumerStatefulWidget {
  const Profilescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ProfilescreenmainState();
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
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              //profile top bar
              Row(
                children: [
                  Text(
                    "🍸 canuzlas",
                    style: TextStyle(fontSize: 18),
                  ),
                  Spacer(),
                  IconButton(
                    iconSize: 20,
                    color: darkThemeMain ? Colors.white : Colors.black,
                    icon: const Icon(Icons.add_box_outlined),
                    onPressed: () {
                      return null;
                    },
                  ),
                  IconButton(
                    iconSize: 20,
                    color: darkThemeMain ? Colors.white : Colors.black,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircleAvatar(
                      backgroundImage: AssetImage("assets/openingPageDT.png"),
                    ),
                  ),
                  Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr" ? "gönderi" : "post"),
                    ],
                  ),
                  Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr" ? "takipçi" : "follower"),
                    ],
                  ),
                  Column(
                    children: [
                      Text("1"),
                      Text(langMain == "tr" ? "takip" : "follow"),
                    ],
                  ),
                ],
              ),
              // name, biografi and buttons

              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                    ),
                    //name
                    Text("Can Uzlaş",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    //bio
                    Text(
                      "asdasd    sadasdasdasdsasdasdasdasdasdadasdadasdasdsadasds asdadasd",
                      softWrap: true,
                      style: TextStyle(fontSize: 18),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 10),
                          padding: EdgeInsets.all(3),
                          height: 30,
                          child: Text(
                            langMain == "tr"
                                ? "profili düzenle"
                                : "edit profile",
                            style: TextStyle(
                              color: darkThemeMain
                                  ? Colors.orangeAccent
                                  : Colors.deepOrange,
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),

              Flexible(
                flex: 3,
                child: DefaultTabController(
                  length: 2,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, value) {
                      return [
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          floating: true,
                          pinned: false,
                          bottom: TabBar(
                            tabs: [
                              Tab(
                                  text: langMain == "tr"
                                      ? "Paylaşımlar"
                                      : "Posts"),
                              Tab(
                                  text: langMain == "tr"
                                      ? "Beğenilenler"
                                      : "Likes"),
                            ],
                          ),
                          flexibleSpace: FlexibleSpaceBar(
                            collapseMode: CollapseMode.pin,
                            background:
                                null, // This is where you build the profile part
                          ),
                        ),
                      ];
                    },
                    body: TabBarView(
                      children: [
                        Container(
                          child: GridView.count(
                              padding: EdgeInsets.zero,
                              crossAxisCount: 3,
                              children: [
                                for (var i = 0; i < 10; i++)
                                  Container(
                                    padding: EdgeInsets.all(1),
                                    height: 150.0,
                                    color: Colors.transparent,
                                    child: Image.network(
                                        "https://picsum.photos/300/300"),
                                  ),
                              ]),
                        ),
                        Container(
                          child: GridView.count(
                              padding: EdgeInsets.zero,
                              crossAxisCount: 3,
                              children: [
                                for (var i = 0; i < 10; i++)
                                  Container(
                                    padding: EdgeInsets.all(1),
                                    height: 150.0,
                                    color: Colors.transparent,
                                    child: Image.network(
                                        "https://picsum.photos/300/300"),
                                  ),
                              ]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
