import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// Import packages for GIF support
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // GIF-related variables
  bool _isLoading = false;
  List<String> _gifs = [];
  final String _gifApiKey =
      'jQvRAGPsXaXoATFjA2BGc5IE3z9XZDru'; // Replace with your Giphy API key
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reactionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Pre-load some trending GIFs
    _fetchTrendingGifs();
  }

  @override
  void dispose() {
    _reactionAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Method to fetch trending GIFs
  Future<void> _fetchTrendingGifs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.giphy.com/v1/gifs/trending?api_key=$_gifApiKey&limit=20&rating=g'),
        headers: {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'] is List) {
          setState(() {
            _gifs = (data['data'] as List)
                .map((gif) => gif['images']['fixed_height']['url'].toString())
                .toList();
            _isLoading = false;
          });
          print('Loaded ${_gifs.length} trending GIFs');
        } else {
          print('Invalid data format from Giphy API');
          setState(() {
            _gifs = [];
            _isLoading = false;
          });
        }
      } else {
        print('Failed to load trending GIFs: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching trending GIFs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to search for GIFs
  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) {
      _fetchTrendingGifs();
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    try {
      // Encode the query to handle spaces and special characters
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse(
            'https://api.giphy.com/v1/gifs/search?api_key=$_gifApiKey&q=$encodedQuery&limit=20&rating=g'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null &&
            data['data'] is List &&
            (data['data'] as List).isNotEmpty) {
          setState(() {
            _gifs = (data['data'] as List)
                .map((gif) => gif['images']['fixed_height']['url'].toString())
                .toList();
            _isLoading = false;
          });
        } else {
          print('No GIFs found for query: $query');
          setState(() {
            _gifs = [];
            _isLoading = false;
          });
        }
      } else {
        print('Failed to search GIFs: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching GIFs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to show GIF picker
  void _showGifPicker() {
    // Create local state variables for the modal
    bool isLoading = true;
    List<String> gifs = [];
    String searchQuery = '';
    TextEditingController searchController = TextEditingController();

    // Function to fetch trending GIFs specifically for the modal
    Future<void> fetchTrendingGifs(StateSetter setModalState) async {
      setModalState(() {
        isLoading = true;
      });

      try {
        final response = await http.get(
          Uri.parse(
              'https://api.giphy.com/v1/gifs/trending?api_key=$_gifApiKey&limit=20&rating=g'),
          headers: {
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['data'] != null && data['data'] is List) {
            setModalState(() {
              gifs = (data['data'] as List)
                  .map((gif) => gif['images']['fixed_height']['url'].toString())
                  .toList();
              isLoading = false;
            });
            print('Loaded ${gifs.length} trending GIFs');
          } else {
            print('Invalid data format from Giphy API');
            setModalState(() {
              gifs = [];
              isLoading = false;
            });
          }
        } else {
          print('Failed to load trending GIFs: ${response.statusCode}');
          print('Response body: ${response.body}');
          setModalState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching trending GIFs: $e');
        setModalState(() {
          isLoading = false;
        });
      }
    }

    // Function to search GIFs specifically for the modal
    Future<void> searchGifsModal(
        String query, StateSetter setModalState) async {
      if (query.isEmpty) {
        fetchTrendingGifs(setModalState);
        return;
      }

      setModalState(() {
        isLoading = true;
        searchQuery = query;
      });

      try {
        // Encode the query to handle spaces and special characters
        final encodedQuery = Uri.encodeComponent(query);
        final response = await http.get(
          Uri.parse(
              'https://api.giphy.com/v1/gifs/search?api_key=$_gifApiKey&q=$encodedQuery&limit=20&rating=g'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['data'] != null &&
              data['data'] is List &&
              (data['data'] as List).isNotEmpty) {
            setModalState(() {
              gifs = (data['data'] as List)
                  .map((gif) => gif['images']['fixed_height']['url'].toString())
                  .toList();
              isLoading = false;
            });
          } else {
            print('No GIFs found for query: $query');
            setModalState(() {
              gifs = [];
              isLoading = false;
            });
          }
        } else {
          print('Failed to search GIFs: ${response.statusCode}');
          print('Response body: ${response.body}');
          setModalState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error searching GIFs: $e');
        setModalState(() {
          isLoading = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
          // Initial fetch when the modal is opened
          if (isLoading && gifs.isEmpty) {
            fetchTrendingGifs(setModalState);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade600,
                        Colors.purpleAccent.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select a GIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search GIFs...',
                            hintStyle: const TextStyle(color: Colors.white70),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white70),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.white70),
                                    onPressed: () {
                                      searchController.clear();
                                      fetchTrendingGifs(setModalState);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              searchGifsModal(value, setModalState);
                            }
                          },
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.deepPurple,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading GIFs...',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            ],
                          ),
                        )
                      : gifs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sentiment_dissatisfied,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    searchController.text.isEmpty
                                        ? 'No trending GIFs available'
                                        : 'No GIFs found for "${searchController.text}"',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (searchController.text.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        searchController.clear();
                                        fetchTrendingGifs(setModalState);
                                      },
                                      child: const Text(
                                        'Show trending GIFs',
                                        style: TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                if (searchController.text.isEmpty) {
                                  await fetchTrendingGifs(setModalState);
                                } else {
                                  await searchGifsModal(
                                      searchController.text, setModalState);
                                }
                              },
                              child: GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.0,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemCount: gifs.length,
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendGifMessage(gifs[index]);
                                    },
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              gifs[index],
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    value: loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                                    color: Colors.deepPurple,
                                                    strokeWidth: 2,
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                print(
                                                    'Error loading GIF at index $index: $error');
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            // Add an overlay effect when pressed
                                            Positioned.fill(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  splashColor: Colors
                                                      .purpleAccent
                                                      .withOpacity(0.3),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _sendGifMessage(
                                                        gifs[index]);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // Method to send a GIF message
  Future<void> _sendGifMessage(String gifUrl) async {
    // Ensure IDs are stored as strings
    final senderMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': 'GIF',
      'gifUrl': gifUrl,
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
      'isGif': true,
    };

    final recipientMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': 'GIF',
      'gifUrl': gifUrl,
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
      'isGif': true,
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
            'lastMessage': 'GIF',
            'timestamp': senderMessage['timestamp'],
          });
        });
      } else {
        await conversationRefSender.set({
          'senderId': currentUserId,
          'recipientId': widget.recipientId,
          'messages': [senderMessage],
          'lastMessage': 'GIF',
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
            'lastMessage': 'GIF',
            'timestamp': recipientMessage['timestamp'],
          });
        });
      } else {
        await conversationRefRecipient.set({
          'senderId': widget.recipientId,
          'recipientId': currentUserId,
          'messages': [recipientMessage],
          'lastMessage': 'GIF',
          'timestamp': recipientMessage['timestamp'],
          'participants': [widget.recipientId, currentUserId],
        });
      }

      _scrollToBottom();
    } catch (e) {
      print("Error sending GIF message: $e");
    }
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> deleteAllMessages() async {
    try {
      // Show a confirmation dialog
      bool confirm = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Delete Conversation'),
                content: const Text(
                    'Are you sure you want to delete this conversation?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirm) return;

      final conversationIdSender = "$currentUserId-${widget.recipientId}";

      // Try to delete recipient's conversation document but don't fail if it doesn't exist
      try {
        await _messagesRef.doc(conversationIdSender).delete();
      } catch (e) {
        print("Note: Could not delete recipient conversation: $e");
        // This is non-critical, so continue execution
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back after deletion
      Navigator.pop(context);
    } catch (e) {
      print("Error deleting messages: $e");

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete conversation: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                const Text(
                  'React to this message',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
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
                                style: const TextStyle(fontSize: 30)),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
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
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Center(
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
              const SizedBox(width: 10),
              const Text(
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
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 20),
            ),
            onPressed: deleteAllMessages,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
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
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .doc("$currentUserId-${widget.recipientId}")
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
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
                          const SizedBox(height: 16),
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
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('messages')
                          .doc("${widget.recipientId}-$currentUserId")
                          .snapshots(),
                      builder: (context, secondSnapshot) {
                        if (secondSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!secondSnapshot.hasData ||
                            !secondSnapshot.data!.exists) {
                          return const Center(child: Text('No messages yet'));
                        }

                        var data = secondSnapshot.data!.data()
                            as Map<String, dynamic>?;
                        if (data == null || !data.containsKey('messageList')) {
                          return const Center(
                              child: Text('Start a conversation'));
                        }

                        var messageList = List<Map<String, dynamic>>.from(
                            data['messageList'] ?? []);

                        // Sort messages by timestamp
                        messageList.sort((a, b) {
                          var aTimestamp = a['timestamp'] as Timestamp;
                          var bTimestamp = b['timestamp'] as Timestamp;
                          return aTimestamp.compareTo(bTimestamp);
                        });

                        return ListView.builder(
                          reverse: false,
                          itemCount: messageList.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            var message = messageList[index];
                            bool isCurrentUser =
                                message['senderId'] == currentUserId;

                            return Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: 8,
                                  left: isCurrentUser ? 64 : 0,
                                  right: isCurrentUser ? 0 : 64,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Colors.deepPurple
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  message['text'] ?? '',
                                  style: TextStyle(
                                    color: isCurrentUser
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index] as Map<String, dynamic>;
                        // Convert senderId to String and compare directly.
                        final String senderId = message['senderId'].toString();
                        final bool isMe = senderId == currentUserId;
                        final bool isGif = message['isGif'] == true;
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
                                  padding: const EdgeInsets.symmetric(
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
                                                topLeft:
                                                    const Radius.circular(18),
                                                topRight:
                                                    const Radius.circular(18),
                                                bottomLeft: isMe
                                                    ? const Radius.circular(18)
                                                    : const Radius.circular(4),
                                                bottomRight: isMe
                                                    ? const Radius.circular(4)
                                                    : const Radius.circular(18),
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
                                                  child: isGif
                                                      ? ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          child: Image.network(
                                                            message['gifUrl'],
                                                            fit: BoxFit.cover,
                                                            loadingBuilder:
                                                                (context, child,
                                                                    loadingProgress) {
                                                              if (loadingProgress ==
                                                                  null) {
                                                                return child;
                                                              }
                                                              return SizedBox(
                                                                height: 150,
                                                                child: Center(
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    value: loadingProgress.expectedTotalBytes !=
                                                                            null
                                                                        ? loadingProgress.cumulativeBytesLoaded /
                                                                            loadingProgress.expectedTotalBytes!
                                                                        : null,
                                                                    color: isMe
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .deepPurple,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            errorBuilder:
                                                                (context, error,
                                                                    stackTrace) {
                                                              return Container(
                                                                height: 100,
                                                                width: 150,
                                                                color: isMe
                                                                    ? Colors
                                                                        .deepPurple
                                                                        .shade300
                                                                    : Colors.grey[
                                                                        300],
                                                                child: Center(
                                                                  child: Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color: isMe
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .grey[600],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        )
                                                      : Text(
                                                          messageText,
                                                          style: TextStyle(
                                                            color: isMe
                                                                ? Colors.white
                                                                : Colors
                                                                    .black87,
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
                                                                const EdgeInsets
                                                                    .all(4),
                                                            child: Text(
                                                              message[
                                                                  'reaction'],
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          20),
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
                    offset: const Offset(0, -3),
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
                        icon: Icon(Icons.gif_box_rounded,
                            color: Colors.deepPurple.shade300),
                        onPressed: _showGifPicker, // Show GIF picker
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextField(
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                            controller: _messageController,
                            decoration: const InputDecoration(
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
                        margin: const EdgeInsets.only(right: 8),
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
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white),
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
