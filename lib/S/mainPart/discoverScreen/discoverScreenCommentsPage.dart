import 'package:bartender/S/mainPart/discoverScreen/discoverScreenMain.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommentsPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final TextEditingController _controller = TextEditingController();
    final String currentUserId = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Comments'),
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
                    return Card(
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
                        title: Text(comment['text']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _timeAgo(comment['timestamp']?.toDate() ??
                                  DateTime.now()),
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (comment['userId'] == currentUserId)
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
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
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
              height: 50,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
