import 'package:bartender/S/mainPart/discoverScreen/searchDelegate.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenState.dart';
import 'package:bartender/mainSettings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenController.dart';

class HomeScreenMain extends ConsumerStatefulWidget {
  const HomeScreenMain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenMainState();
}

class _HomeScreenMainState extends ConsumerState<HomeScreenMain> {
  final HomeScreenController _controller = HomeScreenController();

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final sortedTweetsAsyncValue = ref.watch(sortedTweetsProvider);

    return Scaffold(
      body: SafeArea(
        child: sortedTweetsAsyncValue.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Center(
                child: Container(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 70,
                        color: darkThemeMain ? Colors.white38 : Colors.black26,
                      ),
                      SizedBox(height: 20),
                      Text(
                        langMain == "tr"
                            ? 'Kimseyi takip etmiyorsunuz.'
                            : 'You are not following anyone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color:
                              darkThemeMain ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: UserSearchDelegate(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkThemeMain
                              ? Colors.orangeAccent
                              : Colors.deepOrange,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          langMain == "tr"
                              ? 'Kişileri Keşfet'
                              : 'Discover People',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              color: darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              backgroundColor: darkThemeMain ? Color(0xFF2D2D2D) : Colors.white,
              onRefresh: () async {
                ref.refresh(sortedTweetsProvider);
              },
              child: ListView.builder(
                padding: EdgeInsets.only(top: 8, bottom: 20),
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _buildPostCard(post);
                },
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              ),
            ),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 60,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Failed to load posts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkThemeMain ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkThemeMain ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => ref.refresh(sortedTweetsProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkThemeMain
                          ? Colors.orangeAccent
                          : Colors.deepOrange,
                    ),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onPressed: () => _controller.showNewPostDialog(
            darkThemeMain, langMain, context, ref),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // Improved post card with better styling
  Widget _buildPostCard(dynamic post) {
    final postData = post.data() as Map<String, dynamic>?;
    if (postData == null) return SizedBox.shrink();

    final darkThemeMain = ref.watch(darkTheme);
    final isLiked = ref.watch(likeProvider(post.id));
    final likeCount = ref.watch(likeProvider(post.id).notifier).likeCount;
    final currentUser = FirebaseAuth.instance.currentUser;
    final timestamp = _controller.formatTimestamp(postData['timestamp']);
    final hasImage = postData['photoURL'] != null &&
        (postData['photoURL'] as String).trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
        side: BorderSide(
          color: darkThemeMain ? Colors.grey[800]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      color: darkThemeMain ? Color(0xFF252525) : Colors.white,
      elevation: 2,
      shadowColor: darkThemeMain ? Colors.black : Colors.black38,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile picture and name
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (currentUser != null &&
                        currentUser.uid == postData['userId']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('You cannot view your own profile'),
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } else {
                      _controller.navigateToProfile(
                          context, postData['userId']);
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: darkThemeMain
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                      image: DecorationImage(
                        image: NetworkImage(
                          postData['userPhotoURL'] ??
                              'https://picsum.photos/200',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (currentUser != null &&
                                    currentUser.uid == postData['userId']) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'You cannot view your own profile'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  _controller.navigateToProfile(
                                      context, postData['userId']);
                                }
                              },
                              child: Text(
                                postData['userName'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: darkThemeMain
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 13,
                              color: darkThemeMain
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        postData['message'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          color: darkThemeMain ? Colors.white : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Post image
          if (hasImage)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: darkThemeMain
                        ? Colors.black12
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  postData['photoURL'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 220,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      color:
                          darkThemeMain ? Colors.grey[800] : Colors.grey[200],
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color:
                          darkThemeMain ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.grey[500],
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Actions row (like, comment)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Like button
                _buildActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '$likeCount',
                  isActive: isLiked,
                  darkTheme: darkThemeMain,
                  onPressed: () =>
                      ref.read(likeProvider(post.id).notifier).toggleLike(),
                ),
                SizedBox(width: 16),
                // Comment button
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  label: 'Comment',
                  isActive: false,
                  darkTheme: darkThemeMain,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsPage(tweetId: post.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for action buttons
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool darkTheme,
    required VoidCallback onPressed,
  }) {
    final Color activeColor = Colors.redAccent;
    final Color inactiveColor =
        darkTheme ? Colors.grey[400]! : Colors.grey[600]!;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? activeColor : inactiveColor,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
