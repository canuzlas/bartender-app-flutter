import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSearchDelegate extends SearchDelegate {
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
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
    if (query.isEmpty) return Container(); // Added empty-check

    final searchQuery = query.trim();
    final resultsStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayname')
        .startAt([searchQuery]).endAt([searchQuery + '\uf8ff']).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: resultsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            var isFollowing = (user['followers'] as List<dynamic>?)
                    ?.contains(auth.currentUser?.uid) ??
                false;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(
                    user['photoURL'] ?? 'https://picsum.photos/200'),
              ),
              title: Text(user['displayname']),
              trailing: StatefulBuilder(
                builder: (context, setState) {
                  return ElevatedButton(
                    onPressed: () async {
                      await _toggleFollow(user.id, isFollowing);
                      setState(() {
                        isFollowing = !isFollowing;
                      });
                    },
                    child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) return Container(); // Added empty-check

    final searchQuery = query.trim();
    final suggestionsStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayname')
        .startAt([searchQuery]).endAt([searchQuery + '\uf8ff']).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: suggestionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data?.docs ?? [];
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            var isFollowing = (user['followers'] as List<dynamic>?)
                    ?.contains(auth.currentUser?.uid) ??
                false;
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(
                    user['photoURL'] ?? 'https://picsum.photos/200'),
              ),
              title: Text(user['displayname']),
              trailing: StatefulBuilder(
                builder: (context, setState) {
                  return ElevatedButton(
                    onPressed: () async {
                      await _toggleFollow(user.id, isFollowing);
                      setState(() {
                        isFollowing = !isFollowing;
                      });
                    },
                    child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
