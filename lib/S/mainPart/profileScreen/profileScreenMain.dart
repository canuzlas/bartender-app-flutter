import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenCommentsPage.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenController.dart';

class Profilescreenmain extends ConsumerStatefulWidget {
  const Profilescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ProfilescreenmainState();
}

class _ProfilescreenmainState extends ConsumerState<Profilescreenmain> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final HomeScreenController _controller = HomeScreenController();

  Future<void> _toggleLike(String postId, bool isLiked) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final postDoc = FirebaseFirestore.instance.collection('tweets').doc(postId);

    if (isLiked) {
      await postDoc.update({
        'likedBy': FieldValue.arrayRemove([currentUser.uid]),
      });
    } else {
      await postDoc.update({
        'likedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  Future<void> _refreshPage() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshPage,
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(auth.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final userDoc = snapshot.data;
              final userData = userDoc?.data() as Map<String, dynamic>?;

              if (userData == null) {
                return Center(child: Text('User data not found.'));
              }

              return Column(
                children: [
                  // Profile top bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          "🍸 ${userData['displayname']}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkThemeMain ? Colors.white : Colors.black,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          iconSize: 20,
                          color: darkThemeMain ? Colors.white : Colors.black,
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () {
                            // Add action
                          },
                        ),
                        IconButton(
                          iconSize: 20,
                          color: darkThemeMain ? Colors.white : Colors.black,
                          icon: const Icon(CupertinoIcons.settings),
                          onPressed: () {
                            // Settings action
                          },
                        ),
                      ],
                    ),
                  ),
                  // Profile photo, posts, followers, following
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(userData['photoURL'] ??
                              'https://picsum.photos/200'),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tweets')
                              .where('userId', isEqualTo: auth.currentUser?.uid)
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Column(
                                children: [
                                  Text(
                                    "0",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: darkThemeMain
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    langMain == "tr" ? "gönderi" : "post",
                                    style: TextStyle(
                                      color: darkThemeMain
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              );
                            }
                            final posts = snapshot.data?.docs ?? [];
                            return Column(
                              children: [
                                Text(
                                  "${posts.length}",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: darkThemeMain
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                Text(
                                  langMain == "tr" ? "gönderi" : "post",
                                  style: TextStyle(
                                    color: darkThemeMain
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        Column(
                          children: [
                            Text(
                              "${userData['followers']?.length ?? 0}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    darkThemeMain ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              langMain == "tr" ? "takipçi" : "follower",
                              style: TextStyle(
                                color: darkThemeMain
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              "${userData['following']?.length ?? 0}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    darkThemeMain ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              langMain == "tr" ? "takip" : "follow",
                              style: TextStyle(
                                color: darkThemeMain
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Name, bio, and edit profile button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['displayname'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkThemeMain ? Colors.white : Colors.black,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          userData['bio'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                darkThemeMain ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              // Edit profile action
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkThemeMain
                                  ? Colors.orangeAccent
                                  : Colors.deepOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              langMain == "tr"
                                  ? "Profili Düzenle"
                                  : "Edit Profile",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs for posts and likes
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            tabs: [
                              Tab(
                                text:
                                    langMain == "tr" ? "Paylaşımlar" : "Posts",
                              ),
                              Tab(
                                text:
                                    langMain == "tr" ? "Beğenilenler" : "Likes",
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                RefreshIndicator(
                                  onRefresh: _refreshPage,
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('tweets')
                                        .where('userId',
                                            isEqualTo: auth.currentUser?.uid)
                                        .orderBy('timestamp', descending: true)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Center(
                                            child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError) {
                                        return Center(
                                            child: Text(
                                                'Error: ${snapshot.error}'));
                                      }
                                      final posts = snapshot.data?.docs ?? [];
                                      return ListView.builder(
                                        itemCount: posts.length,
                                        itemBuilder: (context, index) {
                                          final post = posts[index];
                                          final isLiked = (post['likedBy']
                                                      as List<dynamic>?)
                                                  ?.contains(
                                                      auth.currentUser?.uid) ??
                                              false;
                                          return FutureBuilder<QuerySnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('tweets')
                                                .doc(post.id)
                                                .collection('comments')
                                                .get(),
                                            builder: (context, snapshot) {
                                              final commentCount =
                                                  snapshot.data?.docs.length ??
                                                      0;
                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          15.0),
                                                ),
                                                elevation: 5,
                                                child: Column(
                                                  children: [
                                                    ListTile(
                                                      leading: CircleAvatar(
                                                        backgroundImage:
                                                            NetworkImage(post[
                                                                    'userPhotoURL'] ??
                                                                'https://picsum.photos/200'),
                                                      ),
                                                      title: Text(
                                                        post['userName'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        post['message'] ?? '',
                                                      ),
                                                    ),
                                                    OverflowBar(
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            isLiked
                                                                ? Icons.favorite
                                                                : Icons
                                                                    .favorite_border_outlined,
                                                            color: isLiked
                                                                ? Colors.red
                                                                : null,
                                                          ),
                                                          onPressed: () {
                                                            _toggleLike(post.id,
                                                                isLiked);
                                                          },
                                                        ),
                                                        Text(
                                                          "${(post['likedBy'] as List<dynamic>?)?.length ?? 0}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: darkThemeMain
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                        ),
                                                        TextButton.icon(
                                                          icon: Icon(
                                                            CupertinoIcons
                                                                .chat_bubble,
                                                            size: 20,
                                                            color: darkThemeMain
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                          label: Text(
                                                            "$commentCount",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: darkThemeMain
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        CommentsPage(
                                                                  tweetId:
                                                                      post.id,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                RefreshIndicator(
                                  onRefresh: _refreshPage,
                                  child: FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('tweets')
                                        .where('likedBy',
                                            arrayContains:
                                                auth.currentUser?.uid)
                                        .get(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Center(
                                            child: CircularProgressIndicator());
                                      }
                                      if (snapshot.hasError) {
                                        return Center(
                                            child: Text(
                                                'Error: ${snapshot.error}'));
                                      }
                                      final likedPosts =
                                          snapshot.data?.docs ?? [];
                                      return ListView.builder(
                                        itemCount: likedPosts.length,
                                        itemBuilder: (context, index) {
                                          final post = likedPosts[index];
                                          final isLiked = (post['likedBy']
                                                      as List<dynamic>?)
                                                  ?.contains(
                                                      auth.currentUser?.uid) ??
                                              false;
                                          return FutureBuilder<QuerySnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('tweets')
                                                .doc(post.id)
                                                .collection('comments')
                                                .get(),
                                            builder: (context, snapshot) {
                                              final commentCount =
                                                  snapshot.data?.docs.length ??
                                                      0;
                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          15.0),
                                                ),
                                                elevation: 5,
                                                child: Column(
                                                  children: [
                                                    ListTile(
                                                      leading: CircleAvatar(
                                                        backgroundImage:
                                                            NetworkImage(post[
                                                                    'userPhotoURL'] ??
                                                                'https://picsum.photos/200'),
                                                      ),
                                                      title: Text(
                                                        post['userName'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        post['message'] ?? '',
                                                      ),
                                                    ),
                                                    OverflowBar(
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            isLiked
                                                                ? Icons.favorite
                                                                : Icons
                                                                    .favorite_border_outlined,
                                                            color: isLiked
                                                                ? Colors.red
                                                                : null,
                                                          ),
                                                          onPressed: () {
                                                            _toggleLike(post.id,
                                                                isLiked);
                                                          },
                                                        ),
                                                        Text(
                                                          "${(post['likedBy'] as List<dynamic>?)?.length ?? 0}",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: darkThemeMain
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                        ),
                                                        TextButton.icon(
                                                          icon: Icon(
                                                            CupertinoIcons
                                                                .chat_bubble,
                                                            size: 20,
                                                            color: darkThemeMain
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black87,
                                                          ),
                                                          label: Text(
                                                            "$commentCount",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: darkThemeMain
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        CommentsPage(
                                                                  tweetId:
                                                                      post.id,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
