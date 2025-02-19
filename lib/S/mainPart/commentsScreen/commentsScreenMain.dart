import 'package:bartender/S/mainPart/discoverScreen/discoverScreenMain.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommentsPage extends ConsumerWidget {
  final String tweetId;
  CommentsPage({required this.tweetId});

  String _timeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final TextEditingController _controller = TextEditingController();
    final String currentUserId = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(langMain == "tr" ? "Yorumlar" : 'Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tweets')
                  .doc(tweetId)
                  .collection('comments')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final comments = snapshot.data?.docs ?? [];
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentData = comment.data() as Map<String, dynamic>;
                    // Check if the comment contains a userId.
                    if (!commentData.containsKey('userId')) {
                      return Card(
                        // Fallback UI for missing userId in comment.
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage('https://picsum.photos/200'),
                          ),
                          title: Text('Unknown'),
                          subtitle: Text(commentData['text']),
                          trailing: Text(
                            _timeAgo(commentData['timestamp']?.toDate() ??
                                DateTime.now()),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      );
                    }
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(commentData['userId'])
                          .get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            title: Text(langMain == "tr"
                                ? "Yükleniyor..."
                                : 'Loading...'),
                          );
                        }
                        if (userSnapshot.hasError) {
                          return ListTile(
                            title: Text('Error: ${userSnapshot.error}'),
                          );
                        }
                        final userDoc = userSnapshot.data;
                        final userData =
                            userDoc?.data() as Map<String, dynamic>?;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  userData?['photoURL'] ??
                                      'https://picsum.photos/200'),
                            ),
                            title: Text(userData?['displayname'] ?? 'Unknown'),
                            subtitle: Text(comment['text']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _timeAgo(comment['timestamp']?.toDate() ??
                                      DateTime.now()),
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                if (((comment.data() as Map<String, dynamic>)
                                        .containsKey('userId') &&
                                    (comment.data() as Map<String, dynamic>)[
                                            'userId'] ==
                                        currentUserId))
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('tweets')
                                          .doc(tweetId)
                                          .collection('comments')
                                          .doc(comment.id)
                                          .delete();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        style: TextStyle(
                            color: darkThemeMain ? Colors.black : Colors.white),
                        controller: _controller,
                        decoration: InputDecoration(
                          hintStyle: TextStyle(
                              color:
                                  darkThemeMain ? Colors.black : Colors.white),
                          hintText: langMain == "tr"
                              ? "Bir yorum ekle..."
                              : 'Add a comment...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send,
                      color: darkThemeMain ? Colors.white : Colors.black),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      FirebaseFirestore.instance
                          .collection('tweets')
                          .doc(tweetId)
                          .collection('comments')
                          .add({
                        'text': _controller.text,
                        'timestamp': Timestamp.now(),
                        'userId': currentUserId, // Add user ID to comment
                      });
                      _controller.clear();
                    }
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              height: 20,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
