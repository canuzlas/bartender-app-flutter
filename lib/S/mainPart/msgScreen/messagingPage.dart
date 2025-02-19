import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/services.dart'; // For haptic feedback if needed

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

  // List of emojis to react with
  final List<String> _emojiOptions = ['👍', '❤️', '😂', '😮', '😢', '👏'];
  int?
      _activeMessageTimestamp; // New state variable to track open reaction area

  Future<void> _updateExistingDocuments(
      List<QueryDocumentSnapshot> docs, Map<String, dynamic> message) async {
    for (var doc in docs) {
      try {
        print("Updating document ${doc.id}");
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot freshSnap = await transaction.get(doc.reference);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([message]),
            'lastMessage': message['content'], // Update lastMessage field
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

  Map<String, dynamic> createNewMessage(
    Map<String, dynamic> message,
  ) {
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

  Map<String, dynamic> createNewMessage1(
    Map<String, dynamic> message,
  ) {
    return {
      'senderId': widget.recipientId,
      'recipientId': currentUserId,
      'lastMessage': message['content'],
      'timestamp': message['timestamp'],
      'messages': [message],
      'isRead': false,
      'isSent': false,
    };
  }

  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Ensure IDs are stored as strings
    final senderMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
    };

    final recipientMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
    };

    final conversationIdSender = "$currentUserId-${widget.recipientId}";
    final conversationIdRecipient = "${widget.recipientId}-$currentUserId";
    final conversationRefSender = _messagesRef.doc(conversationIdSender);
    final conversationRefRecipient = _messagesRef.doc(conversationIdRecipient);

    try {
      // Save sender's message
      final senderSnap = await conversationRefSender.get();
      if (senderSnap.exists) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final freshSnap = await transaction.get(conversationRefSender);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([senderMessage]),
            'lastMessage': senderMessage['content'],
            'timestamp': senderMessage['timestamp'],
          });
        });
      } else {
        await conversationRefSender.set({
          'senderId': currentUserId,
          'recipientId': widget.recipientId,
          'messages': [senderMessage],
          'lastMessage': senderMessage['content'],
          'timestamp': senderMessage['timestamp'],
          'participants': [currentUserId, widget.recipientId],
        });
      }

      // Save recipient's message
      final recipientSnap = await conversationRefRecipient.get();
      if (recipientSnap.exists) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final freshSnap = await transaction.get(conversationRefRecipient);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([recipientMessage]),
            'lastMessage': recipientMessage['content'],
            'timestamp': recipientMessage['timestamp'],
          });
        });
      } else {
        await conversationRefRecipient.set({
          'senderId': widget.recipientId,
          'recipientId': currentUserId,
          'messages': [recipientMessage],
          'lastMessage': recipientMessage['content'],
          'timestamp': recipientMessage['timestamp'],
          'participants': [widget.recipientId, currentUserId],
        });
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
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

  void deleteAllMessages() async {
    try {
      final conversationIdSender = "$currentUserId-${widget.recipientId}";
      // Removed deletion for the recipient's conversation document.
      await _messagesRef.doc(conversationIdSender).delete();
      print(
          "Messages for conversation $conversationIdSender deleted successfully");
    } catch (e) {
      print("Error deleting messages: $e");
    }
  }

  // New method to show emoji picker on double tap.
  void _showReactionPicker(
      Map<String, dynamic> message, String conversationId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: _emojiOptions.map((emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _updateMessageReaction(conversationId, message, emoji);
                },
                child: Center(
                  child: Text(emoji, style: TextStyle(fontSize: 30)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Updated method to update reaction after performing all reads.
  Future<void> _updateMessageReaction(String conversationId,
      Map<String, dynamic> targetMessage, String emoji) async {
    final reverseConversationId = conversationId.split('-').reversed.join('-');
    final conversationRef = _messagesRef.doc(conversationId);
    final reverseRef = _messagesRef.doc(reverseConversationId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // Read both documents before doing any writes.
      DocumentSnapshot snap1 = await transaction.get(conversationRef);
      DocumentSnapshot snap2 = await transaction.get(reverseRef);

      // Prepare update for primary conversation doc if exists.
      if (snap1.exists) {
        final data = snap1.data() as Map<String, dynamic>;
        List<dynamic> messages = data['messages'] ?? [];
        List<dynamic> updatedMessages = messages.map((msg) {
          if ((msg['timestamp'] as Timestamp).seconds ==
                  (targetMessage['timestamp'] as Timestamp).seconds &&
              msg['content'] == targetMessage['content']) {
            return {
              ...msg,
              'reaction': emoji,
            };
          }
          return msg;
        }).toList();
        transaction.update(conversationRef, {
          'messages': updatedMessages,
        });
      }

      // Prepare update for reverse conversation doc if exists.
      if (snap2.exists) {
        final data2 = snap2.data() as Map<String, dynamic>;
        List<dynamic> messages2 = data2['messages'] ?? [];
        List<dynamic> updatedMessages2 = messages2.map((msg) {
          if ((msg['timestamp'] as Timestamp).seconds ==
                  (targetMessage['timestamp'] as Timestamp).seconds &&
              msg['content'] == targetMessage['content']) {
            return {
              ...msg,
              'reaction': emoji,
            };
          }
          return msg;
        }).toList();
        transaction.update(reverseRef, {
          'messages': updatedMessages2,
        });
      }
    }).catchError((e) {
      print("Error updating message reaction: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipientDataAsync =
        ref.watch(recipientDataProvider(widget.recipientId));
    final conversationId = "$currentUserId-${widget.recipientId}";

    return Scaffold(
      appBar: AppBar(
        title: recipientDataAsync.when(
          data: (data) {
            return Row(
              children: [
                CircleAvatar(
                  backgroundImage: data?['photoURL'] != null
                      ? NetworkImage(data!['photoURL'])
                      : null,
                  child: data?['photoURL'] == null ? Icon(Icons.person) : null,
                ),
                SizedBox(width: 8),
                Text(data?['displayname'] ?? "Chat"),
              ],
            );
          },
          loading: () => Text("Loading..."),
          error: (_, __) => Text("Chat"),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: deleteAllMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // ...existing code for recipient widget...
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _messagesRef.doc(conversationId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error: ${snapshot.error}");
                  return Center(child: Text('An error occurred.'));
                }
                if (!snapshot.hasData || !(snapshot.data!.exists)) {
                  return Center(child: Text('No messages found.'));
                }
                try {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final messages = (data['messages'] as List<dynamic>? ?? []);

                  messages.sort((a, b) {
                    final timeA = (a['timestamp'] as Timestamp).toDate();
                    final timeB = (b['timestamp'] as Timestamp).toDate();
                    return timeA.compareTo(timeB);
                  });

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index] as Map<String, dynamic>;
                      // Convert senderId to String and compare directly.
                      final String senderId = message['senderId'].toString();
                      final bool isMe = senderId == currentUserId;

                      final messageText = message['content'] ?? 'No message';
                      final timestamp = message['timestamp'] != null
                          ? (message['timestamp'] as Timestamp).toDate()
                          : DateTime.now();
                      final msgTime =
                          (message['timestamp'] as Timestamp).seconds;
                      // Wrap message bubble with GestureDetector for double tap.
                      return GestureDetector(
                        onDoubleTap: () {
                          setState(() {
                            _activeMessageTimestamp =
                                (_activeMessageTimestamp == msgTime
                                    ? null
                                    : msgTime);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.7,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 15),
                                      decoration: BoxDecoration(
                                        gradient: isMe
                                            ? LinearGradient(
                                                colors: [
                                                  Colors.blueAccent,
                                                  Colors.lightBlue
                                                ],
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  Colors.grey[300]!,
                                                  Colors.grey[400]!
                                                ],
                                              ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                          bottomLeft: isMe
                                              ? Radius.circular(12)
                                              : Radius.circular(0),
                                          bottomRight: isMe
                                              ? Radius.circular(0)
                                              : Radius.circular(12),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(2, 2))
                                        ],
                                      ),
                                      child: Text(
                                        messageText,
                                        style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                                // Inline reaction area
                                if (_activeMessageTimestamp == msgTime)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      children: _emojiOptions.map((emoji) {
                                        return GestureDetector(
                                          onTap: () {
                                            _updateMessageReaction(
                                                conversationId, message, emoji);
                                            setState(() {
                                              _activeMessageTimestamp = null;
                                            });
                                          },
                                          child: Text(emoji,
                                              style: TextStyle(fontSize: 30)),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (message['reaction'] != null)
                                      Text(
                                        message['reaction'],
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.grey),
                                      ),
                                    if (message['reaction'] != null)
                                      SizedBox(width: 4),
                                    Text(
                                      DateFormat('hh:mm a').format(timestamp),
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
          // ...existing code for message input field...
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(2, 2))
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Colors.blue),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
