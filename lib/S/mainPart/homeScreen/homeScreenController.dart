import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomeScreenController {
  final FirebaseAuth auth = FirebaseAuth.instance;

  String formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }
}

final likeProvider = StateNotifierProvider.family<LikeNotifier, bool, String>(
  (ref, postId) => LikeNotifier(postId),
);

class LikeNotifier extends StateNotifier<bool> {
  final String postId;
  int likeCount = 0;

  LikeNotifier(this.postId) : super(false) {
    _loadInitialLikeState();
  }

  Future<void> _loadInitialLikeState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final postDoc =
        await FirebaseFirestore.instance.collection('tweets').doc(postId).get();

    final likedBy = postDoc.data()?['likedBy'] as List<dynamic>? ?? [];
    state = likedBy.contains(currentUser.uid);
    likeCount = likedBy.length;
  }

  Future<void> toggleLike() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final postDoc = FirebaseFirestore.instance.collection('tweets').doc(postId);

    if (state) {
      await postDoc.update({
        'likedBy': FieldValue.arrayRemove([currentUser.uid]),
      });
      likeCount--;
    } else {
      await postDoc.update({
        'likedBy': FieldValue.arrayUnion([currentUser.uid]),
      });
      likeCount++;
    }
    state = !state;
  }
}
