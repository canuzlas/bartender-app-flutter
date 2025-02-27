import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bartender/S/mainPart/msgScreen/messagingPage.dart';
import 'package:intl/intl.dart';

class OtherUserProfileScreen extends ConsumerWidget {
  final String userId;

  const OtherUserProfileScreen({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider(userId));
    final tweetCountAsyncValue = ref.watch(tweetCountProvider(userId));

    return Scaffold(
      body: userAsyncValue.when(
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text('User not found'));
          }
          final isFollowing = ref.watch(followingProvider(userId));
          final joinDate = userData['createdAt'] != null
              ? (userData['createdAt'] as Timestamp).toDate()
              : null;

          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          userData['coverPhotoURL'] ??
                              'https://picsum.photos/id/237/200/300',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                            color: Colors.grey,
                            child: Center(child: Icon(Icons.error)),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.5),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(
                                userData['photoURL'] ??
                                    'https://picsum.photos/200',
                              ),
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    if (isFollowing) {
                                      ref
                                          .read(followingProvider(userId)
                                              .notifier)
                                          .unfollow();
                                    } else {
                                      ref
                                          .read(followingProvider(userId)
                                              .notifier)
                                          .follow();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing
                                        ? Colors.redAccent
                                        : Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                      Text(isFollowing ? 'Unfollow' : 'Follow'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MessagingPage(recipientId: userId),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Message'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userData['displayname'] ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData['bio'] ?? 'No bio available',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        if (joinDate != null)
                          Text(
                            'Joined: ${DateFormat('MMMM d, y').format(joinDate)}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoColumn(
                                context,
                                'Followers',
                                userData['followers']?.length.toString() ??
                                    '0'),
                            _buildInfoColumn(
                                context,
                                'Following',
                                userData['following']?.length.toString() ??
                                    '0'),
                            tweetCountAsyncValue.when(
                              data: (tweetCount) => _buildInfoColumn(
                                  context, 'Tweets', '$tweetCount'),
                              loading: () =>
                                  _buildInfoColumn(context, 'Tweets', '-'),
                              error: (error, stackTrace) =>
                                  _buildInfoColumn(context, 'Tweets', 'Err'),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'User Tweets',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, watch, child) {
                    final userTweetsAsyncValue =
                        ref.watch(userTweetsProvider(userId));
                    return userTweetsAsyncValue.when(
                      data: (tweets) {
                        if (tweets.isEmpty) {
                          return const SliverToBoxAdapter(
                              child: Center(child: Text('No tweets found')));
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final tweet = tweets[index];
                              final tweetData =
                                  tweet.data() as Map<String, dynamic>;
                              final likeCount = tweetData['likes'] ?? 0;
                              final commentCount = tweetData['comments'] ?? 0;
                              final postPhotoURL = tweetData['photoURL'];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12.0, vertical: 6.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (postPhotoURL != null &&
                                        postPhotoURL.toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: Image.network(
                                          postPhotoURL,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const SizedBox(
                                                  height: 200,
                                                  child: Center(
                                                      child: Icon(
                                                          Icons.broken_image))),
                                        ),
                                      ),
                                    ListTile(
                                      title: Text(tweetData['message'] ?? ''),
                                      subtitle: Text(
                                          'Posted on: ${tweetData['timestamp'].toDate()}'),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 8.0),
                                      child: Row(
                                        children: [
                                          // Retrieve current user and determine like state
                                          Builder(
                                            builder: (context) {
                                              final currentUser = FirebaseAuth
                                                  .instance.currentUser;
                                              final likedBy =
                                                  (tweetData['likedBy']
                                                          as List<dynamic>?) ??
                                                      [];
                                              final isLiked =
                                                  currentUser != null &&
                                                      likedBy.contains(
                                                          currentUser.uid);
                                              return Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      isLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      color: isLiked
                                                          ? Colors.red
                                                          : null,
                                                    ),
                                                    onPressed: () async {
                                                      if (currentUser == null)
                                                        return;
                                                      if (!isLiked) {
                                                        await tweet.reference
                                                            .update({
                                                          'likes': FieldValue
                                                              .increment(1),
                                                          'likedBy': FieldValue
                                                              .arrayUnion([
                                                            currentUser.uid
                                                          ])
                                                        });
                                                      } else {
                                                        await tweet.reference
                                                            .update({
                                                          'likes': FieldValue
                                                              .increment(-1),
                                                          'likedBy': FieldValue
                                                              .arrayRemove([
                                                            currentUser.uid
                                                          ])
                                                        });
                                                      }
                                                    },
                                                  ),
                                                  Text('$likeCount'),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.comment_bank_outlined),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      CommentsPage(
                                                          tweetId: tweet.id),
                                                ),
                                              );
                                            },
                                          ),
                                          Text('$commentCount'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: tweets.length,
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                          child: Center(child: CircularProgressIndicator())),
                      error: (error, stack) => SliverToBoxAdapter(
                          child: Center(child: Text('Error: $error'))),
                    );
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}

final userProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  return userDoc.data();
});

final userTweetsProvider = StreamProvider.family<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('tweets')
      .where('userId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});

final followingProvider =
    StateNotifierProvider.family<FollowingNotifier, bool, String>(
  (ref, userId) => FollowingNotifier(userId),
);

class FollowingNotifier extends StateNotifier<bool> {
  final String userId;

  FollowingNotifier(this.userId) : super(false) {
    _loadInitialFollowingState();
  }

  Future<void> _loadInitialFollowingState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final following = userDoc.data()?['following'] as List<dynamic>? ?? [];
    state = following.contains(userId);
  }

  Future<void> follow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'following': FieldValue.arrayUnion([userId]),
    });
    state = true;
  }

  Future<void> unfollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'following': FieldValue.arrayRemove([userId]),
    });
    state = false;
  }
}

final tweetCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('tweets')
      .where('userId', isEqualTo: userId)
      .get();
  return snapshot.size;
});
