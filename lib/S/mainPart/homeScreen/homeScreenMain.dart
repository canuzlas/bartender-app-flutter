import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenCommentsPage.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenController.dart';

final sortedTweetsProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncMap((userDoc) async {
    final following = (userDoc.data()?['following'] as List<dynamic>?) ?? [];
    if (following.isEmpty) {
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('tweets')
        .where('userId', whereIn: following)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs;
  });
});

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
                  duration: Duration(seconds: 2),
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
                  final postData = post.data() as Map<String, dynamic>?;
                  if (postData == null) {
                    return SizedBox.shrink();
                  }
                  final isLiked = ref.watch(likeProvider(post.id));
                  final likeCount =
                      ref.watch(likeProvider(post.id).notifier).likeCount;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    elevation: 5,
                    child: Column(
                      children: [
                        ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => OtherUserProfileScreen(
                                      userId: postData['userId']),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  postData['userPhotoURL'] ??
                                      'https://picsum.photos/200'),
                            ),
                          ),
                          title: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => OtherUserProfileScreen(
                                      userId: postData['userId']),
                                ),
                              );
                            },
                            child: Text(
                              postData['message'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          subtitle: Text(
                            'Updated by: ${postData['userName'] ?? 'Unknown'}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          trailing: Text(
                            _controller.formatTimestamp(postData['timestamp']),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
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
                                    onPressed: () {
                                      ref
                                          .read(likeProvider(post.id).notifier)
                                          .toggleLike();
                                    },
                                  ),
                                  Text('$likeCount likes'),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.comment),
                                color: Colors.grey,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CommentsPage(tweetId: post.id),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
          loading: () => Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              final TextEditingController _textController =
                  TextEditingController();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                title: Text(
                  langMain == "tr" ? 'Yeni Gönderi' : 'New Post',
                  style: TextStyle(
                    color: darkThemeMain ? Colors.white : Colors.black,
                  ),
                ),
                content: TextField(
                  controller: _textController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: langMain == "tr"
                        ? 'Neler oluyor?'
                        : 'What\'s happening?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      langMain == "tr" ? 'İptal' : 'Cancel',
                      style: TextStyle(
                          color: darkThemeMain
                              ? Colors.orangeAccent
                              : Colors.deepOrange),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_textController.text.isNotEmpty) {
                        final userId = FirebaseAuth.instance.currentUser?.uid;
                        final userName =
                            FirebaseAuth.instance.currentUser?.displayName;
                        final userPhotoURL =
                            FirebaseAuth.instance.currentUser?.photoURL;
                        if (userId != null && userName != null) {
                          FirebaseFirestore.instance.collection('tweets').add({
                            'userId': userId,
                            'userName': userName,
                            'userPhotoURL': userPhotoURL,
                            'message': _textController.text,
                            'timestamp': Timestamp.now(),
                            'likedBy': [],
                          });
                          Navigator.of(context).pop();
                          ref.refresh(
                              sortedTweetsProvider); // Refresh the provider
                        }
                      }
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                    label: Text(
                      langMain == "tr" ? 'Gönder' : 'Post',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkThemeMain
                          ? Colors.orangeAccent
                          : Colors.deepOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
        mini: true,
      ),
    );
  }
}
