import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomeScreenController {
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> toggleLike(String postId, bool isLiked) async {
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
