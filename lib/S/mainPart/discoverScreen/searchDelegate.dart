import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSearchDelegate extends SearchDelegate {
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  String get searchFieldLabel => 'Search users';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ThemeData(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]),
      ),
      textTheme: theme.textTheme,
      primaryColor: isDark ? Colors.white : Colors.black87,
      primaryIconTheme: theme.primaryIconTheme.copyWith(
        color: isDark ? Colors.white : Colors.black87,
      ),
      scaffoldBackgroundColor: isDark ? Colors.black : Colors.white,
      brightness: theme.brightness,
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        close(context, null);
      },
    );
  }

  Future<void> _toggleFollow(String userId, bool isFollowing) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final currentUserDoc =
        FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    if (isFollowing) {
      await userDoc.update({
        'followers': FieldValue.arrayRemove([currentUser.uid]),
      });
      await currentUserDoc.update({
        'following': FieldValue.arrayRemove([userId]),
      });
    } else {
      await userDoc.update({
        'followers': FieldValue.arrayUnion([currentUser.uid]),
      });
      await currentUserDoc.update({
        'following': FieldValue.arrayUnion([userId]),
      });
    }
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptySearchState(context);
    }

    final searchQuery = query.trim();
    final resultsStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayname')
        .startAt([searchQuery]).endAt([searchQuery + '\uf8ff']).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: resultsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error);
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return _buildNoResultsState(context);
        }

        return _buildUserList(context, users);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildEmptySearchState(context);
    }

    final searchQuery = query.trim();
    final suggestionsStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayname')
        .startAt([searchQuery]).endAt([searchQuery + '\uf8ff']).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: suggestionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }
        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error);
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return _buildNoResultsState(context);
        }

        return _buildUserList(context, users);
      },
    );
  }

  Widget _buildUserList(
      BuildContext context, List<QueryDocumentSnapshot> users) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      itemCount: users.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final user = users[index];
        var isFollowing = (user['followers'] as List<dynamic>?)
                ?.contains(auth.currentUser?.uid) ??
            false;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey[300],
              backgroundImage:
                  NetworkImage(user['photoURL'] ?? 'https://picsum.photos/200'),
            ),
            title: Text(
              user['displayname'] ?? 'User',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              '@${user['displayname'] ?? 'username'}',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
            trailing: StatefulBuilder(
              builder: (context, setState) {
                return ElevatedButton(
                  onPressed: () async {
                    await _toggleFollow(user.id, isFollowing);
                    setState(() {
                      isFollowing = !isFollowing;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? (isDark ? Colors.grey[800] : Colors.grey[200])
                        : (isDark ? Colors.blueAccent : Colors.blue),
                    foregroundColor: isFollowing
                        ? (isDark ? Colors.white70 : Colors.black87)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: isFollowing ? 0 : 2,
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 72,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Search for users',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off,
            size: 72,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          isDark ? Colors.white70 : Colors.grey[800]!,
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, dynamic error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: isDark ? Colors.redAccent : Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading search results',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
