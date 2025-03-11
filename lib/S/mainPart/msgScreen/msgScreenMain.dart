import 'package:bartender/S/mainPart/discoverScreen/searchDelegate.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  // Updated deleteMessage method to handle both conversation ID formats
  Future<void> deleteMessage(String participantId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Try first format: currentUser-participant
      final conversationId1 = "$currentUserId-$participantId";

      // Try second format: participant-currentUser
      final conversationId2 = "$participantId-$currentUserId";

      // Check if the first format exists
      final doc1 = await FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationId1)
          .get();

      if (doc1.exists) {
        // Delete the document if it exists
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(conversationId1)
            .delete();
        print("Conversation deleted successfully with ID: $conversationId1");
      } else {
        // Check if the second format exists
        final doc2 = await FirebaseFirestore.instance
            .collection('messages')
            .doc(conversationId2)
            .get();

        if (doc2.exists) {
          // Delete the document if it exists
          await FirebaseFirestore.instance
              .collection('messages')
              .doc(conversationId2)
              .delete();
          print("Conversation deleted successfully with ID: $conversationId2");
        } else {
          print("No conversation found with either ID format");
        }
      }

      // Show success message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error deleting conversation: $e");
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete conversation'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
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
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data() ?? {};
    } catch (e) {
      print("Error fetching user data: $e");
      return {};
    }
  }

  Future<void> _refreshMessages() async {
    setState(() {
      _isRefreshing = true;
    });

    // Wait a bit to show the refresh indicator
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isRefreshing = false;
    });

    return;
  }

  void _startNewChat(BuildContext context) {
    // Use showSearch for SearchDelegate
    showSearch(
      context: context,
      delegate: UserSearchDelegate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final darkThemeMain = ref.watch(darkTheme);

    return Scaffold(
      appBar: _isSearching
          ? AppBar(
              backgroundColor: darkThemeMain ? Colors.black : Colors.white,
              elevation: 0,
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color:
                          darkThemeMain ? Colors.grey[400] : Colors.grey[600]),
                ),
                style: TextStyle(
                    color: darkThemeMain ? Colors.white : Colors.black),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: darkThemeMain ? Colors.white : Colors.black,
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            )
          : AppBar(
              backgroundColor: darkThemeMain ? Colors.black : Colors.white,
              elevation: 0,
              title: Text(
                'Messages',
                style: TextStyle(
                  color: darkThemeMain ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search,
                      color: darkThemeMain ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _refreshMessages,
        color: Colors.deepPurple,
        child: StreamBuilder<QuerySnapshot>(
          // Modified query to only include messages where the current user is the sender
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: currentUserId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_isRefreshing) {
              return const Center(
                  child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 3,
              ));
            }

            if (snapshot.hasError) {
              print("Error: ${snapshot.error}");
              return Center(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: _refreshMessages,
                    child: const Text('Try Again',
                        style: TextStyle(color: Colors.deepPurple)),
                  )
                ],
              ));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.message, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation with someone',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _startNewChat(context),
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('Start New Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    )
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
                // Add null check for senderId and recipientId
                final String senderId =
                    messageData['senderId']?.toString() ?? '';
                final String recipientId =
                    messageData['recipientId']?.toString() ?? '';

                // Ensure we have a valid participantId
                final String participantId;
                if (currentUserId == senderId && recipientId.isNotEmpty) {
                  participantId = recipientId;
                } else if (senderId.isNotEmpty) {
                  participantId = senderId;
                } else {
                  // Skip this message if we can't determine a valid participant
                  print("Skipping message with invalid IDs: $messageData");
                  return;
                }

                final userData = await getUserData(participantId);
                final String profilePhoto = userData['photoURL']?.toString() ??
                    'assets/images/placeholder.png';
                final String sendername =
                    userData['displayname']?.toString() ?? 'Unknown';
                final String lastMessage =
                    messageData['lastMessage']?.toString() ?? 'No message';
                final timestamp = messageData['timestamp'] != null
                    ? (messageData['timestamp'] as Timestamp).toDate()
                    : DateTime.now();
                final bool unread = messageData['unread'] == true;
                final String messageId = messageData['messageId']?.toString() ??
                    DateTime.now().toIso8601String();

                if (!usersMap.containsKey(participantId) ||
                    timestamp.compareTo(usersMap[participantId]!['timestamp']) >
                        0) {
                  usersMap[participantId] = {
                    'profilePhoto': profilePhoto,
                    'lastMessage': lastMessage,
                    'timestamp': timestamp,
                    'senderId': senderId,
                    'sendername': sendername,
                    'unread': unread,
                    'messageId': messageId
                  };
                }
              }).toList()),
              builder: (context, AsyncSnapshot<void> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting &&
                    !_isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userSnapshot.hasError) {
                  print("Error: ${userSnapshot.error}");
                  return const Center(child: Text('An error occurred.'));
                }

                final usersList = usersMap.entries.toList()
                  ..sort((a, b) =>
                      b.value['timestamp'].compareTo(a.value['timestamp']));

                // Apply search filter if searching
                final filteredUsersList = _searchQuery.isEmpty
                    ? usersList
                    : usersList.where((user) {
                        final senderName =
                            user.value['sendername'].toString().toLowerCase();
                        final lastMessage =
                            user.value['lastMessage'].toString().toLowerCase();
                        return senderName.contains(_searchQuery) ||
                            lastMessage.contains(_searchQuery);
                      }).toList();

                if (filteredUsersList.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 70, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No matches found',
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: filteredUsersList.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsersList[index];
                    final timestamp = user.value['timestamp'] as DateTime;
                    final timeAgoText = timeAgo(timestamp);
                    final isUnread = user.value['unread'] == true &&
                        user.value['senderId'] != currentUserId;

                    return Dismissible(
                      key: Key(user.value['messageId']?.toString() ?? user.key),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Delete Conversation"),
                              content: const Text(
                                  "Are you sure you want to delete this conversation?"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text("Delete",
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        deleteMessage(user.key);
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade800,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Row(
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
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isUnread
                                ? (darkThemeMain
                                    ? Colors.deepPurple.withOpacity(0.15)
                                    : Colors.deepPurple.withOpacity(0.08))
                                : (darkThemeMain
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                spreadRadius: 0,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple
                                                .withOpacity(0.2),
                                            spreadRadius: 1,
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        backgroundImage: user.value[
                                                        'profilePhoto'] !=
                                                    null &&
                                                user.value['profilePhoto']
                                                    .toString()
                                                    .startsWith('http')
                                            ? NetworkImage(user
                                                .value['profilePhoto']
                                                .toString())
                                            : const AssetImage(
                                                    'assets/openingPageDT.png')
                                                as ImageProvider,
                                        radius: 30,
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: darkThemeMain
                                                  ? const Color(0xFF2A2A2A)
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.value['sendername'] !=
                                                          null &&
                                                      user.value[
                                                              'sendername'] !=
                                                          'Unknown'
                                                  ? user.value['sendername']
                                                  : 'Unknown',
                                              style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                fontSize: 17,
                                                color: darkThemeMain
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isUnread
                                                  ? Colors.deepPurple
                                                      .withOpacity(0.8)
                                                  : (darkThemeMain
                                                      ? Colors.deepPurple
                                                          .withOpacity(0.2)
                                                      : Colors.deepPurple
                                                          .withOpacity(0.1)),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              timeAgoText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isUnread
                                                    ? Colors.white
                                                    : (darkThemeMain
                                                        ? Colors.grey[300]
                                                        : Colors
                                                            .deepPurple[700]),
                                                fontWeight: isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (user.value['senderId'] ==
                                              currentUserId)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  right: 6),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: darkThemeMain
                                                    ? Colors.grey[700]
                                                    : Colors.grey[200],
                                              ),
                                              child: Icon(
                                                Icons.send,
                                                size: 12,
                                                color: darkThemeMain
                                                    ? Colors.grey[300]
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              user.value['lastMessage'] !=
                                                          null &&
                                                      user.value[
                                                              'lastMessage'] !=
                                                          'Unknown'
                                                  ? user.value['lastMessage']
                                                  : 'Unknown',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isUnread
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isUnread
                                                    ? (darkThemeMain
                                                        ? Colors.white
                                                        : Colors.black87)
                                                    : (darkThemeMain
                                                        ? Colors.grey[400]
                                                        : Colors.grey[700]),
                                              ),
                                            ),
                                          ),
                                        ],
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startNewChat(context),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
