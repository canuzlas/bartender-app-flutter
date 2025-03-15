import 'package:bartender/S/mainPart/discoverScreen/discoverScreenModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod/riverpod.dart';

final tweetProvider = StreamProvider<List<Tweet>>((ref) {
  return FirebaseFirestore.instance
      .collection('tweets')
      .where('archived', isEqualTo: false) // Filter out archived tweets
      .orderBy('timestamp', descending: true) // Sort by timestamp descending
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => Tweet.fromDocument(doc))
        .toList()
        .cast<Tweet>();
  });
});
