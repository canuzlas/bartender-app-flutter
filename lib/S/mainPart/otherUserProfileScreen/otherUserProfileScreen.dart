import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/mainSettings.dart';
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
    final darkThemeMain = ref.watch(darkTheme.notifier).state;
    final theme = Theme.of(context);

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

          return SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(25)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Hero(
                                  tag: 'avatar-${userData['uid']}',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardColor,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor: Colors.grey.shade200,
                                      backgroundImage: NetworkImage(
                                        userData['photoURL'] ??
                                            'https://picsum.photos/200',
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => MessagingPage(
                                                recipientId: userId),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 2,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      icon: const Icon(Icons.message, size: 18),
                                      label: const Text('Message'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
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
                                            ? Colors.grey.shade200
                                            : theme.primaryColor,
                                        foregroundColor: isFollowing
                                            ? Colors.black87
                                            : Colors.white,
                                        elevation: 2,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      icon: Icon(
                                        isFollowing
                                            ? Icons.person_remove
                                            : Icons.person_add,
                                        size: 18,
                                      ),
                                      label: Text(
                                          isFollowing ? 'Unfollow' : 'Follow'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData['displayname'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userData['bio'] ?? 'No bio available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (joinDate != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Joined ${DateFormat('MMMM d, y').format(joinDate)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              theme.textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatsColumn(
                                      context,
                                      'Tweets',
                                      tweetCountAsyncValue.when(
                                        data: (count) => '$count',
                                        loading: () => '-',
                                        error: (_, __) => 'Err',
                                      ),
                                      darkThemeMain: darkThemeMain),
                                  _buildVerticalDivider(),
                                  _buildStatsColumn(
                                    context,
                                    'Following',
                                    userData['following']?.length.toString() ??
                                        '0',
                                    darkThemeMain: darkThemeMain,
                                  ),
                                  _buildVerticalDivider(),
                                  _buildStatsColumn(
                                    context,
                                    'Followers',
                                    userData['followers']?.length.toString() ??
                                        '0',
                                    darkThemeMain: darkThemeMain,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.format_quote, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Recent Tweets',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                        ],
                      ),
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
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.speaker_notes_off,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tweets found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
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
                              final timestamp =
                                  tweetData['timestamp'] as Timestamp;
                              final formattedDate = DateFormat('MMM d · h:mm a')
                                  .format(timestamp.toDate());

                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 8.0, left: 16.0, right: 16.0),
                                child: Card(
                                  elevation: 1,
                                  margin: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (postPhotoURL != null &&
                                          postPhotoURL.toString().isNotEmpty)
                                        ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(16)),
                                          child: Image.network(
                                            postPhotoURL,
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                              height: 200,
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                  child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey.shade400,
                                                size: 40,
                                              )),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tweetData['message'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                // Retrieve current user and determine like state
                                                Builder(
                                                  builder: (context) {
                                                    final currentUser =
                                                        FirebaseAuth.instance
                                                            .currentUser;
                                                    final likedBy = (tweetData[
                                                                'likedBy']
                                                            as List<
                                                                dynamic>?) ??
                                                        [];
                                                    final isLiked =
                                                        currentUser != null &&
                                                            likedBy.contains(
                                                                currentUser
                                                                    .uid);
                                                    return _buildTweetActionButton(
                                                      icon: isLiked
                                                          ? Icons.favorite
                                                          : Icons
                                                              .favorite_border,
                                                      label: '$likeCount',
                                                      color: isLiked
                                                          ? Colors.red
                                                          : null,
                                                      onTap: () async {
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
                                                    );
                                                  },
                                                ),
                                                _buildTweetActionButton(
                                                  icon:
                                                      Icons.chat_bubble_outline,
                                                  label: '$commentCount',
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            CommentsPage(
                                                                tweetId:
                                                                    tweet.id),
                                                      ),
                                                    );
                                                  },
                                                ),
                                                _buildTweetActionButton(
                                                  icon: Icons.share_outlined,
                                                  label: 'Share',
                                                  onTap: () {
                                                    // Share functionality
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    'Sharing coming soon')));
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: tweets.length,
                          ),
                        );
                      },
                      loading: () => const SliverToBoxAdapter(
                          child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )),
                      error: (error, stack) => SliverToBoxAdapter(
                          child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.error_outline,
                                  size: 40, color: Colors.red),
                              SizedBox(height: 16),
                              Text('Error loading tweets',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      )),
                    );
                  },
                ),
                // Add some padding at the bottom
                const SliverToBoxAdapter(
                  child: SizedBox(height: 30),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTweetActionButton({
    required IconData icon,
    required String label,
    required Function() onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsColumn(BuildContext context, String label, String value,
      {bool darkThemeMain = true}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: darkThemeMain ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade300,
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
