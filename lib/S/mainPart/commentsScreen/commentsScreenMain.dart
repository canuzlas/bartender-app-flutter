import 'package:bartender/S/mainPart/discoverScreen/discoverScreenMain.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommentsPage extends ConsumerWidget {
  final String tweetId;
  const CommentsPage({super.key, required this.tweetId});

  String _timeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final TextEditingController controller = TextEditingController();
    final String currentUserId = auth.currentUser!.uid;

    final themeColor = darkThemeMain ? Colors.grey[800] : Colors.white;
    final textColor = darkThemeMain ? Colors.white : Colors.black87;
    const accentColor = Colors.blue;

    return Scaffold(
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
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tweets')
                  .doc(tweetId)
                  .collection('comments')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: accentColor));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.red[300]),
                    ),
                  );
                }
                final comments = snapshot.data?.docs ?? [];

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
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final commentData = comment.data() as Map<String, dynamic>;
                    // Check if the comment contains a userId.
                    if (!commentData.containsKey('userId')) {
                      return _buildEnhancedCommentCard(
                        context,
                        darkThemeMain,
                        textColor,
                        null, // No user data for anonymous comment
                        commentData,
                        false, // Not current user's comment
                        commentData['timestamp']?.toDate() ?? DateTime.now(),
                        null, // No comment ID
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 100,
                            decoration: BoxDecoration(
                              color: darkThemeMain
                                  ? Colors.grey[850]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    darkThemeMain
                                        ? Colors.white70
                                        : Colors.blue[300]!,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        if (userSnapshot.hasError) {
                          return ListTile(
                            title: Text('Error: ${userSnapshot.error}'),
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
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
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
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          darkThemeMain ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        style: TextStyle(
                            color: darkThemeMain ? Colors.white : Colors.black),
                        controller: controller,
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
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 40, height: 40),
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        FirebaseFirestore.instance
                            .collection('tweets')
                            .doc(tweetId)
                            .collection('comments')
                            .add({
                          'text': controller.text,
                          'timestamp': Timestamp.now(),
                          'userId': currentUserId, // Add user ID to comment
                        });
                        controller.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              height: 0,
              color: Colors.transparent,
            ),
          ),
        ],
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
  ) {
    final displayName = userData?['displayname'] ?? 'Unknown';
    final photoUrl = userData?['photoURL'] ?? 'https://picsum.photos/200';
    final commentText = commentData['text'] as String;

    // Determine card color based on theme and if it's user's comment
    final cardColor = darkTheme
        ? (isCurrentUserComment
            ? const Color(0xFF1E3A5F)
            : const Color(0xFF212121))
        : (isCurrentUserComment ? const Color(0xFFE3F2FD) : Colors.white);

    // Accent color for current user's comment
    final accentLineColor =
        isCurrentUserComment ? const Color(0xFF4FC3F7) : Colors.transparent;

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
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
                                  color:
                                      darkTheme ? Colors.white : Colors.black87,
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

                        // Delete button for user's comments
                        if (isCurrentUserComment && commentId != null)
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () {
                                FirebaseFirestore.instance
                                    .collection('tweets')
                                    .doc(tweetId)
                                    .collection('comments')
                                    .doc(commentId)
                                    .delete();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color:
                                      darkTheme ? Colors.red[300] : Colors.red,
                                ),
                              ),
                            ),
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
                          color:
                              darkTheme ? Colors.grey[300] : Colors.grey[850],
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
    );
  }
}
