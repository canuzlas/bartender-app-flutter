import 'package:bartender/S/mainPart/msgScreen/messagingPage.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MsgScreenMain extends ConsumerStatefulWidget {
  const MsgScreenMain({super.key});

  @override
  _MsgScreenMainState createState() => _MsgScreenMainState();
}

class _MsgScreenMainState extends ConsumerState<MsgScreenMain> {
  String timeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inDays > 1) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 1) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 1) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  // Updated deleteMessage method using non-sorted conversationId
  Future<void> deleteMessage(String participantId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final conversationId = "$currentUserId-$participantId";
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationId)
          .delete();
      print("Conversation deleted successfully.");
    } catch (e) {
      print("Error deleting conversation: $e");
    }
  }

  void openMessagingPage(BuildContext context, String recipientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessagingPage(recipientId: recipientId),
      ),
    );
  }

  Future<Map<String, dynamic>> getUserData(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final darkThemeMain = ref.watch(darkTheme);

    print("Current User ID: $currentUserId");
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        // Filter only docs where current user is sender (to avoid duplicates)
        stream: FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error: ${snapshot.error}");
            return Center(child: Text('An error occurred.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("No messages found.");
            return Center(child: Text('No messages found.'));
          }

          final messages = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
          final usersMap = <String, Map<String, dynamic>>{};

          return FutureBuilder(
            future: Future.wait(messages.map((message) async {
              final messageData = message;
              final participantId = currentUserId == messageData['senderId']
                  ? messageData['recipientId']
                  : messageData['senderId'];
              final userData = await getUserData(participantId);
              final profilePhoto =
                  userData['photoURL'] ?? 'assets/images/placeholder.png';
              final sendername = userData['displayname'] ?? 'Unknown';
              final lastMessage = messageData['lastMessage'] ?? 'No message';
              final timestamp = messageData['timestamp'] != null
                  ? (messageData['timestamp'] as Timestamp).toDate()
                  : DateTime.now();
              if (!usersMap.containsKey(participantId) ||
                  timestamp.compareTo(usersMap[participantId]!['timestamp']) >
                      0) {
                usersMap[participantId] = {
                  'profilePhoto': profilePhoto,
                  'lastMessage': lastMessage,
                  'timestamp': timestamp,
                  'senderId': messageData['senderId'] ?? 'Unknown',
                  'sendername': sendername,
                  'messageId': messageData['messageId'] ?? 'Unknown'
                };
              }
            }).toList()),
            builder: (context, AsyncSnapshot<void> userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (userSnapshot.hasError) {
                print("Error: ${userSnapshot.error}");
                return Center(child: Text('An error occurred.'));
              }

              final usersList = usersMap.entries.toList()
                ..sort((a, b) =>
                    b.value['timestamp'].compareTo(a.value['timestamp']));

              return ListView.builder(
                itemCount: usersList.length,
                itemBuilder: (context, index) {
                  final user = usersList[index];
                  final timestamp = user.value['timestamp'] as DateTime;
                  final timeAgoText = timeAgo(timestamp);
                  return Dismissible(
                    key: Key(user.value['messageId']),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) {
                      deleteMessage(user.key);
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    child: GestureDetector(
                      onTap: () => openMessagingPage(context, user.key),
                      child: Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: user.value['profilePhoto'] !=
                                            null &&
                                        user.value['profilePhoto']
                                            .startsWith('http')
                                    ? NetworkImage(user.value['profilePhoto'])
                                    : AssetImage('assets/openingPageDT.png')
                                        as ImageProvider,
                                radius: 30,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          user.value['sendername'] != null &&
                                                  user.value['sendername'] !=
                                                      'Unknown'
                                              ? user.value['sendername']
                                              : 'Unknown',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          timeAgoText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      user.value['lastMessage'] != null &&
                                              user.value['lastMessage'] !=
                                                  'Unknown'
                                          ? user.value['lastMessage']
                                          : 'Unknown',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: darkThemeMain
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
