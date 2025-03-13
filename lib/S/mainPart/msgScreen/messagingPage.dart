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
import 'dart:async'; // For timer functionality

// Define Riverpod providers for message page state
final gifsProvider = StateProvider<List<String>>((ref) => []);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final searchQueryProvider = StateProvider<String>((ref) => '');
final recipientTypingProvider = StateProvider<bool>((ref) => false);
// Remove typing icon provider as we don't need it anymore
final messageOpacityProvider =
    StateProvider<double>((ref) => 0.3); // New provider for message opacity
final recipientDataProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => doc.exists ? doc.data() : null);
});

class MessagingPage extends ConsumerStatefulWidget {
  final String recipientId;

  const MessagingPage({super.key, required this.recipientId});

  @override
  _MessagingPageState createState() => _MessagingPageState();
}

// Refine the initial loading and scroll behavior
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
  final String _gifApiKey = 'jQvRAGPsXaXoATFjA2BGc5IE3z9XZDru';
  final TextEditingController _searchController = TextEditingController();

  // Typing indicator variables
  Timer? _typingTimer;
  bool _isTyping = false;
  final CollectionReference _typingRef =
      FirebaseFirestore.instance.collection('typing_status');
  StreamSubscription? _typingSubscription;

  // Flag to prevent multiple scrolls
  bool _isFirstLoad = true;
  bool _isScrolling = false;

  // Flag to track if we've initiated first scroll
  bool _hasScheduledInitialScroll = false;

  // More reliable scroll control variables
  bool _isFirstBuild = true;

  // Additional flag to track initial content loading
  bool _messagesLoaded = false;

  // More precise control over initial loading
  bool _initialRenderComplete = false;
  int _scrollAttempts = 0;
  final int _maxScrollAttempts = 5;

  // Improved loading state management
  bool _isInitialLoading = true;

  // Simple flag to track first load without using providers that could cause errors
  bool _showLogoOnly = true;

  // Add new flag to track if we should update state after build
  bool _needsStateUpdate = false;

  @override
  void initState() {
    super.initState();
    _reactionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Pre-load some trending GIFs - Using Future to delay state updates
    Future(() {
      _fetchTrendingGifs();
    });

    // Listen to typing status changes
    _listenToTypingStatus();

    // Mark messages as read when conversation is opened
    _markMessagesAsRead();

    // Add listener to scroll controller to know when initial render is complete
    _scrollController.addListener(() {
      if (_scrollController.hasClients && !_initialRenderComplete) {
        _initialRenderComplete = true;
        _attemptScrollToBottom();
      }
    });

    // Set initial loading state properly with error handling
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showLogoOnly = true;
          });
        }
      });
    } catch (e) {
      print("Error setting initial loading state: $e");
    }

    // Apply a simple timeout to ensure the logo doesn't show indefinitely
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showLogoOnly = false;
        });
      }
    });

    // Start with low opacity for messages - fix by using post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(messageOpacityProvider.notifier).state = 0.3;

        // Animate to full opacity after a delay - move inside post-frame callback
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ref.read(messageOpacityProvider.notifier).state = 1.0;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _reactionAnimController.dispose();
    _searchController.dispose();
    _messageController.dispose();
    _typingTimer?.cancel();
    _typingSubscription?.cancel();
    _scrollController.dispose();

    // Clean up typing status when leaving the chat
    _setTypingStatus(false);

    super.dispose();
  }

  // Method to mark all messages in conversation as read
  Future<void> _markMessagesAsRead() async {
    try {
      // Get current conversation document for receiving messages from the other user
      final conversationIdReceiver = "$currentUserId-${widget.recipientId}";
      final conversationRef = _messagesRef.doc(conversationIdReceiver);

      final docSnapshot = await conversationRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (data.containsKey('messages')) {
          final List<dynamic> messages = List.from(data['messages'] ?? []);
          bool hasUnreadMessages = false;

          // Update read status for messages from the recipient
          for (int i = 0; i < messages.length; i++) {
            final msg = messages[i];
            if (msg is Map<String, dynamic> &&
                msg['senderId'] == widget.recipientId.toString() &&
                msg['isRead'] == false) {
              messages[i]['isRead'] = true;
              hasUnreadMessages = true;
            }
          }

          // Only update the document if there were unread messages
          if (hasUnreadMessages) {
            await conversationRef.update({'messages': messages});

            // Also update the mirror conversation doc if it exists
            final conversationIdSender = "${widget.recipientId}-$currentUserId";
            final reverseRef = _messagesRef.doc(conversationIdSender);
            final reverseSnapshot = await reverseRef.get();

            if (reverseSnapshot.exists) {
              final reverseData =
                  reverseSnapshot.data() as Map<String, dynamic>;
              final List<dynamic> reverseMessages =
                  List.from(reverseData['messages'] ?? []);
              bool reverseHasUnread = false;

              for (int i = 0; i < reverseMessages.length; i++) {
                final msg = reverseMessages[i];
                if (msg is Map<String, dynamic> &&
                    msg['senderId'] == currentUserId.toString() &&
                    msg['isRead'] == false) {
                  reverseMessages[i]['isRead'] = true;
                  reverseHasUnread = true;
                }
              }

              if (reverseHasUnread) {
                await reverseRef.update({'messages': reverseMessages});
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  // Method to listen for typing status - simplified version that only updates recipient typing
  void _listenToTypingStatus() {
    final typingDocId =
        "${widget.recipientId}_$currentUserId"; // recipient to current user

    _typingSubscription =
        _typingRef.doc(typingDocId).snapshots().listen((snapshot) {
      // Wrap the state update in Future to delay it until after build
      Future(() {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('isTyping')) {
            bool isTyping = data['isTyping'] == true;
            ref.read(recipientTypingProvider.notifier).state = isTyping;
            // No longer showing typing icon, so we don't need to update that state
          } else {
            ref.read(recipientTypingProvider.notifier).state = false;
          }
        } else {
          ref.read(recipientTypingProvider.notifier).state = false;
        }
      });
    });
  }

  // Method to update typing status
  void _setTypingStatus(bool isTyping) async {
    if (_isTyping == isTyping) return; // No change

    _isTyping = isTyping;
    final typingDocId =
        "${currentUserId}_${widget.recipientId}"; // current user to recipient

    try {
      await _typingRef.doc(typingDocId).set({
        'isTyping': isTyping,
        'timestamp': Timestamp.now(),
        'senderId': currentUserId,
        'recipientId': widget.recipientId,
      });
    } catch (e) {
      print("Error setting typing status: $e");
    }
  }

  // Method to handle typing detection
  void _handleTyping() {
    _setTypingStatus(true);

    // Reset the timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _setTypingStatus(false);
    });
  }

  // Method to fetch trending GIFs
  Future<void> _fetchTrendingGifs() async {
    // Safely update the loading state
    Future(() {
      ref.read(isLoadingProvider.notifier).state = true;
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
          final gifs = (data['data'] as List)
              .map((gif) => gif['images']['fixed_height']['url'].toString())
              .toList();

          // Safely update the state
          Future(() {
            if (mounted) {
              ref.read(gifsProvider.notifier).state = gifs;
            }
          });

          print('Loaded ${gifs.length} trending GIFs');
        } else {
          print('Invalid data format from Giphy API');

          // Safely update the state
          Future(() {
            if (mounted) {
              ref.read(gifsProvider.notifier).state = [];
            }
          });
        }
      } else {
        print('Failed to load trending GIFs: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching trending GIFs: $e');
    } finally {
      // Safely update the loading state
      Future(() {
        if (mounted) {
          ref.read(isLoadingProvider.notifier).state = false;
        }
      });
    }
  }

  // Method to search for GIFs
  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) {
      _fetchTrendingGifs();
      return;
    }

    // Safely update the state
    Future(() {
      if (mounted) {
        ref.read(isLoadingProvider.notifier).state = true;
        ref.read(searchQueryProvider.notifier).state = query;
      }
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
          final gifs = (data['data'] as List)
              .map((gif) => gif['images']['fixed_height']['url'].toString())
              .toList();

          // Safely update the state
          Future(() {
            if (mounted) {
              ref.read(gifsProvider.notifier).state = gifs;
            }
          });
        } else {
          print('No GIFs found for query: $query');

          // Safely update the state
          Future(() {
            if (mounted) {
              ref.read(gifsProvider.notifier).state = [];
            }
          });
        }
      } else {
        print('Failed to search GIFs: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error searching GIFs: $e');
    } finally {
      // Safely update the loading state
      Future(() {
        if (mounted) {
          ref.read(isLoadingProvider.notifier).state = false;
        }
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

    // Clear typing indicator when sending a message
    _setTypingStatus(false);
    _typingTimer?.cancel();

    // Ensure IDs are stored as strings
    final senderMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
      'isDelivered': false, // New field for delivery status
    };

    final recipientMessage = {
      'senderId': currentUserId.toString(),
      'recipientId': widget.recipientId.toString(),
      'content': _messageController.text.trim(),
      'timestamp': Timestamp.now(),
      'isRead': false,
      'isSent': true,
      'isDelivered': false, // New field for delivery status
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

      // Mark message as delivered after a short delay (simulating network delay)
      Future.delayed(const Duration(milliseconds: 500), () {
        _updateMessageDeliveryStatus(senderMessage['timestamp'] as Timestamp);
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  // Update delivery status of messages
  Future<void> _updateMessageDeliveryStatus(Timestamp messageTimestamp) async {
    try {
      final conversationIdSender = "$currentUserId-${widget.recipientId}";
      final conversationIdRecipient = "${widget.recipientId}-$currentUserId";

      // Update in both conversation documents
      await _updateDeliveryInDocument(conversationIdSender, messageTimestamp);
      await _updateDeliveryInDocument(
          conversationIdRecipient, messageTimestamp);
    } catch (e) {
      print("Error updating message delivery status: $e");
    }
  }

  Future<void> _updateDeliveryInDocument(
      String docId, Timestamp messageTimestamp) async {
    try {
      final docRef = _messagesRef.doc(docId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final List<dynamic> messages = List.from(data['messages'] ?? []);
        bool updated = false;

        for (int i = 0; i < messages.length; i++) {
          final msg = messages[i];
          if (msg is Map<String, dynamic>) {
            final timestamp = msg['timestamp'];
            if (timestamp is Timestamp &&
                timestamp.seconds == messageTimestamp.seconds &&
                timestamp.nanoseconds == messageTimestamp.nanoseconds) {
              messages[i]['isDelivered'] = true;
              updated = true;
            }
          }
        }

        if (updated) {
          await docRef.update({'messages': messages});
        }
      }
    } catch (e) {
      print("Error updating delivery in document: $e");
    }
  }

  // More reliable scroll to bottom implementation
  void _scrollToBottom() {
    if (_isScrolling) return; // Prevent multiple scrolls

    _isScrolling = true;

    // Use Future to defer scrolling until after the current frame
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController
            .animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
            .then((_) {
          // Reset scrolling flag after animation completes
          if (mounted) {
            _isScrolling = false;
          }
        });
      } else {
        _isScrolling = false;
      }
    });
  }

  // Scroll to bottom immediately for initial build
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // Safe method to schedule one-time scroll to bottom
  void _safeScrollToBottomOnce() {
    if (_isFirstLoad && !_hasScheduledInitialScroll) {
      _hasScheduledInitialScroll = true;

      // Use additional Future.microtask to ensure widget tree is built
      Future.microtask(() {
        if (mounted) {
          _jumpToBottom(); // Use immediate jump for first load
          _isFirstLoad = false;
        }
      });
    }
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
      final conversationIdRecipient = "${widget.recipientId}-$currentUserId";

      // Delete both conversation documents
      await Future.wait([
        _messagesRef.doc(conversationIdSender).delete(),
        // Try to delete recipient's document but don't fail if it doesn't exist
        _messagesRef.doc(conversationIdRecipient).delete().catchError((e) {
          print("Note: Could not delete recipient conversation: $e");
          // Non-critical error, continue execution
        }),
      ]);

      // Set state flag to immediately reflect the deletion in UI
      if (mounted) {
        setState(() {
          _showLogoOnly = false;
          _messagesLoaded = false;
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Navigate back after deletion with a slight delay to ensure the snackbar is visible
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
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

  // Helper method to format dates for grouping messages
  String _getDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  // Improved scroll to bottom implementation to force scroll on first load
  void _forceScrollToBottom() {
    // Schedule multiple attempts to scroll to handle race conditions
    for (int delay = 50; delay <= 300; delay += 50) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && _scrollController.hasClients) {
          try {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          } catch (e) {
            print("Scroll attempt at ${delay}ms failed: $e");
          }
        }
      });
    }
  }

  // Override didUpdateWidget to ensure proper scrolling after widget updates
  @override
  void didUpdateWidget(MessagingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipientId != widget.recipientId) {
      _isFirstBuild = true;
      _isFirstLoad = true;
      _hasScheduledInitialScroll = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure we scroll to bottom when page is fully loaded
    if (_isFirstLoad) {
      _forceScrollToBottom();
    }
  }

  // Improved method to handle message loading completion
  void _onMessagesLoaded() {
    _isInitialLoading = false;
    _messagesLoaded = true;

    // Instead of calling setState directly, set a flag and schedule update
    _needsStateUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _needsStateUpdate) {
        setState(() {
          _showLogoOnly = false;
          _needsStateUpdate = false; // Reset flag
        });

        // Animate message opacity to full
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            ref.read(messageOpacityProvider.notifier).state = 1.0;
          }
        });
      }
    });

    // Reset scroll attempts counter and try again
    _scrollAttempts = 0;
    _attemptScrollToBottom();
  }

  // Improved scrolling method with multiple attempts
  void _attemptScrollToBottom() {
    if (_scrollAttempts >= _maxScrollAttempts) return;
    _scrollAttempts++;

    // First attempt is immediate
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }

    // Additional attempts with increasing delays
    for (int i = 1; i <= 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted && _scrollController.hasClients) {
          try {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          } catch (e) {
            print("Scroll attempt $i failed: $e");
          }
        }
      });
    }
  }

  // Helper method to safely update loading state
  void _hideLoadingState() {
    // Use post-frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _showLogoOnly = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // final darkThemeMain = ref.watch(darkTheme);
    // final langMain = ref.watch(lang);
    final recipientIsTyping = ref.watch(recipientTypingProvider);
    final messageOpacity =
        ref.watch(messageOpacityProvider); // Get message opacity state
    final recipientDataAsync =
        ref.watch(recipientDataProvider(widget.recipientId));
    final conversationId = "$currentUserId-${widget.recipientId}";

    // Schedule a scroll on initial build
    if (_isFirstBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _forceScrollToBottom();
      });
    }

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
                        Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          error: (_, __) => const Text(
            "Chat",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          loading: () {},
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
            // Message area with opacity animation
            Expanded(
              child: AnimatedOpacity(
                opacity: messageOpacity,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                child: Stack(
                  children: [
                    // ...existing code... (StreamBuilder section)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('messages')
                          .doc("$currentUserId-${widget.recipientId}")
                          .snapshots(),
                      builder: (context, snapshot) {
                        // Only when we start loading
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _isInitialLoading) {
                          return const SizedBox();
                        }

                        // Handle errors - FIXED: No setState during build
                        if (snapshot.hasError) {
                          // Mark for update after build instead of direct setState
                          _needsStateUpdate = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _needsStateUpdate) {
                              setState(() {
                                _showLogoOnly = false;
                                _needsStateUpdate = false;
                              });
                            }
                          });

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

                        // If primary conversation doesn't exist, check the reversed conversation ID
                        if (!snapshot.hasData || !(snapshot.data!.exists)) {
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('messages')
                                .doc("${widget.recipientId}-$currentUserId")
                                .snapshots(),
                            builder: (context, reverseSnapshot) {
                              if (reverseSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !_messagesLoaded) {
                                return const SizedBox();
                              }

                              if (!reverseSnapshot.hasData ||
                                  !reverseSnapshot.data!.exists) {
                                // Fix for refreshing loop - only update state once
                                if (_needsStateUpdate) {
                                  _needsStateUpdate =
                                      false; // Prevent multiple updates
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _showLogoOnly = false;
                                      });
                                    }
                                  });
                                }

                                // Enhanced empty state UI
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ... existing UI code for no messages ...
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.deepPurple.shade300,
                                              Colors.purpleAccent.shade100,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.deepPurple
                                                  .withOpacity(0.2),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.chat_outlined,
                                          size: 48,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'No messages yet',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.deepPurple.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 40),
                                        child: Text(
                                          'Send your first message to start a conversation',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.deepPurple.shade500,
                                              Colors.purpleAccent.shade400,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.deepPurple
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.arrow_downward,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Type a message below',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // If using the reverse conversation, parse messages from that
                              if (reverseSnapshot.hasData &&
                                  reverseSnapshot.data!.exists) {
                                // FIXED: Don't call setState-triggering methods in build
                                _needsStateUpdate = true;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted && _needsStateUpdate) {
                                    _isInitialLoading = false;
                                    _messagesLoaded = true;
                                    setState(() {
                                      _showLogoOnly = false;
                                      _needsStateUpdate = false;
                                    });
                                    _attemptScrollToBottom();
                                  }
                                });
                                return _buildMessageList(reverseSnapshot.data!);
                              }

                              return const SizedBox();
                            },
                          );
                        }

                        // Main conversation exists
                        // FIXED: Don't call setState-triggering methods in build
                        _needsStateUpdate = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _needsStateUpdate) {
                            _isInitialLoading = false;
                            _messagesLoaded = true;
                            setState(() {
                              _showLogoOnly = false;
                              _needsStateUpdate = false;
                            });
                            _attemptScrollToBottom();
                          }
                        });
                        return _buildMessageList(snapshot.data!);
                      },
                    ),

                    // Logo loading indicator remains the same
                    if (_showLogoOnly)
                      Container(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.message_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Messages',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Message input bar - same as before
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
                            onChanged: (value) {
                              // Detect typing and show typing indicator
                              _handleTyping();
                            },
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

  Widget _buildMessageList(DocumentSnapshot document) {
    try {
      final data = document.data() as Map<String, dynamic>;
      if (!data.containsKey('messages') || data['messages'] == null) {
        // FIXED: Don't update state directly in build method
        _needsStateUpdate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _needsStateUpdate) {
            setState(() {
              _showLogoOnly = false;
              _needsStateUpdate = false;
            });
          }
        });
        return const Center(child: Text('Start a conversation'));
      }

      final List<dynamic> messages =
          List.from(data['messages'] as List<dynamic>);

      // Ensure messages are sorted by timestamp
      messages.sort((a, b) {
        final timeA = (a['timestamp'] as Timestamp).toDate();
        final timeB = (b['timestamp'] as Timestamp).toDate();
        return timeA.compareTo(timeB);
      });

      // If building for the first time, trigger scroll
      if (_isFirstBuild) {
        _isFirstBuild = false;
        Future.microtask(() {
          if (mounted) {
            _attemptScrollToBottom();
          }
        });
      }

      // Group messages by date
      final Map<String, List<Map<String, dynamic>>> groupedMessages = {};

      for (var message in messages) {
        final timestamp = (message['timestamp'] as Timestamp).toDate();
        final dateGroup = _getDateGroup(timestamp);

        if (!groupedMessages.containsKey(dateGroup)) {
          groupedMessages[dateGroup] = [];
        }

        groupedMessages[dateGroup]!.add(message as Map<String, dynamic>);
      }

      // Create message widgets
      final List<Widget> messageWidgets = [];

      // Add date headers and message bubbles
      groupedMessages.forEach((dateGroup, messagesInGroup) {
        // Add date header
        messageWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  dateGroup,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );

        // Track conversation state
        String? lastSenderId;
        DateTime? lastMessageTime;

        // Add each message bubble
        for (int i = 0; i < messagesInGroup.length; i++) {
          final message = messagesInGroup[i];
          final String senderId = message['senderId'].toString();
          final bool isMe = senderId == currentUserId;
          final bool isGif = message['isGif'] == true;
          final messageText = message['content'] ?? 'No message';
          final timestamp = message['timestamp'] != null
              ? (message['timestamp'] as Timestamp).toDate()
              : DateTime.now();

          // Check if this message is part of a sequence
          final bool isSequential = lastSenderId == senderId;

          // Check if messages are close in time
          final bool isCloseInTime = lastMessageTime != null &&
              timestamp.difference(lastMessageTime!).inMinutes < 2;

          // Determine if we should show the time for this message
          final bool showTime = i == messagesInGroup.length - 1 ||
              messagesInGroup[i + 1]['senderId'].toString() != senderId ||
              !isCloseInTime;

          // Update tracking variables
          lastSenderId = senderId;
          lastMessageTime = timestamp;

          // Add the message bubble
          messageWidgets.add(
            GestureDetector(
              onDoubleTap: () {
                HapticFeedback.mediumImpact();
                _showReactionPicker(
                    message, "$currentUserId-${widget.recipientId}");
              },
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: showTime ? 4.0 : 2.0,
                  top: isSequential && isCloseInTime ? 2.0 : 8.0,
                ),
                child: Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            margin: EdgeInsets.only(
                              left: isMe ? 50 : 0,
                              right: isMe ? 0 : 50,
                            ),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.deepPurple.shade700,
                                        Colors.deepPurple.shade900,
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white,
                                        Colors.grey.shade100,
                                      ],
                                    ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
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
                                      ? Colors.deepPurple.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Message content
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: isGif
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            message['gifUrl'],
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child,
                                                loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return SizedBox(
                                                height: 150,
                                                child: Center(
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
                                                    color: isMe
                                                        ? Colors.white
                                                        : Colors.deepPurple,
                                                  ),
                                                ),
                                              );
                                            },
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                height: 100,
                                                width: 150,
                                                color: isMe
                                                    ? Colors.deepPurple.shade300
                                                    : Colors.grey[300],
                                                child: Center(
                                                  child: Icon(
                                                    Icons.broken_image,
                                                    color: isMe
                                                        ? Colors.white
                                                        : Colors.grey[600],
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
                                                : Colors.black87,
                                            fontSize: 16,
                                            height: 1.3,
                                          ),
                                        ),
                                ),

                                // Emoji reaction display
                                if (message['reaction'] != null)
                                  Positioned(
                                    bottom: -16,
                                    right: isMe ? null : -2,
                                    left: isMe ? -2 : null,
                                    child: AnimatedBuilder(
                                      animation: _reactionAnimController,
                                      builder: (context, child) {
                                        final scale = _lastReactedMessageId ==
                                                    "${(message['timestamp'] as Timestamp).seconds}-${message['content'].hashCode}" &&
                                                _reactionAnimController
                                                    .isAnimating
                                            ? 1.0 +
                                                _reactionAnimController.value *
                                                    0.5
                                            : 1.0;

                                        return Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 4,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              message['reaction'],
                                              style:
                                                  const TextStyle(fontSize: 16),
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

                      // Message timestamp and status
                      if (showTime)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 4,
                            left: 4,
                            right: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('h:mm a').format(timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: _buildMessageStatusIcon(message),
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
        }
      });

      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: messageWidgets,
      );
    } catch (e) {
      print("Error processing messages: $e");
      // FIXED: No setState during build
      _needsStateUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _needsStateUpdate) {
          setState(() {
            _showLogoOnly = false;
            _needsStateUpdate = false;
          });
        }
      });
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red[400]),
            const SizedBox(height: 12),
            const Text('There was an error displaying messages'),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }
  }

  // Helper widget for message status indicator
  Widget _buildMessageStatusIcon(Map<String, dynamic> message) {
    // Check message status - priority: read > delivered > sent
    if (message['isRead'] == true) {
      return const Icon(
        Icons.done_all,
        size: 14,
        color: Colors.blue,
      );
    } else if (message['isDelivered'] == true) {
      return Icon(
        Icons.done_all,
        size: 14,
        color: Colors.grey[500],
      );
    } else if (message['isSent'] == true) {
      return Icon(
        Icons.check,
        size: 14,
        color: Colors.grey[500],
      );
    } else {
      return Icon(
        Icons.access_time,
        size: 14,
        color: Colors.grey[400],
      );
    }
  }
}
