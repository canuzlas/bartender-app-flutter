import 'package:bartender/S/mainPart/profileScreen/emojiesButtons.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenController.dart';
import 'package:bartender/S/mainPart/profileScreen/profileScreenController.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart';

class Profilescreenmain extends ConsumerStatefulWidget {
  const Profilescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ProfilescreenmainState();
}

class _ProfilescreenmainState extends ConsumerState<Profilescreenmain> {
  final ProfileScreenController _controller = ProfileScreenController();
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _controller.loadSharedPreferences(ref);
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final selectedEmoji = ref.watch(selectedEmojiProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
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
                        GestureDetector(
                          onTap: () => _controller.showEmojiPicker(
                              context, langMain, ref),
                          child: Text(
                            "$selectedEmoji ${userData['displayname']}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  darkThemeMain ? Colors.white : Colors.black,
                            ),
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
                        PopupMenuButton<int>(
                          onSelected: (item) async {
                            if (item == 0) {
                              await _controller.showSettingsDialog(
                                  context, ref);
                            } else if (item == 1) {
                              await _controller.confirmLogout(
                                  context, langMain);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<int>(
                              value: 0,
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.settings,
                                      color: darkThemeMain
                                          ? Colors.white
                                          : Colors.black),
                                  SizedBox(width: 8),
                                  Text(langMain == 'tr'
                                      ? 'Ayarlar'
                                      : 'Settings'),
                                ],
                              ),
                            ),
                            PopupMenuItem<int>(
                              value: 1,
                              child: Row(
                                children: [
                                  Icon(Icons.logout,
                                      color: darkThemeMain
                                          ? Colors.white
                                          : Colors.black),
                                  SizedBox(width: 8),
                                  Text(langMain == 'tr' ? 'Çıkış' : 'Logout'),
                                ],
                              ),
                            ),
                          ],
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
                            GestureDetector(
                              onTap: () {
                                _controller.showUserListDialog(
                                  context,
                                  langMain == "tr" ? "Takipçiler" : "Followers",
                                  List<String>.from(
                                      userData['followers'] ?? []),
                                  langMain,
                                  ref,
                                );
                              },
                              child: Text(
                                langMain == "tr" ? "takipçi" : "follower",
                                style: TextStyle(
                                  color: darkThemeMain
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
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
                            GestureDetector(
                              onTap: () {
                                _controller.showUserListDialog(
                                    context,
                                    langMain == "tr"
                                        ? "Takip Edilenler"
                                        : "Following",
                                    List<String>.from(
                                        userData['following'] ?? []),
                                    langMain,
                                    ref);
                              },
                              child: Text(
                                langMain == "tr" ? "takip" : "follow",
                                style: TextStyle(
                                  color: darkThemeMain
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
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
                                  onRefresh: () async {
                                    setState(() {});
                                  },
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
                                          final postData = post.data()
                                              as Map<String, dynamic>;
                                          final isLiked = postData['likedBy']
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
                                                            NetworkImage(postData[
                                                                    'userPhotoURL'] ??
                                                                'https://picsum.photos/200'),
                                                      ),
                                                      title: Text(
                                                        postData['userName'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        postData['message'] ??
                                                            '',
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
                                                            _controller
                                                                .toggleLike(
                                                              post.id,
                                                              isLiked,
                                                            );
                                                          },
                                                        ),
                                                        Text(
                                                          "${(postData['likedBy'] as List<dynamic>?)?.length ?? 0}",
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
                                  onRefresh: () async {
                                    setState(() {});
                                  },
                                  child: FutureBuilder<QuerySnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('tweets')
                                        .where('likedBy',
                                            arrayContains:
                                                auth.currentUser?.uid)
                                        .orderBy('timestamp', descending: true)
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
                                          final postData = post.data()
                                              as Map<String, dynamic>;
                                          final isLiked = postData['likedBy']
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
                                                            NetworkImage(postData[
                                                                    'userPhotoURL'] ??
                                                                'https://picsum.photos/200'),
                                                      ),
                                                      title: Text(
                                                        postData['userName'] ??
                                                            'Unknown',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      subtitle: Text(
                                                        postData['message'] ??
                                                            '',
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
                                                            _controller
                                                                .toggleLike(
                                                              post.id,
                                                              isLiked,
                                                            );
                                                          },
                                                        ),
                                                        Text(
                                                          "${(postData['likedBy'] as List<dynamic>?)?.length ?? 0}",
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
