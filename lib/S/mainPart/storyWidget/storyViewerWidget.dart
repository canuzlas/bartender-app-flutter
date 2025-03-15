import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/mainSettings.dart'; // Add for language support

class StoryViewerWidget extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String userName;
  final String userImage;
  final VoidCallback onClose;
  // Add new callback functions
  final Function(String storyId, bool isLiked)? onLike;
  final Function(String storyId, String message)? onSendMessage;
  // Add new property to identify if it's the user's own story
  final bool isOwnStory;
  // Add index property to identify which highlight to delete
  final int? highlightIndex;

  const StoryViewerWidget({
    super.key,
    required this.stories,
    required this.userName,
    required this.userImage,
    required this.onClose,
    this.onLike,
    this.onSendMessage,
    this.isOwnStory = false, // Default to false for backward compatibility
    this.highlightIndex,
  });

  @override
  ConsumerState<StoryViewerWidget> createState() => _StoryViewerWidgetState();
}

class _StoryViewerWidgetState extends ConsumerState<StoryViewerWidget>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;
  final _storyDuration = const Duration(seconds: 5);
  Timer? _timer;
  bool _isPaused = false;
  final TextEditingController _messageController = TextEditingController();
  bool _showReplyBox = false;

  // Add a flag to track if the widget is in the process of being disposed
  bool _isDisposing = false;

  // Add a global key for Scaffold to access ScaffoldMessenger safely
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Cache language to avoid context access
  String? _cachedLanguage;

  // Add this line near other state variables
  Map<String, bool> _likedStories = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController =
        AnimationController(vsync: this, duration: _storyDuration);

    // Initialize liked state for all stories
    for (var story in widget.stories) {
      final storyId = story['id']?.toString() ?? '';
      final List<dynamic> likedBy = story['likedBy'] ?? [];
      _likedStories[storyId] =
          likedBy.contains(FirebaseAuth.instance.currentUser?.uid);
    }

    // Mark initial story as viewed - with null safety check
    if (_currentIndex < widget.stories.length) {
      final storyId = widget.stories[_currentIndex]['id'];
      if (storyId != null) {
        _markAsViewed(storyId.toString());
      }
    }

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    // Start animation after a short delay to ensure UI is built
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _loadStory();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the language when dependencies change
    _cachedLanguage = ref.read(lang);
  }

  @override
  void dispose() {
    // Set the flag before starting disposal process
    _isDisposing = true;

    // Cancel any pending operations
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }

    _animController.stop();
    _pageController.dispose();
    _animController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Safe method to check if we can use context
  bool get _canUseContext => mounted && !_isDisposing;

  // Safe language getter that doesn't depend on context
  String get _language => _cachedLanguage ?? 'en';

  // Safe method to show dialogs
  Future<T?> _safeShowDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) async {
    if (!_canUseContext) return null;
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: builder,
      );
    } catch (e) {
      print("Error showing dialog: $e");
      return null;
    }
  }

  // Safe method to show a snackbar without context
  void _showSnackBar(String message, {bool isError = false}) {
    if (!_canUseContext) return;

    try {
      // Use the global key if available
      if (_scaffoldMessengerKey.currentState != null) {
        _scaffoldMessengerKey.currentState!.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.green,
          ),
        );
      } else if (mounted) {
        // Fallback to context if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error showing snackbar: $e");
    }
  }

  void _loadStory() {
    if (!mounted) return;
    _animController.reset();
    _animController.forward();
  }

  void _nextStory() {
    setState(() {
      if (_currentIndex + 1 < widget.stories.length) {
        _currentIndex += 1;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _loadStory();
      } else {
        // Last story finished - ensure proper navigation
        widget.onClose();
        Navigator.of(context).pop();
      }
    });
  }

  void _previousStory() {
    setState(() {
      if (_currentIndex - 1 >= 0) {
        _currentIndex -= 1;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _loadStory();
      }
    });
  }

  void _pauseStory() {
    if (!_isPaused) {
      _isPaused = true;
      _animController.stop();
    }
  }

  void _resumeStory() {
    if (_isPaused) {
      _isPaused = false;
      _animController.forward();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    // Detect tap location (left or right)
    if (tapPosition < screenWidth / 3) {
      // Left tap - go to previous story
      _previousStory();
    } else if (tapPosition > screenWidth * 2 / 3) {
      // Right tap - go to next story
      _nextStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cache language at build time
    _cachedLanguage = ref.watch(lang);

    if (_currentIndex >= widget.stories.length) {
      // Handle edge case where current index might be out of bounds
      _currentIndex = widget.stories.length - 1;
    }

    final story = widget.stories[_currentIndex];
    // Add null safety check for storyId
    final storyId = story['id']?.toString() ?? '';

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey, // Assign global key here
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          // Apply SafeArea on all sides
          child: Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            // Add persistent bottom action bar
            bottomNavigationBar: _showReplyBox ? null : _buildBottomActionBar(),
            body: GestureDetector(
              onTapDown: (details) {
                if (!_showReplyBox) {
                  // Only handle taps if reply box is not shown
                  _onTapDown(details);
                }
              },
              onLongPress: _pauseStory,
              onLongPressEnd: (_) => _resumeStory(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Story content
                  PageView.builder(
                    controller: _pageController,
                    physics: _showReplyBox
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    itemCount: widget.stories.length,
                    onPageChanged: (index) {
                      if (index != _currentIndex) {
                        setState(() {
                          _currentIndex = index;
                          _loadStory();
                          // Add null check before casting to String
                          final storyId = widget.stories[index]['id'];
                          if (storyId != null) {
                            _markAsViewed(storyId.toString());
                          }
                        });
                      }
                    },
                    itemBuilder: (context, index) {
                      final storyItem = widget.stories[index];
                      return _buildStoryContent(storyItem);
                    },
                  ),

                  // UI Overlay (Progress, User info, Actions)
                  Column(
                    children: [
                      // Add extra padding for the status bar
                      SizedBox(
                          height: widget.isOwnStory
                              ? MediaQuery.of(context).padding.top
                              : 0),

                      // Progress indicator
                      Padding(
                        // Add extra padding for own stories to avoid notch area
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          children: widget.stories
                              .asMap()
                              .map((i, e) {
                                return MapEntry(
                                  i,
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2.0),
                                      height: 2.0,
                                      child: LinearProgressIndicator(
                                        value: i == _currentIndex
                                            ? _animController.value
                                            : i < _currentIndex
                                                ? 1.0
                                                : 0.0,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.4),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .values
                              .toList(),
                        ),
                      ),

                      // User info
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(widget.userImage),
                              radius: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              _formatTimestamp(story['timestamp']),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Fix close button
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                // First notify parent via callback if needed
                                widget.onClose();
                                // Then ensure we pop this screen
                                Navigator.of(context).pop();
                              },
                              padding: const EdgeInsets.all(8),
                            ),
                          ],
                        ),
                      ),

                      // Spacer to push action buttons to the bottom
                      const Spacer(),

                      // Delete button - shown for all own stories, not just highlights
                      if (widget.isOwnStory)
                        Padding(
                          padding: EdgeInsets.only(
                              bottom:
                                  16.0 + MediaQuery.of(context).padding.bottom,
                              left: 16.0,
                              right: 16.0),
                          child: ElevatedButton.icon(
                            onPressed: () => _confirmDeleteHighlight(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 20.0),
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              ref.watch(lang) == 'tr'
                                  ? 'Bu Hikayeyi Sil'
                                  : 'Delete This Story',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),

                      // Reply Box (keeping this section for backward compatibility)
                      if (_showReplyBox)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          color: Colors.black.withOpacity(0.8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: ref.watch(lang) == 'tr'
                                            ? 'Mesajınızı yazın...'
                                            : 'Type your message...',
                                        hintStyle: const TextStyle(
                                            color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(25.0),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white24,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 12.0,
                                        ),
                                      ),
                                      autofocus: true,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send,
                                        color: Colors.white),
                                    onPressed: () {
                                      _sendMessage(storyId);
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _showReplyBox = false;
                                        _messageController.clear();
                                      });
                                      _resumeStory();
                                    },
                                    child: Text(
                                      ref.watch(lang) == 'tr'
                                          ? 'İptal'
                                          : 'Cancel',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add new method to build the bottom action bar
  Widget _buildBottomActionBar() {
    final isCurrentUserStory = widget.stories.isNotEmpty &&
        widget.stories[0]['userId'] == FirebaseAuth.instance.currentUser?.uid;

    final darkThemeMain = ref.watch(darkTheme);
    final primaryColor =
        darkThemeMain ? Colors.orangeAccent : Colors.deepOrange;

    return Container(
      color: Colors.black.withOpacity(0.7),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom,
        top: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Add Info Button for story owner
          if (isCurrentUserStory)
            _buildIconButton(
              icon: Icons.info_outline,
              label: ref.watch(lang) == 'tr' ? 'Bilgi' : 'Info',
              color: Colors.blue,
              onTap: () => _showStoryInfo(widget.stories[_currentIndex]),
            ),

          // Delete Button - only shown if it's the user's own story
          if (isCurrentUserStory)
            _buildIconButton(
              icon: Icons.delete_outline,
              label: ref.watch(lang) == 'tr' ? 'Sil' : 'Delete',
              color: Colors.red,
              onTap: () {
                _confirmDeleteHighlight();
              },
            ),

          // Like Button - only if not current user's story
          if (!isCurrentUserStory)
            _buildIconButton(
              icon: _isLiked() ? Icons.favorite : Icons.favorite_border,
              label: ref.watch(lang) == 'tr' ? 'Beğen' : 'Like',
              color: _isLiked() ? Colors.red : Colors.white,
              onTap: _handleLike, // Use the new method here
            ),

          // Reply Button - only if not current user's story
          if (!isCurrentUserStory)
            _buildIconButton(
              icon: Icons.reply,
              label: ref.watch(lang) == 'tr' ? 'Yanıtla' : 'Reply',
              color: Colors.white,
              onTap: () {
                setState(() {
                  _showReplyBox = true;
                  _pauseStory();
                });
              },
            ),
        ],
      ),
    );
  }

  // Helper method to build icon buttons with consistent style
  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Map<String, dynamic> storyItem) {
    if (storyItem['media'] != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Media content
          Image.network(
            storyItem['media'],
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              _pauseStory();
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              _resumeStory();
              return const Center(
                child: Icon(Icons.error_outline, color: Colors.white, size: 48),
              );
            },
          ),

          // Description overlay if available
          if (storyItem['description'] != null &&
              storyItem['description'] != '')
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  storyItem['description'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    } else if (storyItem['description'] != null &&
        storyItem['description'] != '') {
      // Text-only story
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            storyItem['description'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      // Fallback
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'No content available',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
  }

  void _sendMessage(String storyId) {
    if (!_canUseContext || storyId.isEmpty) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // First update UI state while we're definitely still mounted
    setState(() {
      _showReplyBox = false;
    });
    _messageController.clear();
    _resumeStory();

    // Then handle the async work in a detached Future
    Future.microtask(() async {
      try {
        final String currentUserId =
            FirebaseAuth.instance.currentUser?.uid ?? '';
        if (currentUserId.isEmpty) return;

        // Get the story to find the recipient user
        final storyDoc = await FirebaseFirestore.instance
            .collection('stories')
            .doc(storyId)
            .get();

        if (!storyDoc.exists) return;

        final storyData = storyDoc.data() as Map<String, dynamic>;
        final String recipientId = storyData['userId'] as String? ?? '';

        if (recipientId.isEmpty || recipientId == currentUserId) return;

        // Create messages
        final senderMessage = {
          'senderId': currentUserId.toString(),
          'recipientId': recipientId.toString(),
          'content': message,
          'timestamp': Timestamp.now(),
          'isRead': false,
          'isSent': true,
          'isStoryReply': true,
          'storyId': storyId,
        };

        final recipientMessage = Map<String, dynamic>.from(senderMessage);

        // Create conversation references
        final conversationIdSender = "$currentUserId-$recipientId";
        final conversationIdRecipient = "$recipientId-$currentUserId";
        final conversationRefSender = FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationIdSender);
        final conversationRefRecipient = FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationIdRecipient);

        // Execute operations without depending on UI state
        final batch = FirebaseFirestore.instance.batch();

        // Get conversation documents
        final senderSnap = await conversationRefSender.get();
        final recipientSnap = await conversationRefRecipient.get();

        // Update or create conversations
        if (senderSnap.exists) {
          batch.update(conversationRefSender, {
            'messages': FieldValue.arrayUnion([senderMessage]),
            'lastMessage': senderMessage['content'],
            'timestamp': senderMessage['timestamp'],
          });
        } else {
          batch.set(conversationRefSender, {
            'senderId': currentUserId,
            'recipientId': recipientId,
            'messages': [senderMessage],
            'lastMessage': senderMessage['content'],
            'timestamp': senderMessage['timestamp'],
            'participants': [currentUserId, recipientId],
          });
        }

        if (recipientSnap.exists) {
          batch.update(conversationRefRecipient, {
            'messages': FieldValue.arrayUnion([recipientMessage]),
            'lastMessage': recipientMessage['content'],
            'timestamp': recipientMessage['timestamp'],
          });
        } else {
          batch.set(conversationRefRecipient, {
            'senderId': recipientId,
            'recipientId': currentUserId,
            'messages': [recipientMessage],
            'lastMessage': recipientMessage['content'],
            'timestamp': recipientMessage['timestamp'],
            'participants': [recipientId, currentUserId],
          });
        }

        // Commit all operations atomically
        await batch.commit();

        // Notify the parent widget if available and widget is still mounted
        if (_canUseContext && widget.onSendMessage != null) {
          widget.onSendMessage!(storyId, message);
        }
      } catch (e) {
        print("Error sending message: $e");

        // Only show error message if widget is still mounted
        if (_canUseContext) {
          _showSnackBar(
              _language == 'tr'
                  ? 'Mesaj gönderilemedi'
                  : 'Failed to send message',
              isError: true);
        }
      }
    });
  }

  // Add method to view current user's stories
  void _viewMyStories() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || !_canUseContext) return;

    try {
      // Show loading indicator
      _showSnackBar(_language == 'tr'
          ? 'Hikayeleriniz yükleniyor...'
          : 'Loading your stories...');

      // Fetch current user's active stories
      final storiesQuery = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: currentUserId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: true)
          .get();

      if (storiesQuery.docs.isEmpty) {
        if (_canUseContext) {
          _showSnackBar(
              _language == 'tr'
                  ? 'Aktif hikayeniz bulunmuyor'
                  : 'You have no active stories',
              isError: true);
        }
        return;
      }

      // Get current user's information
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      String userName = FirebaseAuth.instance.currentUser?.displayName ?? 'You';
      String userImage = FirebaseAuth.instance.currentUser?.photoURL ??
          'https://picsum.photos/100';

      // Update with user info from Firestore if available
      if (userSnapshot.exists) {
        final userData = userSnapshot.data();
        if (userData != null) {
          userName = userData['displayname'] ?? userName;
          userImage = userData['photoURL'] ?? userImage;
        }
      }

      // Convert query results to story items
      List<Map<String, dynamic>> storyItems = storiesQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'media': data['media'],
          'description': data['description'] ?? '',
          'timestamp': data['timestamp'],
          'userId': data['userId'],
          'viewedBy': data['viewedBy'] ?? [],
          'likedBy': data['likedBy'] ?? [],
        };
      }).toList();

      // Navigate to view the stories
      if (_canUseContext) {
        // First close current story viewer
        Navigator.of(context).pop();

        // Then open new story viewer with user's stories
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => StoryViewerWidget(
              stories: storyItems,
              userName: userName,
              userImage: userImage,
              isOwnStory: true,
              onClose: () {
                // Use the same onClose as the parent widget
                widget.onClose();
              },
              onLike: widget.onLike,
              onSendMessage: widget.onSendMessage,
            ),
            transitionsBuilder: (context, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      print("Error loading user stories: $e");
      if (_canUseContext) {
        _showSnackBar(
            _language == 'tr'
                ? 'Hikayeler yüklenirken hata oluştu'
                : 'Error loading stories',
            isError: true);
      }
    }
  }

  // Helper method to mark stories as viewed - with improved safety
  void _markAsViewed(String storyId) {
    if (storyId.isEmpty || _isDisposing) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Use a detached Future to avoid context dependency
        Future.microtask(() {
          // Additional check in case widget is disposed during async gap
          if (_isDisposing) return;

          FirebaseFirestore.instance.collection('stories').doc(storyId).update({
            'viewedBy': FieldValue.arrayUnion([currentUser.uid])
          }).catchError((error) {
            print("Error marking story as viewed: $error");
          });
        });
      }
    } catch (e) {
      print("Error marking story as viewed: $e");
    }
  }

  // New method to confirm story deletion with improved safety
  void _confirmDeleteHighlight() {
    if (!_canUseContext) return;

    _pauseStory(); // Pause the story while dialog is shown

    _safeShowDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async {
              _resumeStory(); // Resume story playback on back button
              return true;
            },
            child: AlertDialog(
              title: Text(
                _language == 'tr' ? 'Hikayeyi Sil' : 'Delete Story',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(_language == 'tr'
                  ? 'Bu hikaye kalıcı olarak silinecek. Emin misiniz?'
                  : 'This story will be permanently deleted. Are you sure?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _resumeStory(); // Resume story playback
                  },
                  child: Text(
                    _language == 'tr' ? 'İptal' : 'Cancel',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (_canUseContext) {
                      _deleteHighlight();
                    }
                  },
                  child: Text(
                    _language == 'tr' ? 'Evet, Sil' : 'Yes, Delete',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        });
  }

  // Improved method for highlight deletion with completely safe context handling
  void _deleteHighlight() {
    if (!_canUseContext) return; // Remove the widget.highlightIndex check

    // Show loading dialog with safe context handling
    BuildContext? dialogContext;

    _safeShowDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return WillPopScope(
          onWillPop: () async => false, // Prevent dismissal with back button
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(_language == 'tr' ? 'Siliniyor...' : 'Deleting...'),
              ],
            ),
          ),
        );
      },
    );

    // Handle the actual deletion in a detached context
    Future.microtask(() async {
      try {
        // Get current user ID
        final String currentUserId =
            FirebaseAuth.instance.currentUser?.uid ?? '';
        if (currentUserId.isEmpty) {
          _closeDialogSafely(dialogContext);
          if (_canUseContext) {
            _showSnackBar(
                _language == 'tr'
                    ? 'Kimlik doğrulama hatası'
                    : 'Authentication error',
                isError: true);
          }
          return;
        }

        // Get the story ID to delete
        final storyId = widget.stories[_currentIndex]['id'];
        if (storyId == null) {
          _closeDialogSafely(dialogContext);
          if (_canUseContext) {
            _showSnackBar(
                _language == 'tr' ? 'Hikaye bulunamadı' : 'Story not found',
                isError: true);
          }
          return;
        }

        // Delete the story from Firestore
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(storyId.toString())
            .delete();

        // Close loading dialog
        _closeDialogSafely(dialogContext);

        // Only show success and close if still mounted
        if (_canUseContext) {
          _showSnackBar(_language == 'tr' ? 'Hikaye silindi' : 'Story deleted');

          // Close the story viewer after deletion
          Navigator.of(context).pop();

          // Then call onClose callback if provided
          widget.onClose();
        }
      } catch (e) {
        print("Error deleting highlight: $e");

        // Close dialog safely
        _closeDialogSafely(dialogContext);

        // Show error if still mounted
        if (_canUseContext) {
          _showSnackBar(
              _language == 'tr'
                  ? 'Hikaye silinirken bir hata oluştu'
                  : 'Error deleting story',
              isError: true);
        }
      }
    });
  }

  // Helper method to safely close dialogs
  void _closeDialogSafely(BuildContext? dialogContext) {
    if (dialogContext != null && !_isDisposing) {
      try {
        if (Navigator.canPop(dialogContext)) {
          Navigator.of(dialogContext, rootNavigator: true).pop();
        }
      } catch (e) {
        print("Error closing dialog: $e");
      }
    }
  }

  bool _isLiked() {
    final currentStory = widget.stories[_currentIndex];
    final storyId = currentStory['id']?.toString() ?? '';
    return _likedStories[storyId] ?? false;
  }

  // Add this new method
  void _handleLike() {
    final storyId = widget.stories[_currentIndex]['id']?.toString();
    if (storyId == null) return;

    setState(() {
      _likedStories[storyId] = !(_likedStories[storyId] ?? false);
    });

    if (widget.onLike != null) {
      widget.onLike!(storyId, _likedStories[storyId] ?? false);
    }
  }

  // Add new method to show story info
  void _showStoryInfo(Map<String, dynamic> story) async {
    _pauseStory(); // Pause the story while showing info

    final viewedBy = List<String>.from(story['viewedBy'] ?? []);
    final likedBy = List<String>.from(story['likedBy'] ?? []);
    final isDarkTheme = ref.watch(darkTheme);
    final language = ref.watch(lang);

    // Get user details for viewers and likers
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId,
            whereIn: [...viewedBy, ...likedBy].toSet().toList())
        .get();

    if (!mounted) return;

    final userDetails = Map.fromEntries(
      usersSnapshot.docs.map((doc) => MapEntry(
            doc.id,
            {
              'displayname': doc.data()['displayname'] ?? 'Unknown User',
              'photoURL': doc.data()['photoURL'] ?? 'https://picsum.photos/100',
            },
          )),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                tabs: [
                  Tab(
                    text:
                        '${language == 'tr' ? 'Görüntüleyenler' : 'Views'} (${viewedBy.length})',
                  ),
                  Tab(
                    text:
                        '${language == 'tr' ? 'Beğenenler' : 'Likes'} (${likedBy.length})',
                  ),
                ],
                labelColor: isDarkTheme ? Colors.white : Colors.black,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: TabBarView(
                  children: [
                    _buildUserList(
                        viewedBy, userDetails, isDarkTheme, language),
                    _buildUserList(likedBy, userDetails, isDarkTheme, language),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => _resumeStory());
  }

  Widget _buildUserList(
      List<String> userIds,
      Map<String, Map<String, dynamic>> userDetails,
      bool isDarkTheme,
      String language) {
    if (userIds.isEmpty) {
      return Center(
        child: Text(
          language == 'tr' ? 'Henüz kimse yok' : 'No one yet',
          style: TextStyle(
            color: isDarkTheme ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        final user = userDetails[userId];
        if (user == null) return const SizedBox.shrink();

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(user['photoURL'] as String),
          ),
          title: Text(
            user['displayname'] as String,
            style: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp == null) return '';

      DateTime dateTime;
      if (timestamp is DateTime) {
        dateTime = timestamp;
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        // Handle Firestore Timestamp
        dateTime = timestamp.toDate();
      } else {
        // Fallback for other timestamp formats
        return '';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      print("Error formatting timestamp: $e");
      return '';
    }
  }
}
