import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

  const StoryViewerWidget({
    Key? key,
    required this.stories,
    required this.userName,
    required this.userImage,
    required this.onClose,
    this.onLike,
    this.onSendMessage,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController =
        AnimationController(vsync: this, duration: _storyDuration);

    // Mark initial story as viewed
    _markAsViewed(widget.stories[_currentIndex]['id'] as String);

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    // Start animation after a short delay to ensure UI is built
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _loadStory();
      }
    });
  }

  @override
  void dispose() {
    _animController.stop();
    _pageController.dispose();
    _animController.dispose();
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
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
        // Last story finished
        widget.onClose();
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
    if (_currentIndex >= widget.stories.length) {
      // Handle edge case where current index might be out of bounds
      _currentIndex = widget.stories.length - 1;
    }

    final story = widget.stories[_currentIndex];
    final storyId = story['id'] as String;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
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
                  physics:
                      _showReplyBox ? NeverScrollableScrollPhysics() : null,
                  itemCount: widget.stories.length,
                  onPageChanged: (index) {
                    if (index != _currentIndex) {
                      setState(() {
                        _currentIndex = index;
                        _loadStory();
                        _markAsViewed(widget.stories[index]['id'] as String);
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
                    // Progress indicator
                    Padding(
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
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                    ),

                    // Spacer to push action buttons to the bottom
                    const Spacer(),

                    // Bottom action bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: _isLiked()
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isLiked() ? Colors.red : Colors.white,
                            label: _isLiked()
                                ? (ref.watch(lang) == 'tr'
                                    ? 'Beğenildi'
                                    : 'Liked')
                                : (ref.watch(lang) == 'tr' ? 'Beğen' : 'Like'),
                            onTap: () {
                              if (widget.onLike != null) {
                                widget.onLike!(storyId, !_isLiked());

                                // Update local state immediately for better UX
                                setState(() {
                                  final currentStory =
                                      widget.stories[_currentIndex];
                                  final List<dynamic> likedBy =
                                      List<dynamic>.from(
                                          currentStory['likedBy'] ?? []);
                                  final String currentUserId =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                          '';

                                  if (!_isLiked()) {
                                    if (!likedBy.contains(currentUserId)) {
                                      likedBy.add(currentUserId);
                                    }
                                  } else {
                                    likedBy.remove(currentUserId);
                                  }

                                  // Update the local copy
                                  widget.stories[_currentIndex]['likedBy'] =
                                      likedBy;
                                });
                              }
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.reply,
                            color: Colors.white,
                            label:
                                ref.watch(lang) == 'tr' ? 'Yanıtla' : 'Reply',
                            onTap: () {
                              _pauseStory();
                              setState(() {
                                _showReplyBox = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Reply Box
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
                                    style: const TextStyle(color: Colors.white),
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
                                    style:
                                        const TextStyle(color: Colors.white70),
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
                padding: EdgeInsets.all(8),
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

  void _sendMessage(String storyId) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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

      // Create messages using the new schema
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

      final recipientMessage = {
        'senderId': currentUserId.toString(),
        'recipientId': recipientId.toString(),
        'content': message,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'isSent': true,
        'isStoryReply': true,
        'storyId': storyId,
      };

      final conversationIdSender = "$currentUserId-$recipientId";
      final conversationIdRecipient = "$recipientId-$currentUserId";
      final conversationRefSender = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationIdSender);
      final conversationRefRecipient = FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationIdRecipient);

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
          'recipientId': recipientId,
          'messages': [senderMessage],
          'lastMessage': senderMessage['content'],
          'timestamp': senderMessage['timestamp'],
          'participants': [currentUserId, recipientId],
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
          'senderId': recipientId,
          'recipientId': currentUserId,
          'messages': [recipientMessage],
          'lastMessage': recipientMessage['content'],
          'timestamp': recipientMessage['timestamp'],
          'participants': [recipientId, currentUserId],
        });
      }

      _messageController.clear();
      setState(() {
        _showReplyBox = false;
      });

      // Notify the parent widget if callback exists
      if (widget.onSendMessage != null) {
        widget.onSendMessage!(storyId, message);
      }

      _resumeStory();
    } catch (e) {
      print("Error sending message: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.watch(lang) == 'tr'
              ? 'Mesaj gönderilemedi'
              : 'Failed to send message'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
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
            Icon(icon, color: color, size: 28),
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

  bool _isLiked() {
    final currentStory = widget.stories[_currentIndex];
    final List<dynamic> likedBy = currentStory['likedBy'] ?? [];
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return likedBy.contains(currentUserId);
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

  // Helper method to mark stories as viewed
  void _markAsViewed(String storyId) {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        FirebaseFirestore.instance.collection('stories').doc(storyId).update({
          'viewedBy': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    } catch (e) {
      print("Error marking story as viewed: $e");
    }
  }
}
