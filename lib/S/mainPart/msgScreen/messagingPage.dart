import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
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
    return doc.data();
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
// New state variable to track open reaction area

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
    // final darkThemeMain = ref.watch(darkTheme);
    // final langMain = ref.watch(lang);
    final recipientDataAsync =
        ref.watch(recipientDataProvider(widget.recipientId));
    final conversationId = "$currentUserId-${widget.recipientId}";

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: recipientDataAsync.when(
          data: (data) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherUserProfileScreen(
                      userId: widget.recipientId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: data?['photoURL'] != null
                        ? NetworkImage(data!['photoURL'])
                        : null,
                    child: data?['photoURL'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(data?['displayname'] ?? "Chat"),
                ],
              ),
            );
          },
          loading: () => const Text("Loading..."),
          error: (_, __) => const Text("Chat"),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
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
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error: ${snapshot.error}");
                  return const Center(child: Text('An error occurred.'));
                }
                if (!snapshot.hasData || !(snapshot.data!.exists)) {
                  return const Center(child: Text('No messages found.'));
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

                      // Wrap message bubble with GestureDetector for double tap.
                      return GestureDetector(
                        onDoubleTap: () {
                          _showReactionPicker(message, conversationId);
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 15),
                                      decoration: BoxDecoration(
                                        gradient: isMe
                                            ? const LinearGradient(
                                                colors: [
                                                  Colors.deepPurple,
                                                  Colors.purpleAccent
                                                ],
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  Colors.teal.shade200,
                                                  Colors.teal.shade400
                                                ],
                                              ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(12),
                                          topRight: const Radius.circular(12),
                                          bottomLeft: isMe
                                              ? const Radius.circular(12)
                                              : const Radius.circular(0),
                                          bottomRight: isMe
                                              ? const Radius.circular(0)
                                              : const Radius.circular(12),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.15),
                                            blurRadius: 6,
                                            offset: const Offset(2, 2),
                                          )
                                        ],
                                      ),
                                      child: Text(
                                        messageText,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (message['reaction'] != null)
                                      Text(
                                        message['reaction'],
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.grey),
                                      ),
                                    if (message['reaction'] != null)
                                      const SizedBox(width: 4),
                                    Text(
                                      DateFormat('hh:mm a').format(timestamp),
                                      style: const TextStyle(
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
                  return const Center(child: Text('An error occurred.'));
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
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
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
                        style:
                            const TextStyle(color: Colors.black, fontSize: 16),
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(child: SizedBox(height: 10)),
        ],
      ),
    );
  }
}
