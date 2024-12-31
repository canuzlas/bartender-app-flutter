import 'package:bartender/mainSettings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_view/story_view.dart';

class Homescreenmain extends ConsumerStatefulWidget {
  const Homescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomescreenmainState();
}

class _HomescreenmainState extends ConsumerState<Homescreenmain> {
  final StoryController controller = StoryController();

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    return Scaffold(
      backgroundColor: darkThemeMain
          ? const Color.fromRGBO(23, 21, 59, 1)
          : const Color.fromRGBO(249, 247, 247, 1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Story section
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(7, (index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => MoreStories(
                                    storyOwner: "can uzlas",
                                  )));
                        },
                        child: const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: CircleAvatar(
                              backgroundImage:
                                  AssetImage("assets/openingPageLT.png"),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Post section
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(4, (index) {
                        return Container(
                          margin: const EdgeInsets.all(5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // User info and more button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircleAvatar(
                                        backgroundImage: NetworkImage(
                                            "https://picsum.photos/300/300"),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Can Uzlaş",
                                    style: TextStyle(
                                        color: darkThemeMain
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    iconSize: 25,
                                    color: darkThemeMain
                                        ? Colors.white
                                        : Colors.black,
                                    icon: const Icon(Icons.more_horiz),
                                    onPressed: () {
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              // Post image
                              SizedBox(
                                height: 220,
                                child: Image.network(
                                    alignment: Alignment.center,
                                    "https://picsum.photos/300/200"),
                              ),
                              // Bottom buttons
                              Row(
                                children: [
                                  IconButton(
                                    iconSize: 22,
                                    color: darkThemeMain
                                        ? Colors.white
                                        : Colors.black,
                                    icon: const Icon(CupertinoIcons.heart),
                                    onPressed: () {
                                      return null;
                                    },
                                  ),
                                  IconButton(
                                    iconSize: 22,
                                    color: darkThemeMain
                                        ? Colors.white
                                        : Colors.black,
                                    icon: const Icon(
                                        Icons.insert_comment_outlined),
                                    onPressed: () {
                                      return null;
                                    },
                                  ),
                                  Spacer(),
                                  IconButton(
                                    iconSize: 22,
                                    color: darkThemeMain
                                        ? Colors.white
                                        : Colors.black,
                                    icon: const Icon(Icons.send_outlined),
                                    onPressed: () {
                                      return null;
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoreStories extends StatefulWidget {
  // will be GoogleUser object
  final String storyOwner;
  MoreStories({Key? key, required this.storyOwner}) : super(key: key);
  @override
  _MoreStoriesState createState() => _MoreStoriesState();
}

class _MoreStoriesState extends State<MoreStories> {
  final storyController = StoryController();

  @override
  void dispose() {
    storyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storyOwner),
      ),
      body: StoryView(
        storyItems: [
          StoryItem.text(
            title: "I guess you'd love to see more of our food. That's great.",
            backgroundColor: Colors.blue,
          ),
          StoryItem.text(
            title: "Nice!\n\nTap to continue.",
            backgroundColor: Colors.red,
            textStyle: TextStyle(
              fontFamily: 'Dancing',
              fontSize: 40,
            ),
          ),
          StoryItem.pageImage(
            url:
                "https://image.ibb.co/cU4WGx/Omotuo-Groundnut-Soup-braperucci-com-1.jpg",
            caption: Text(
              "Still sampling",
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            controller: storyController,
          ),
          StoryItem.pageImage(
              url: "https://media.giphy.com/media/5GoVLqeAOo6PK/giphy.gif",
              caption: Text(
                "Working with gifs",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              controller: storyController),
          StoryItem.pageImage(
            url: "https://media.giphy.com/media/XcA8krYsrEAYXKf4UQ/giphy.gif",
            caption: Text(
              "Hello, from the other side",
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            controller: storyController,
          ),
          StoryItem.pageImage(
            url: "https://media.giphy.com/media/XcA8krYsrEAYXKf4UQ/giphy.gif",
            caption: Text(
              "Hello, from the other side2",
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            controller: storyController,
          ),
        ],
        onStoryShow: (storyItem, index) {
          print("Showing a story");
        },
        onComplete: () {
          print("Completed a cycle");
        },
        progressPosition: ProgressPosition.top,
        repeat: false,
        controller: storyController,
      ),
    );
  }
}
