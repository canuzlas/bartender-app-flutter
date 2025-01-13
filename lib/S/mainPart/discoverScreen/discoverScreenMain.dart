import 'package:bartender/S/mainPart/discoverScreen/discoverScreenCommentsPage.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenModel.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenState.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverPageController.dart';
import 'package:bartender/S/mainPart/discoverScreen/searchDelegate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

class DiscoveryScreenMain extends ConsumerStatefulWidget {
  @override
  _DiscoveryScreenMainState createState() => _DiscoveryScreenMainState();
}

class _DiscoveryScreenMainState extends ConsumerState<DiscoveryScreenMain> {
  final DiscoverPageController _controller = DiscoverPageController();

  @override
  Widget build(BuildContext context) {
    final tweetAsyncValue = ref.watch(tweetProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon:
                        Icon(Icons.menu, color: Theme.of(context).primaryColor),
                    onPressed: () {
                      // Add menu action
                    },
                  ),
                  Text(
                    'your world',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search,
                        color: Theme.of(context).primaryColor),
                    onPressed: () {
                      showSearch(
                        context: context,
                        delegate: UserSearchDelegate(),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: tweetAsyncValue.when(
                data: (tweets) {
                  return ListView.builder(
                    itemCount: tweets.length,
                    itemBuilder: (context, index) {
                      final tweet = tweets[index];
                      return FutureBuilder<String>(
                        future: _controller.getUserName(tweet.userId),
                        builder: (context, snapshot) {
                          final userName = snapshot.data ?? 'Loading...';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            elevation: 5,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        'https://picsum.photos/200'),
                                  ),
                                  title: Text(
                                    tweet.message,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Updated by: $userName',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: Text(
                                    _controller.timeAgo(tweet.timestamp),
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.thumb_up),
                                            color: tweet.likes > 0
                                                ? Colors.blue
                                                : Colors.grey,
                                            onPressed: () {
                                              final userId = auth.currentUser!
                                                  .uid; // Replace with actual user ID
                                              if (tweet.likedBy
                                                  .contains(userId)) {
                                                FirebaseFirestore.instance
                                                    .collection('tweets')
                                                    .doc(tweet.id)
                                                    .update({
                                                  'likes':
                                                      FieldValue.increment(-1),
                                                  'likedBy':
                                                      FieldValue.arrayRemove(
                                                          [userId]),
                                                });
                                              } else {
                                                FirebaseFirestore.instance
                                                    .collection('tweets')
                                                    .doc(tweet.id)
                                                    .update({
                                                  'likes':
                                                      FieldValue.increment(1),
                                                  'likedBy':
                                                      FieldValue.arrayUnion(
                                                          [userId]),
                                                });
                                              }
                                            },
                                          ),
                                          Text('${tweet.likes} likes'),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.comment),
                                        color: Colors.grey,
                                        onPressed: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (context) =>
                                                CommentsPage(tweetId: tweet.id),
                                          ));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              final TextEditingController _controller = TextEditingController();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                title: Text('New Tweet'),
                content: TextField(
                  controller: _controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'What\'s happening?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel',
                        style:
                            TextStyle(color: Theme.of(context).primaryColor)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        final userId = auth
                            .currentUser!.uid; // Replace with actual user ID
                        FirebaseFirestore.instance.collection('tweets').add(
                              Tweet('', _controller.text, DateTime.now(),
                                      userId)
                                  .toMap(),
                            );
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                    label: Text('Tweet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Theme.of(context).primaryColor,
        mini: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 50,
          color: Colors.transparent,
        ),
      ),
    );
  }
}
