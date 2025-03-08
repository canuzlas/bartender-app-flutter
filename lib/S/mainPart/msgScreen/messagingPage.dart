import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MessagingPageState extends ConsumerState<MessagingPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final CollectionReference _messagesRef =
      FirebaseFirestore.instance.collection('messages');

  // Animation controller for reaction effects
  late AnimationController _reactionAnimController;
  String? _lastReactedMessageId;

  // List of emojis to react with - simplified back to basic format
  final List<String> _emojiOptions = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '👏',
    '🔥',
    '🙏'
  ];

  @override
  void initState() {
    super.initState();
    _reactionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _reactionAnimController.dispose();
    super.dispose();
  }

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

  // Improved reaction picker UI
  void _showReactionPicker(
      Map<String, dynamic> message, String conversationId) {
    // Generate a unique ID for the message based on timestamp and content
    final messageId =
        "${(message['timestamp'] as Timestamp).seconds}-${message['content'].hashCode}";
    _lastReactedMessageId = messageId;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade600,
                  Colors.purpleAccent.shade400
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'React to this message',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _emojiOptions.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _updateMessageReaction(
                              conversationId, message, _emojiOptions[index]);
                          // Play animation
                          _reactionAnimController.reset();
                          _reactionAnimController.forward();
                        },
                        child: Container(
                          width: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(_emojiOptions[index],
                                style: TextStyle(fontSize: 30)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // Simplified and improved method to update reaction
  Future<void> _updateMessageReaction(String conversationId,
      Map<String, dynamic> targetMessage, String emoji) async {
    try {
      final reverseConversationId =
          conversationId.split('-').reversed.join('-');
      final conversationRef = _messagesRef.doc(conversationId);
      final reverseRef = _messagesRef.doc(reverseConversationId);

      // Create a timestamp identifier for the message to match
      final targetTimestamp = (targetMessage['timestamp'] as Timestamp).seconds;
      final targetContent = targetMessage['content'];

      // First document update
      await _updateSingleConversation(
          conversationRef, targetTimestamp, targetContent, emoji);

      // Second document update - don't fail if this one doesn't work
      try {
        await _updateSingleConversation(
            reverseRef, targetTimestamp, targetContent, emoji);
      } catch (e) {
        print("Error updating reverse conversation: $e");
        // Non-critical error, continue
      }

      // Trigger animation
      _reactionAnimController.reset();
      _reactionAnimController.forward();
    } catch (e) {
      print("Error in _updateMessageReaction: $e");
    }
  }

  // Helper method to update a single conversation document
  Future<void> _updateSingleConversation(DocumentReference docRef,
      int targetTimestamp, String targetContent, String emoji) async {
    // Get the document first
    final docSnapshot = await docRef.get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() as Map<String, dynamic>;
    final List<dynamic> messages = List.from(data['messages'] ?? []);

    // Find and update the message
    bool updated = false;
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg is Map<String, dynamic>) {
        final timestamp = msg['timestamp'];
        if (timestamp is Timestamp &&
            timestamp.seconds == targetTimestamp &&
            msg['content'] == targetContent) {
          // Update the message with the reaction
          messages[i] = {...msg, 'reaction': emoji};
          updated = true;
          break;
        }
      }
    }

    // Only update if we found and modified the message
    if (updated) {
      await docRef.update({'messages': messages});
    }
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade800,
                Colors.purpleAccent.shade700
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                  Hero(
                    tag: 'profile-${widget.recipientId}',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.6),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: data?['photoURL'] != null
                            ? NetworkImage(data!['photoURL'])
                            : null,
                        child: data?['photoURL'] == null
                            ? Icon(Icons.person, color: Colors.grey[700])
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data?['displayname'] ?? "Chat",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                "Loading...",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          error: (_, __) => const Text(
            "Chat",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, color: Colors.white, size: 20),
            ),
            onPressed: deleteAllMessages,
          ),
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.info_outline, color: Colors.white, size: 20),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
          ),
        ),
        child: Column(
          children: [
            // ...existing code for recipient widget...
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _messagesRef.doc(conversationId).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple,
                        strokeWidth: 3,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    print("Error: ${snapshot.error}");
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 60, color: Colors.grey[500]),
                          SizedBox(height: 16),
                          Text(
                            'An error occurred',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (!snapshot.hasData || !(snapshot.data!.exists)) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 80, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      physics: BouncingScrollPhysics(),
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

                        // Group messages by date
                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevTimestamp = messages[index - 1]
                                      ['timestamp'] !=
                                  null
                              ? (messages[index - 1]['timestamp'] as Timestamp)
                                  .toDate()
                              : DateTime.now();

                          if (timestamp.day != prevTimestamp.day ||
                              timestamp.month != prevTimestamp.month ||
                              timestamp.year != prevTimestamp.year) {
                            showDateHeader = true;
                          }
                        }

                        // Wrap message bubble with GestureDetector for reaction
                        return Column(
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    DateFormat('MMMM d, yyyy')
                                        .format(timestamp),
                                    style: TextStyle(
                                      color: Colors.grey[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onDoubleTap: () {
                                HapticFeedback.mediumImpact();
                                _showReactionPicker(message, conversationId);
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
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
                                              maxWidth: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.75,
                                            ),
                                            margin: EdgeInsets.only(
                                              left: isMe ? 50 : 0,
                                              right: isMe ? 0 : 50,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: isMe
                                                  ? LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Colors.deepPurple
                                                            .shade700,
                                                        Colors.deepPurple
                                                            .shade900,
                                                      ],
                                                    )
                                                  : LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                      colors: [
                                                        Colors.white,
                                                        Colors.grey.shade100,
                                                      ],
                                                    ),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(18),
                                                topRight: Radius.circular(18),
                                                bottomLeft: isMe
                                                    ? Radius.circular(18)
                                                    : Radius.circular(4),
                                                bottomRight: isMe
                                                    ? Radius.circular(4)
                                                    : Radius.circular(18),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: isMe
                                                      ? Colors.deepPurple
                                                          .withOpacity(0.3)
                                                      : Colors.black
                                                          .withOpacity(0.05),
                                                  blurRadius: 8,
                                                  spreadRadius: 0,
                                                  offset: const Offset(0, 3),
                                                )
                                              ],
                                            ),
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Text(
                                                    messageText,
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 16,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ),
                                                if (message['reaction'] != null)
                                                  Positioned(
                                                    bottom: -16,
                                                    right: isMe ? null : -2,
                                                    left: isMe ? -2 : null,
                                                    child: AnimatedBuilder(
                                                      animation:
                                                          _reactionAnimController,
                                                      builder:
                                                          (context, child) {
                                                        final scale = _lastReactedMessageId ==
                                                                    "${(message['timestamp'] as Timestamp).seconds}-${message['content'].hashCode}" &&
                                                                _reactionAnimController
                                                                    .isAnimating
                                                            ? 1.0 +
                                                                _reactionAnimController
                                                                        .value *
                                                                    0.5
                                                            : 1.0;

                                                        return Transform.scale(
                                                          scale: scale,
                                                          child: Container(
                                                            padding:
                                                                EdgeInsets.all(
                                                                    4),
                                                            child: Text(
                                                              message[
                                                                  'reaction'],
                                                              style: TextStyle(
                                                                  fontSize: 20),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          left: 4,
                                          right: 4,
                                        ),
                                        child: Text(
                                          DateFormat('h:mm a')
                                              .format(timestamp),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
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
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12.0),
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.shade100,
                        Colors.grey.shade200,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.emoji_emotions_outlined,
                            color: Colors.deepPurple.shade300),
                        onPressed: () {}, // Placeholder for emoji picker
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextField(
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: Colors.black54),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade600,
                              Colors.purpleAccent.shade700,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
