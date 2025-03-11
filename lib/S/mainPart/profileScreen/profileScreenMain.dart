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

class _ProfilescreenmainState extends ConsumerState<Profilescreenmain>
    with SingleTickerProviderStateMixin {
  final ProfileScreenController _controller = ProfileScreenController();
  final FirebaseAuth auth = FirebaseAuth.instance;
  late TabController _tabController;

  // Store the current tab index to avoid depending on ref during disposal
  int _currentTabIndex = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller.loadSharedPreferences(ref);
    _tabController = TabController(length: 3, vsync: this);

    // Set initial state based on the initial tab controller index
    _currentTabIndex = _tabController.index;

    // Add listener after setting initial state
    _tabController.addListener(_tabControllerListener);

    // Check Firestore data on initialization
    _checkFirestoreData();

    // Add small delay to ensure proper loading
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted && !_isDisposed) {
        ref.read(refreshingProvider.notifier).update((state) => !state);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;

    // First remove listener to prevent callbacks during disposal
    if (_tabController != null) {
      _tabController.removeListener(_tabControllerListener);
      _tabController.dispose();
    }

    super.dispose();
  }

  // Modified listener to safely handle tab changes
  void _tabControllerListener() {
    // Exit if the widget is no longer in the tree
    if (!mounted || _isDisposed) return;

    // Store current tab index locally
    _currentTabIndex = _tabController.index;

    // Only update providers if mounted
    ref.read(showArchivedProvider.notifier).state = _currentTabIndex == 2;
    ref.read(tabIndexProvider.notifier).state = _currentTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    // Use read instead of watch for values that shouldn't trigger rebuilds
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final selectedEmoji = ref.watch(selectedEmojiProvider);
    final refreshing = ref.watch(refreshingProvider);
    final showArchived = ref.watch(showArchivedProvider);
    final tabIndex = ref.watch(tabIndexProvider);

    final primaryColor =
        darkThemeMain ? Colors.orangeAccent : Colors.deepOrange;
    final textColor = darkThemeMain ? Colors.white : Colors.black;
    final secondaryTextColor = darkThemeMain ? Colors.white70 : Colors.black87;
    final backgroundColor =
        darkThemeMain ? const Color(0xFF121212) : Colors.grey[50];

    // Safely sync tab controller with Riverpod state
    if (!_isDisposed && _tabController.index != tabIndex) {
      _tabController.animateTo(tabIndex);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      // Remove the floating action button and use settings menu instead
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

              final lastActive = userData['lastActive'] != null
                  ? (userData['lastActive'] as Timestamp).toDate()
                  : DateTime.now();
              final isOnline =
                  DateTime.now().difference(lastActive).inMinutes < 5;

              return CustomScrollView(
                slivers: [
                  // Profile header with background image
                  SliverAppBar(
                    floating: false,
                    pinned: true,
                    backgroundColor: backgroundColor,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.ios_share),
                        color: textColor,
                        onPressed: () => _shareProfile(userData),
                      ),
                      PopupMenuButton<int>(
                        icon: Icon(Icons.menu, color: textColor),
                        onSelected: (item) async {
                          if (item == 0) {
                            await _controller.showSettingsDialog(context, ref);
                          } else if (item == 1) {
                            _controller.getScheduledPosts(context, ref);
                          } else if (item == 2) {
                            _controller.manageSocialLinks(context, ref);
                          } else if (item == 3) {
                            _controller.updateStoryPrivacy(context, ref);
                          } else if (item == 4) {
                            _controller.viewPostStatistics(context, ref);
                          } else if (item == 5) {
                            await _controller.confirmLogout(context, langMain);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<int>(
                            value: 0,
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.settings, color: textColor),
                                const SizedBox(width: 8),
                                Text(langMain == 'tr' ? 'Ayarlar' : 'Settings'),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 1,
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: textColor),
                                const SizedBox(width: 8),
                                Text(langMain == 'tr'
                                    ? 'Planlı Gönderiler'
                                    : 'Scheduled Posts'),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 2,
                            child: Row(
                              children: [
                                Icon(Icons.link, color: textColor),
                                const SizedBox(width: 8),
                                Text(langMain == 'tr'
                                    ? 'Sosyal Medya'
                                    : 'Social Links'),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 3,
                            child: Row(
                              children: [
                                Icon(Icons.privacy_tip, color: textColor),
                                const SizedBox(width: 8),
                                Text(langMain == 'tr' ? 'Gizlilik' : 'Privacy'),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 4,
                            child: Row(
                              children: [
                                Icon(Icons.bar_chart, color: textColor),
                                const SizedBox(width: 8),
                                Text(langMain == 'tr'
                                    ? 'İstatistikler'
                                    : 'Statistics'),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 5,
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

                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Stories/Highlights section
                        _buildHighlightsSection(
                            userData, darkThemeMain, primaryColor, textColor),

                        // Profile section with online indicator
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Stack(
                                children: [
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
                                  // Online status indicator
                                  if (isOnline)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: darkThemeMain
                                                ? Colors.black
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              _buildStatColumn(
                                context,
                                FirebaseFirestore.instance
                                    .collection('tweets')
                                    .where('userId',
                                        isEqualTo: auth.currentUser?.uid)
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
                                    langMain == "tr"
                                        ? "Takipçiler"
                                        : "Followers",
                                    List<String>.from(
                                        userData['followers'] ?? []),
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
                                    List<String>.from(
                                        userData['following'] ?? []),
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

                        // Bio section with last seen info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _controller.selectEmoji(
                                        context, langMain, ref),
                                    child: Text(
                                      selectedEmoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
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
                                  if (!isOnline)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Text(
                                        _getLastSeenText(lastActive, langMain),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryTextColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                userData['bio'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Action Buttons Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _controller.editProfile(context, ref),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 3,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: ElevatedButton(
                                      onPressed: () => _editHeaderImage(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
                                      ),
                                      child: const Icon(Icons.image),
                                    ),
                                  ),
                                ],
                              ),
                              if (userData['socialLinks'] != null)
                                _buildSocialLinks(userData['socialLinks'],
                                    textColor, primaryColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced tab system with Archive tab
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: Column(
                            children: [
                              TabBar(
                                controller: _tabController,
                                labelColor: primaryColor,
                                unselectedLabelColor: secondaryTextColor,
                                indicatorColor: primaryColor,
                                indicatorWeight: 3,
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                tabs: [
                                  Tab(
                                      text: langMain == "tr"
                                          ? "Paylaşımlar"
                                          : "Posts"),
                                  Tab(
                                      text: langMain == "tr"
                                          ? "Beğenilenler"
                                          : "Likes"),
                                  Tab(
                                      text: langMain == "tr"
                                          ? "Arşiv"
                                          : "Archive"),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // Modified tab content to use adjusted queries
                                    _buildPostsTab(
                                      FirebaseFirestore.instance
                                          .collection('tweets')
                                          .where('userId',
                                              isEqualTo: auth.currentUser?.uid)
                                          .where('archived', isEqualTo: false)
                                          .snapshots(),
                                      darkThemeMain,
                                      primaryColor,
                                      textColor,
                                      secondaryTextColor,
                                    ),
                                    _buildLikesTab(
                                      darkThemeMain,
                                      primaryColor,
                                      textColor,
                                      secondaryTextColor,
                                    ),
                                    _buildArchivedTab(
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
                      ],
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

  // New method for building highlights/stories section
  Widget _buildHighlightsSection(Map<String, dynamic> userData, bool darkTheme,
      Color primaryColor, Color textColor) {
    final List<dynamic> highlights = userData['highlights'] ?? [];

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: highlights.length + 1, // +1 for the 'Add' button
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _addHighlight(),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              darkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.add, color: primaryColor, size: 30),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('New', style: TextStyle(fontSize: 12, color: textColor)),
                ],
              ),
            );
          }

          final highlight = highlights[index - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _viewHighlight(highlight),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 2),
                      image: DecorationImage(
                        image: NetworkImage(
                            highlight['cover'] ?? 'https://picsum.photos/100'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  highlight['title'] ?? 'Story',
                  style: TextStyle(fontSize: 12, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // New helper methods
  String _getLastSeenText(DateTime lastSeen, String language) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 60) {
      return language == 'tr'
          ? '${difference.inMinutes} dk önce'
          : '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return language == 'tr'
          ? '${difference.inHours} saat önce'
          : '${difference.inHours}h ago';
    } else {
      return language == 'tr'
          ? '${difference.inDays} gün önce'
          : '${difference.inDays}d ago';
    }
  }

  void _shareProfile(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          ref.watch(darkTheme) ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ref.watch(lang) == 'tr' ? 'Profili Paylaş' : 'Share Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ref.watch(darkTheme) ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(Icons.content_copy,
                    ref.watch(lang) == 'tr' ? 'Kopyala' : 'Copy Link'),
                _buildShareOption(Icons.message, 'WhatsApp'),
                _buildShareOption(Icons.facebook, 'Facebook'),
                _buildShareOption(Icons.email, 'Email'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Shared via $label')));
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor:
                ref.watch(darkTheme) ? Colors.grey[800] : Colors.grey[200],
            radius: 25,
            child: Icon(icon,
                color: ref.watch(darkTheme)
                    ? Colors.orangeAccent
                    : Colors.deepOrange),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color:
                      ref.watch(darkTheme) ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  void _addHighlight() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.watch(lang) == 'tr'
            ? 'Yeni hikaye ekleniyor...'
            : 'Adding new story...')));
  }

  void _viewHighlight(dynamic highlight) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: NetworkImage(highlight['media'] ??
                    highlight['cover'] ??
                    'https://picsum.photos/400/800'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        highlight['title'] ?? 'Story',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                    ),
                  ),
                  child: Text(highlight['description'] ?? '',
                      style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editHeaderImage() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.watch(lang) == 'tr'
            ? 'Kapak fotoğrafı değiştiriliyor...'
            : 'Changing header image...')));
  }

  // New method for archive tab
  Widget _buildArchivedTab(bool darkTheme, Color primaryColor, Color textColor,
      Color secondaryTextColor) {
    return RefreshIndicator(
      onRefresh: () async {
        // Replace setState with Riverpod refresh
        ref.read(refreshingProvider.notifier).update((state) => !state);
      },
      color: primaryColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tweets')
            .where('userId', isEqualTo: auth.currentUser?.uid)
            .where('archived', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            print("Error in archived tab: ${snapshot.error}"); // Debug info
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final posts = snapshot.data?.docs ?? [];
          print("Archived posts count: ${posts.length}"); // Debug info

          if (posts.isEmpty) {
            return Center(
                child: Text(
              ref.watch(lang) == 'tr'
                  ? 'Arşivlenmiş gönderi yok'
                  : 'No archived posts',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ));
          }

          return _buildPostsList(posts, darkTheme, primaryColor, textColor,
              secondaryTextColor, true);
        },
      ),
    );
  }

  Widget _buildPostsTab(Stream<QuerySnapshot> stream, bool darkTheme,
      Color primaryColor, Color textColor, Color secondaryTextColor) {
    return RefreshIndicator(
      onRefresh: () async {
        // Replace setState with Riverpod refresh
        ref.read(refreshingProvider.notifier).update((state) => !state);
      },
      color: primaryColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tweets')
            .where('userId', isEqualTo: auth.currentUser?.uid)
            .where('archived', isEqualTo: false)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            print("Error in posts tab: ${snapshot.error}"); // Debug info
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final posts = snapshot.data?.docs ?? [];
          print("Posts count: ${posts.length}"); // Debug info

          if (posts.isEmpty) {
            return Center(
                child: Text(
              ref.watch(lang) == 'tr' ? 'Henüz gönderi yok' : 'No posts yet',
              style: TextStyle(color: secondaryTextColor, fontSize: 16),
            ));
          }

          return _buildPostsList(
              posts, darkTheme, primaryColor, textColor, secondaryTextColor);
        },
      ),
    );
  }

  // Modified post list to handle potential errors
  Widget _buildPostsList(List<QueryDocumentSnapshot> posts, bool darkTheme,
      Color primaryColor, Color textColor, Color secondaryTextColor,
      [bool isArchiveTab = false]) {
    if (posts.isEmpty) {
      return Center(
        child: Text(
          'No posts to display',
          style: TextStyle(color: secondaryTextColor, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        try {
          final post = posts[index];
          if (post.data() == null) {
            print("Post data is null at index $index");
            return const SizedBox.shrink(); // Skip invalid posts
          }

          final postData = post.data() as Map<String, dynamic>;
          final isLiked =
              postData['likedBy']?.contains(auth.currentUser?.uid) ?? false;

          // Check if current user is the owner of this tweet
          final isOwner = postData['userId'] == auth.currentUser?.uid;

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
                    onBackgroundImageError: (e, stackTrace) {
                      print("Error loading profile image: $e");
                    },
                  ),
                  title: Row(
                    children: [
                      Text(
                        postData['userName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (isArchiveTab)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.archive,
                              size: 16, color: secondaryTextColor),
                        ),
                    ],
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
                  // Only show popup menu if user is the owner
                  trailing: isOwner
                      ? PopupMenuButton<String>(
                          icon:
                              Icon(Icons.more_vert, color: secondaryTextColor),
                          onSelected: (value) {
                            if (value == 'archive') {
                              _toggleArchiveStatus(post.id, true);
                            } else if (value == 'unarchive') {
                              _toggleArchiveStatus(post.id, false);
                            } else if (value == 'delete') {
                              _deletePost(post.id);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: isArchiveTab ? 'unarchive' : 'archive',
                              child: Row(
                                children: [
                                  Icon(
                                    isArchiveTab
                                        ? Icons.unarchive
                                        : Icons.archive,
                                    color: textColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isArchiveTab
                                        ? (ref.watch(lang) == 'tr'
                                            ? 'Arşivden Çıkar'
                                            : 'Unarchive')
                                        : (ref.watch(lang) == 'tr'
                                            ? 'Arşivle'
                                            : 'Archive'),
                                    style: TextStyle(
                                        color: textColor, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    ref.watch(lang) == 'tr' ? 'Sil' : 'Delete',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
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
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: primaryColor,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print("Error loading post image: $error");
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
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('tweets')
                            .doc(post.id)
                            .collection('comments')
                            .get(),
                        builder: (context, snapshot) {
                          int commentCount = snapshot.data?.docs.length ?? 0;
                          return Text(
                            "$commentCount",
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
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
        } catch (e) {
          print("Error rendering post at index $index: $e");
          return const SizedBox.shrink(); // Skip rendering this post if error
        }
      },
    );
  }

  // Add a debug method to check Firestore data
  Future<void> _checkFirestoreData() async {
    if (_isDisposed) return;

    try {
      if (auth.currentUser?.uid == null) {
        print("User ID is null, cannot check Firestore data");
        return;
      }

      final QuerySnapshot postsSnapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .where('userId', isEqualTo: auth.currentUser?.uid)
          .get();

      print("Total posts found: ${postsSnapshot.docs.length}");

      // Check for archived field in documents
      int missingArchivedField = 0;
      for (var doc in postsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('archived')) {
          missingArchivedField++;
          // Fix missing archived field
          await FirebaseFirestore.instance
              .collection('tweets')
              .doc(doc.id)
              .update({'archived': false});
        }
      }

      if (missingArchivedField > 0) {
        print(
            "Fixed $missingArchivedField documents with missing 'archived' field");
      }

      final QuerySnapshot archivedSnapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .where('userId', isEqualTo: auth.currentUser?.uid)
          .where('archived', isEqualTo: true)
          .get();

      print("Archived posts: ${archivedSnapshot.docs.length}");

      final QuerySnapshot nonArchivedSnapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .where('userId', isEqualTo: auth.currentUser?.uid)
          .where('archived', isEqualTo: false)
          .get();

      print("Non-archived posts: ${nonArchivedSnapshot.docs.length}");
    } catch (e) {
      if (mounted && !_isDisposed) {
        print("Error checking Firestore data: $e");
      }
    }
  }

  // New archive functionality methods
  void _toggleArchiveStatus(String postId, bool archive) {
    if (_isDisposed) return;

    FirebaseFirestore.instance.collection('tweets').doc(postId).update({
      'archived': archive,
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive
              ? (ref.watch(lang) == 'tr'
                  ? 'Gönderi arşivlendi'
                  : 'Post archived')
              : (ref.watch(lang) == 'tr'
                  ? 'Gönderi arşivden çıkarıldı'
                  : 'Post unarchived')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      // Instead of setState, trigger refresh through Riverpod
      if (mounted && !_isDisposed) {
        ref.read(refreshingProvider.notifier).update((state) => !state);
      }
    }).catchError((error) {
      print("Error updating archive status: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _deletePost(String postId) {
    if (_isDisposed) return; // Safety check

    _controller.deletePost(context, postId, ref.read(lang));
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

  // This duplicate method was removed to fix naming conflict

  Widget _buildLikesTab(bool darkTheme, Color primaryColor, Color textColor,
      Color secondaryTextColor) {
    return RefreshIndicator(
      onRefresh: () async {
        // Replace setState with Riverpod refresh
        ref.read(refreshingProvider.notifier).update((state) => !state);
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

  // New method to display social links
  Widget _buildSocialLinks(
      Map<String, dynamic> socialLinks, Color textColor, Color accentColor) {
    final links = <Widget>[];

    if (socialLinks['instagram']?.isNotEmpty == true) {
      links.add(_buildSocialLink(Icons.camera_alt, 'Instagram',
          socialLinks['instagram'], textColor, accentColor));
    }

    if (socialLinks['twitter']?.isNotEmpty == true) {
      links.add(_buildSocialLink(Icons.alternate_email, 'Twitter',
          socialLinks['twitter'], textColor, accentColor));
    }

    if (socialLinks['facebook']?.isNotEmpty == true) {
      links.add(_buildSocialLink(Icons.facebook, 'Facebook',
          socialLinks['facebook'], textColor, accentColor));
    }

    if (socialLinks['website']?.isNotEmpty == true) {
      links.add(_buildSocialLink(Icons.language, 'Website',
          socialLinks['website'], textColor, accentColor));
    }

    if (links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: links,
      ),
    );
  }

  Widget _buildSocialLink(IconData icon, String platform, String handle,
      Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Text(
            '$platform: $handle',
            style: TextStyle(
              color: textColor.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
