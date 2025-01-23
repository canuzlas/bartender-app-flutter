import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bartender/S/mainPart/msgScreen/messagingPage.dart';

class OtherUserProfileScreen extends ConsumerWidget {
  final String userId;

  const OtherUserProfileScreen({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider(userId));
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
      ),
      body: userAsyncValue.when(
        data: (userData) {
          if (userData == null) {
            return Center(child: Text('User not found'));
          }
          final isFollowing = ref.watch(followingProvider(userId));

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                          userData['photoURL'] ?? 'https://picsum.photos/200'),
                    ),
                    SizedBox(height: 16),
                    Text(
                      userData['displayname'] ?? 'Unknown',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      userData['bio'] ?? '',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (isFollowing) {
                              ref
                                  .read(followingProvider(userId).notifier)
                                  .unfollow();
                            } else {
                              ref
                                  .read(followingProvider(userId).notifier)
                                  .follow();
                            }
                          },
                          child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                        ),
                        SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    MessagingPage(recipientId: userId),
                              ),
                            );
                          },
                          child: Text('Message'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'User Tweets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Display user's tweets
              Consumer(
                builder: (context, watch, child) {
                  final userTweetsAsyncValue =
                      ref.watch(userTweetsProvider(userId));
                  return userTweetsAsyncValue.when(
                    data: (tweets) {
                      if (tweets.isEmpty) {
                        return Center(child: Text('No tweets found'));
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: tweets.length,
                        itemBuilder: (context, index) {
                          final tweet = tweets[index];
                          final tweetData =
                              tweet.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(tweetData['message'] ?? ''),
                            subtitle: Text(
                                'Posted on: ${tweetData['timestamp'].toDate()}'),
                          );
                        },
                      );
                    },
                    loading: () => Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error: $error')),
                  );
                },
              ),
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
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
