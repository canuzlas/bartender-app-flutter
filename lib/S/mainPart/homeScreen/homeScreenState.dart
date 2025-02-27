import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod/riverpod.dart';

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
