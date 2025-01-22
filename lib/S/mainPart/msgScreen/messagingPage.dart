import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Define a provider to fetch recipient data
final recipientDataProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, recipientId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(recipientId)
      .get();
  if (doc.exists) {
    return doc.data() as Map<String, dynamic>?;
  }
  return null;
});

class MessagingPage extends ConsumerStatefulWidget {
  final String recipientId;

  const MessagingPage({super.key, required this.recipientId});

  @override
  _MessagingPageState createState() => _MessagingPageState();
}

class _MessagingPageState extends ConsumerState<MessagingPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final CollectionReference _messagesRef =
      FirebaseFirestore.instance.collection('messages');

  Future<void> _updateExistingDocuments(
      List<QueryDocumentSnapshot> docs, Map<String, dynamic> message) async {
    for (var doc in docs) {
      try {
        print("Updating document ${doc.id}");
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot freshSnap = await transaction.get(doc.reference);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([message]),
          });
        });
        print("Document ${doc.id} updated successfully");
      } catch (e) {
        print("Error updating document ${doc.id}: $e");
        // Add more detailed logging
        print("Document data: ${doc.data()}");
        print("Message data: $message");
      }
    }
  }

  Future<void> _addNewMessage(Map<String, dynamic> message) async {
    try {
      print("No existing documents found, adding new message");
      await _messagesRef.add(message);
      print("New message added successfully");
    } catch (e) {
      print("Error adding new message: $e");
    }
  }

  Map<String, dynamic> createNewMessage(Map<String, dynamic> message) {
    return {
      'senderId': currentUserId,
      'recipientId': widget.recipientId,
      'lastMessage': message['content'],
      'timestamp': message['timestamp'],
      'messages': [message],
      'isRead': false,
      'isSent': false,
    };
  }

  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = {
      'senderId': currentUserId,
      'recipientId': widget.recipientId,
      'content': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
    };

    try {
      final querySnapshot = await _messagesRef
          .where("senderId", isEqualTo: currentUserId)
          .where('recipientId', isEqualTo: widget.recipientId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await _updateExistingDocuments(querySnapshot.docs, message);
      } else {
        await _addNewMessage(createNewMessage(message));
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  Future<void> deleteAllMessages() async {
    try {
      final querySnapshot = await _messagesRef
          .where("senderId", isEqualTo: currentUserId)
          .where('recipientId', isEqualTo: widget.recipientId)
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      print("All messages deleted successfully");
    } catch (e) {
      print("Error deleting messages: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipientDataAsync =
        ref.watch(recipientDataProvider(widget.recipientId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: deleteAllMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          recipientDataAsync.when(
            data: (recipientData) {
              if (recipientData != null) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: recipientData['photoURL'] != null
                            ? NetworkImage(recipientData['photoURL'])
                            : AssetImage('assets/openingPageDT.png')
                                as ImageProvider,
                        radius: 30,
                      ),
                      SizedBox(width: 16),
                      Text(
                        recipientData['displayname'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return SizedBox.shrink();
              }
            },
            loading: () => Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading recipient data')),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef
                  .where("senderId", isEqualTo: currentUserId)
                  .where('recipientId', isEqualTo: widget.recipientId)
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
                  return Center(child: Text('No messages found.'));
                }
                try {
                  final messages = snapshot.data!.docs
                      .expand((doc) =>
                          (doc.data() as Map<String, dynamic>)['messages']
                              as List<dynamic>? ??
                          [])
                      .toList();

                  // Sort messages by timestamp from old to new
                  messages.sort((a, b) {
                    final timestampA = (a['timestamp'] as Timestamp).toDate();
                    final timestampB = (b['timestamp'] as Timestamp).toDate();
                    return timestampA.compareTo(timestampB);
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index] as Map<String, dynamic>;
                      final isMe = message['senderId'] == currentUserId;
                      final messageText = message['content'] ?? 'No message';
                      final timestamp = message['timestamp'] != null
                          ? (message['timestamp'] as Timestamp).toDate()
                          : DateTime.now();
                      return ListTile(
                        title: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 15),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              messageText,
                              style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black),
                            ),
                          ),
                        ),
                        subtitle: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text(
                            DateFormat('hh:mm a').format(timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  );
                } catch (e) {
                  print("Error processing messages: $e");
                  return Center(child: Text('An error occurred.'));
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
