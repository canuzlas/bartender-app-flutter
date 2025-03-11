import 'dart:async';

import 'package:bartender/S/mainPart/discoverScreen/discoverScreenMain.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

// Create a class to hold comments state
class CommentsState {
  final bool isLoading;
  final List<QueryDocumentSnapshot<Object?>> comments;
  final String? error;

  CommentsState({
    required this.isLoading,
    required this.comments,
    this.error,
  });

  CommentsState copyWith({
    bool? isLoading,
    List<QueryDocumentSnapshot<Object?>>? comments,
    String? error,
  }) {
    return CommentsState(
      isLoading: isLoading ?? this.isLoading,
      comments: comments ?? this.comments,
      error: error ?? this.error,
    );
  }
}

// Notifier to manage comments
class CommentsNotifier extends StateNotifier<CommentsState> {
  final String tweetId;
  StreamSubscription<QuerySnapshot>? _subscription;

  CommentsNotifier(this.tweetId)
      : super(CommentsState(isLoading: true, comments: [])) {
    _loadComments();
  }

  void _loadComments() {
    // Cancel any existing subscription
    _subscription?.cancel();

    // Set loading state
    state = CommentsState(isLoading: true, comments: []);

    // Create a new subscription
    _subscription = FirebaseFirestore.instance
        .collection('tweets')
        .doc(tweetId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .listen(
      (snapshot) {
        state = CommentsState(
          isLoading: false,
          comments: snapshot.docs,
          error: null,
        );
      },
      onError: (e) {
        state = CommentsState(
          isLoading: false,
          comments: [],
          error: e.toString(),
        );
      },
    );
  }

  void refresh() {
    _loadComments();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Create providers
final isSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);
final replyingToProvider = StateProvider.autoDispose<String?>((ref) => null);
final replyingToNameProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// CommentsNotifier provider
final commentsProvider =
    StateNotifierProvider.family<CommentsNotifier, CommentsState, String>(
  (ref, tweetId) => CommentsNotifier(tweetId),
);

class CommentsPage extends ConsumerStatefulWidget {
  final String tweetId;
  const CommentsPage({super.key, required this.tweetId});

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _timeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final String currentUserId = auth.currentUser!.uid;
    final String commentText = _commentController.text.trim();

    // Clear text field immediately for better UX
    _commentController.clear();

    // Use Riverpod to update submitting state
    ref.read(isSubmittingProvider.notifier).state = true;

    try {
      // Get current reply state from providers
      final replyingTo = ref.read(replyingToProvider);

      // Prepare comment data
      final commentData = {
        'text': commentText,
        'timestamp': Timestamp.now(),
        'userId': currentUserId,
        if (replyingTo != null) 'replyTo': replyingTo,
      };

      // Clear replying state before Firestore operation to prevent double update
      if (replyingTo != null) {
        ref.read(replyingToProvider.notifier).state = null;
        ref.read(replyingToNameProvider.notifier).state = null;
      }

      // Add to Firestore without triggering state updates
      await FirebaseFirestore.instance
          .collection('tweets')
          .doc(widget.tweetId)
          .collection('comments')
          .add(commentData);

      // Auto-scroll to bottom after adding comment
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e')),
        );
      }
    } finally {
      // Update submitting state through provider
      if (mounted) {
        ref.read(isSubmittingProvider.notifier).state = false;
      }
    }
  }

  void _handleReply(String commentId, String userName) {
    ref.read(replyingToProvider.notifier).state = commentId;
    ref.read(replyingToNameProvider.notifier).state = userName;

    _focusNode.requestFocus();
    _commentController.text = '@$userName ';
  }

  void _cancelReply() {
    ref.read(replyingToProvider.notifier).state = null;
    ref.read(replyingToNameProvider.notifier).state = null;

    _commentController.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final String currentUserId = auth.currentUser!.uid;

    // Use Riverpod to watch state
    final isSubmitting = ref.watch(isSubmittingProvider);
    final replyingTo = ref.watch(replyingToProvider);
    final replyingToName = ref.watch(replyingToNameProvider);

    // Watch comments with our new provider
    final commentsState = ref.watch(commentsProvider(widget.tweetId));

    final textColor = darkThemeMain ? Colors.white : Colors.black87;
    const accentColor = Colors.blue;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: darkThemeMain ? Colors.black : Colors.grey[100],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: darkThemeMain ? Colors.black : Colors.white,
          foregroundColor: textColor,
          centerTitle: true,
          title: Text(
            langMain == "tr" ? "Yorumlar" : 'Comments',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: accentColor,
                onRefresh: () async {
                  // Use the notifier to refresh comments
                  ref.read(commentsProvider(widget.tweetId).notifier).refresh();
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: Builder(
                  builder: (context) {
                    // Handle loading state
                    if (commentsState.isLoading) {
                      return const Center(
                          child: CircularProgressIndicator(color: accentColor));
                    }

                    // Handle error state
                    if (commentsState.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 60,
                                color: darkThemeMain
                                    ? Colors.red[300]
                                    : Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error: ${commentsState.error}',
                                style: TextStyle(
                                  color: darkThemeMain
                                      ? Colors.red[300]
                                      : Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => ref
                                    .read(commentsProvider(widget.tweetId)
                                        .notifier)
                                    .refresh(),
                                child: Text(langMain == "tr"
                                    ? "Tekrar Dene"
                                    : "Try Again"),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final comments = commentsState.comments;

                    // Handle empty state
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 70,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              langMain == "tr"
                                  ? "Henüz yorum yok"
                                  : "No comments yet",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              langMain == "tr"
                                  ? "İlk yorumu sen bırak!"
                                  : "Be the first to comment!",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show comments list
                    return ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final commentData =
                            comment.data() as Map<String, dynamic>;

                        // Check if the comment contains a userId
                        if (!commentData.containsKey('userId')) {
                          return _buildEnhancedCommentCard(
                            context,
                            darkThemeMain,
                            textColor,
                            null, // No user data for anonymous comment
                            commentData,
                            false, // Not current user's comment
                            comment['timestamp']?.toDate() ?? DateTime.now(),
                            null, // No comment ID
                            langMain,
                          );
                        }

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(commentData['userId'])
                              .get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return _buildCommentCardSkeleton(darkThemeMain);
                            }

                            if (userSnapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: darkThemeMain
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.red[300]!, width: 1),
                                ),
                                child: Text(
                                  'Error loading user: ${userSnapshot.error}',
                                  style: TextStyle(color: Colors.red[300]),
                                ),
                              );
                            }

                            final userDoc = userSnapshot.data;
                            final userData =
                                userDoc?.data() as Map<String, dynamic>?;

                            final isCurrentUserComment =
                                commentData['userId'] == currentUserId;

                            return _buildEnhancedCommentCard(
                              context,
                              darkThemeMain,
                              textColor,
                              userData,
                              commentData,
                              isCurrentUserComment,
                              comment['timestamp']?.toDate() ?? DateTime.now(),
                              comment.id,
                              langMain,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Reply indicator
            if (replyingTo != null)
              Container(
                color: darkThemeMain ? Colors.grey[850] : Colors.grey[200],
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${langMain == "tr" ? "Yanıtlanıyor" : "Replying to"}: $replyingToName',
                        style: TextStyle(
                          color: darkThemeMain
                              ? Colors.grey[400]
                              : Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: Colors.grey[600],
                      onPressed: _cancelReply,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                  ],
                ),
              ),

            // Comment input field
            Container(
              decoration: BoxDecoration(
                color: darkThemeMain ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: darkThemeMain
                              ? Colors.grey[800]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(24.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            style: TextStyle(
                              color:
                                  darkThemeMain ? Colors.white : Colors.black,
                            ),
                            controller: _commentController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 4,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintStyle: TextStyle(
                                  color: darkThemeMain
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                              hintText: langMain == "tr"
                                  ? "Bir yorum ekle..."
                                  : 'Add a comment...',
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isSubmitting ? Colors.grey : accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                            width: 40, height: 40),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.send,
                                color: Colors.white, size: 20),
                        onPressed: isSubmitting ? null : _submitComment,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCardSkeleton(bool darkTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 100,
      decoration: BoxDecoration(
        color: darkTheme ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: darkTheme ? Colors.grey[700] : Colors.grey[300],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      color: darkTheme ? Colors.grey[700] : Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: darkTheme ? Colors.grey[700] : Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: darkTheme ? Colors.grey[700] : Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedCommentCard(
    BuildContext context,
    bool darkTheme,
    Color textColor,
    Map<String, dynamic>? userData,
    Map<String, dynamic> commentData,
    bool isCurrentUserComment,
    DateTime timestamp,
    String? commentId,
    String langMain,
  ) {
    final displayName = userData?['displayname'] ?? 'Unknown';
    final photoUrl = userData?['photoURL'] ?? 'https://picsum.photos/200';
    final commentText = commentData['text'] as String;
    final isReply = commentData.containsKey('replyTo');

    // Determine card color based on theme and if it's user's comment
    final cardColor = darkTheme
        ? (isCurrentUserComment
            ? const Color(0xFF1E3A5F)
            : const Color(0xFF212121))
        : (isCurrentUserComment ? const Color(0xFFE3F2FD) : Colors.white);

    // Accent color for current user's comment
    final accentLineColor =
        isCurrentUserComment ? const Color(0xFF4FC3F7) : Colors.transparent;

    // Check if the comment is a reply
    Widget replyIndicator = const SizedBox.shrink();
    if (isReply) {
      replyIndicator = Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.reply,
              size: 14,
              color: darkTheme ? Colors.grey[500] : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              langMain == "tr" ? "Yanıt" : "Reply",
              style: TextStyle(
                fontSize: 12,
                color: darkTheme ? Colors.grey[500] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () {
            // Copy comment to clipboard
            Clipboard.setData(ClipboardData(text: commentText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(langMain == "tr"
                    ? "Yorum panoya kopyalandı"
                    : "Comment copied to clipboard"),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent line for user's comments
                if (isCurrentUserComment)
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentLineColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply indicator if this is a reply
                        replyIndicator,

                        // User info row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar with border
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrentUserComment
                                      ? (darkTheme
                                          ? Colors.blue[400]!
                                          : Colors.blue[300]!)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.grey[400]!,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                          child: Icon(Icons.person,
                                              color: Colors.grey[400])),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name and timestamp column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: darkTheme
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _timeAgo(timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: darkTheme
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Action buttons
                            Row(
                              children: [
                                // Reply button
                                if (commentId != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.reply,
                                      size: 18,
                                      color: darkTheme
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                    onPressed: () =>
                                        _handleReply(commentId, displayName),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                  ),

                                // Delete button for user's comments
                                if (isCurrentUserComment && commentId != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: darkTheme
                                          ? Colors.red[300]
                                          : Colors.red,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: darkTheme
                                              ? Colors.grey[850]
                                              : Colors.white,
                                          title: Text(
                                            langMain == "tr"
                                                ? "Yorumu Sil"
                                                : "Delete Comment",
                                            style: TextStyle(
                                              color: darkTheme
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          content: Text(
                                            langMain == "tr"
                                                ? "Bu yorumu silmek istediğinizden emin misiniz?"
                                                : "Are you sure you want to delete this comment?",
                                            style: TextStyle(
                                              color: darkTheme
                                                  ? Colors.grey[300]
                                                  : Colors.grey[800],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: Text(
                                                langMain == "tr"
                                                    ? "İptal"
                                                    : "Cancel",
                                                style: const TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                FirebaseFirestore.instance
                                                    .collection('tweets')
                                                    .doc(widget.tweetId)
                                                    .collection('comments')
                                                    .doc(commentId)
                                                    .delete();
                                              },
                                              child: Text(
                                                langMain == "tr"
                                                    ? "Sil"
                                                    : "Delete",
                                                style: const TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 30, minHeight: 30),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // Comment text
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 6),
                          child: Text(
                            commentText,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                              color: darkTheme
                                  ? Colors.grey[300]
                                  : Colors.grey[850],
                            ),
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
      ),
    );
  }
}
