import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/S/mainPart/profileScreen/profileScreenController.dart';

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
    final refreshing = ref.watch(refreshingProvider);

    final primaryColor =
        darkThemeMain ? Colors.orangeAccent : Colors.deepOrange;
    final textColor = darkThemeMain ? Colors.white : Colors.black;
    final secondaryTextColor = darkThemeMain ? Colors.white70 : Colors.black87;

    return Scaffold(
      backgroundColor:
          darkThemeMain ? const Color(0xFF121212) : Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            ref.read(refreshingProvider.notifier).state = !refreshing;
          },
          child: FutureBuilder<DocumentSnapshot>(
            key: ValueKey(refreshing),
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(auth.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: primaryColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final userDoc = snapshot.data;
              final userData = userDoc?.data() as Map<String, dynamic>?;

              if (userData == null) {
                return const Center(child: Text('User data not found.'));
              }

              return Column(
                children: [
                  // Profile top bar with improved styling
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: darkThemeMain
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _controller.selectEmoji(context, langMain, ref),
                          child: Row(
                            children: [
                              Text(
                                selectedEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userData['displayname'],
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          iconSize: 24,
                          color: textColor,
                          icon: const Icon(Icons.add_box_outlined),
                          onPressed: () {
                            // Add action
                          },
                        ),
                        PopupMenuButton<int>(
                          icon: Icon(Icons.menu, color: textColor),
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
                                      color: textColor),
                                  const SizedBox(width: 8),
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
                                  Icon(Icons.logout, color: textColor),
                                  const SizedBox(width: 8),
                                  Text(langMain == 'tr' ? 'Çıkış' : 'Logout'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Profile photo and stats with better spacing and alignment
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Enhanced profile photo
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(
                                userData['photoURL'] ??
                                    'https://picsum.photos/200'),
                          ),
                        ),
                        // Stats with better styling
                        _buildStatColumn(
                          context,
                          FirebaseFirestore.instance
                              .collection('tweets')
                              .where('userId', isEqualTo: auth.currentUser?.uid)
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          langMain == "tr" ? "gönderi" : "post",
                          darkThemeMain,
                          textColor,
                          secondaryTextColor,
                        ),
                        _buildFollowerColumn(
                          userData['followers']?.length ?? 0,
                          langMain == "tr" ? "takipçi" : "follower",
                          () {
                            _controller.showUserListDialog(
                              context,
                              langMain == "tr" ? "Takipçiler" : "Followers",
                              List<String>.from(userData['followers'] ?? []),
                              langMain,
                              ref,
                            );
                          },
                          darkThemeMain,
                          textColor,
                          secondaryTextColor,
                        ),
                        _buildFollowerColumn(
                          userData['following']?.length ?? 0,
                          langMain == "tr" ? "takip" : "follow",
                          () {
                            _controller.showUserListDialog(
                              context,
                              langMain == "tr"
                                  ? "Takip Edilenler"
                                  : "Following",
                              List<String>.from(userData['following'] ?? []),
                              langMain,
                              ref,
                            );
                          },
                          darkThemeMain,
                          textColor,
                          secondaryTextColor,
                        ),
                      ],
                    ),
                  ),
                  // Bio and edit profile button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData['bio'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              // Fix: Connect the button to the editProfile method in the controller
                              _controller.editProfile(context, ref);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              minimumSize: const Size(200, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              shadowColor: primaryColor.withOpacity(0.5),
                            ),
                            child: Text(
                              langMain == "tr"
                                  ? "Profili Düzenle"
                                  : "Edit Profile",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs with improved styling
                  const SizedBox(height: 16),
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: primaryColor,
                            unselectedLabelColor: secondaryTextColor,
                            indicatorColor: primaryColor,
                            indicatorWeight: 3,
                            labelStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                            tabs: [
                              Tab(
                                  text: langMain == "tr"
                                      ? "Paylaşımlar"
                                      : "Posts"),
                              Tab(
                                  text: langMain == "tr"
                                      ? "Beğenilenler"
                                      : "Likes"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Posts tab
                                _buildPostsTab(
                                  FirebaseFirestore.instance
                                      .collection('tweets')
                                      .where('userId',
                                          isEqualTo: auth.currentUser?.uid)
                                      .orderBy('timestamp', descending: true)
                                      .snapshots(),
                                  darkThemeMain,
                                  primaryColor,
                                  textColor,
                                  secondaryTextColor,
                                ),
                                // Likes tab
                                _buildLikesTab(
                                  darkThemeMain,
                                  primaryColor,
                                  textColor,
                                  secondaryTextColor,
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

  // Helper methods to reduce code repetition
  Widget _buildStatColumn(BuildContext context, Stream<QuerySnapshot> stream,
      String label, bool darkTheme, Color textColor, Color secondaryTextColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return _buildStatItem(
            count, label, () {}, darkTheme, textColor, secondaryTextColor);
      },
    );
  }

  Widget _buildFollowerColumn(int count, String label, VoidCallback onTap,
      bool darkTheme, Color textColor, Color secondaryTextColor) {
    return _buildStatItem(
        count, label, onTap, darkTheme, textColor, secondaryTextColor);
  }

  Widget _buildStatItem(int count, String label, VoidCallback onTap,
      bool darkTheme, Color textColor, Color secondaryTextColor) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            "$count",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(Stream<QuerySnapshot> stream, bool darkTheme,
      Color primaryColor, Color textColor, Color secondaryTextColor) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: primaryColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final posts = snapshot.data?.docs ?? [];
          if (posts.isEmpty) {
            return Center(
                child: Text(
              'No posts yet',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ));
          }
          return _buildPostsList(
              posts, darkTheme, primaryColor, textColor, secondaryTextColor);
        },
      ),
    );
  }

  Widget _buildLikesTab(bool darkTheme, Color primaryColor, Color textColor,
      Color secondaryTextColor) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: primaryColor,
      child: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('tweets')
            .where('likedBy', arrayContains: auth.currentUser?.uid)
            .orderBy('timestamp', descending: true)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final likedPosts = snapshot.data?.docs ?? [];
          if (likedPosts.isEmpty) {
            return Center(
                child: Text(
              'No liked posts',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ));
          }
          return _buildPostsList(likedPosts, darkTheme, primaryColor, textColor,
              secondaryTextColor);
        },
      ),
    );
  }

  Widget _buildPostsList(List<QueryDocumentSnapshot> posts, bool darkTheme,
      Color primaryColor, Color textColor, Color secondaryTextColor) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postData = post.data() as Map<String, dynamic>;
        final isLiked =
            postData['likedBy']?.contains(auth.currentUser?.uid) ?? false;

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('tweets')
              .doc(post.id)
              .collection('comments')
              .get(),
          builder: (context, snapshot) {
            final commentCount = snapshot.data?.docs.length ?? 0;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              elevation: 3,
              color: darkTheme ? const Color(0xFF1E1E1E) : Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(postData['userPhotoURL'] ??
                          'https://picsum.photos/200'),
                    ),
                    title: Text(
                      postData['userName'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        postData['message'] ?? '',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  // Display image if photoURL exists
                  if (postData['photoURL'] != null &&
                      postData['photoURL'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300,
                          ),
                          width: double.infinity,
                          child: Image.network(
                            postData['photoURL'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: primaryColor,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 100,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border_outlined,
                            color: isLiked ? Colors.red : secondaryTextColor,
                          ),
                          onPressed: () {
                            _controller.toggleLike(post.id, isLiked);
                          },
                        ),
                        Text(
                          "${(postData['likedBy'] as List<dynamic>?)?.length ?? 0}",
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            CupertinoIcons.chat_bubble,
                            size: 20,
                            color: secondaryTextColor,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    CommentsPage(tweetId: post.id),
                              ),
                            );
                          },
                        ),
                        Text(
                          "$commentCount",
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
