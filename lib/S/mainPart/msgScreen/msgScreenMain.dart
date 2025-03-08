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
            return Center(
                child: CircularProgressIndicator(
              color: Colors.deepPurple,
              strokeWidth: 3,
            ));
          }

          if (snapshot.hasError) {
            print("Error: ${snapshot.error}");
            return Center(
                child: Text(
              'An error occurred.',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("No messages found.");
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'No messages found',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your conversations will appear here',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
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
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                      margin: EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Delete',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.delete_forever, color: Colors.white),
                        ],
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () => openMessagingPage(context, user.key),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        decoration: BoxDecoration(
                          color:
                              darkThemeMain ? Color(0xFF2A2A2A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  backgroundImage: user.value['profilePhoto'] !=
                                              null &&
                                          user.value['profilePhoto']
                                              .startsWith('http')
                                      ? NetworkImage(user.value['profilePhoto'])
                                      : AssetImage('assets/openingPageDT.png')
                                          as ImageProvider,
                                  radius: 30,
                                ),
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
                                            fontSize: 17,
                                            color: darkThemeMain
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: darkThemeMain
                                                ? Colors.deepPurple
                                                    .withOpacity(0.2)
                                                : Colors.deepPurple
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            timeAgoText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: darkThemeMain
                                                  ? Colors.grey[300]
                                                  : Colors.deepPurple[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
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
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
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
