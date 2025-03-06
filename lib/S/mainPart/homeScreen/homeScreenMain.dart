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
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(seconds: 2),
                  child: Text(
                    langMain == "tr"
                        ? 'Kimseyi takip etmiyorsunuz.'
                        : 'You are not following anyone.',
                    style: TextStyle(
                      fontSize: 18,
                      color: darkThemeMain ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.refresh(sortedTweetsProvider);
              },
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _buildPostCard(post);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
        onPressed: () => _controller.showNewPostDialog(
            darkThemeMain, langMain, context, ref),
        child: const Icon(Icons.add, color: Colors.white),
        mini: true,
      ),
    );
  }

  // New method to build post card widget
  Widget _buildPostCard(dynamic post) {
    final postData = post.data() as Map<String, dynamic>?;
    if (postData == null) return SizedBox.shrink();
    final darkThemeMain = ref.watch(darkTheme);
    final isLiked = ref.watch(likeProvider(post.id));
    final likeCount = ref.watch(likeProvider(post.id).notifier).likeCount;
    // Get current user for checking profile id
    final currentUser = FirebaseAuth.instance.currentUser;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      child: Column(
        children: [
          // Post header
          ListTile(
            leading: GestureDetector(
              onTap: () {
                if (currentUser != null &&
                    currentUser.uid == postData['userId']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'You cannot view your own profile'), // alert text
                    ),
                  );
                } else {
                  _controller.navigateToProfile(context, postData['userId']);
                }
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(
                  postData['userPhotoURL'] ?? 'https://picsum.photos/200',
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                if (currentUser != null &&
                    currentUser.uid == postData['userId']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'You cannot view your own profile'), // alert text
                    ),
                  );
                } else {
                  _controller.navigateToProfile(context, postData['userId']);
                }
              },
              child: Text(
                postData['message'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            subtitle: Text(
              'Updated by: ${postData['userName'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              _controller.formatTimestamp(postData['timestamp']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // New: Display photo if available
          if (postData['photoURL'] != null &&
              (postData['photoURL'] as String).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.network(
                postData['photoURL'],
                fit: BoxFit.cover,
              ),
            ),
          // Post actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.thumb_up),
                      color: isLiked ? Colors.blue : Colors.grey,
                      onPressed: () =>
                          ref.read(likeProvider(post.id).notifier).toggleLike(),
                    ),
                    Text('$likeCount likes'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.comment),
                  color: Colors.grey,
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
}
