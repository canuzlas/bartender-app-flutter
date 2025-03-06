import 'dart:io';

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

class NewPostState {
  final File? selectedImage;
  final bool isUploading;
  const NewPostState({this.selectedImage, this.isUploading = false});

  NewPostState copyWith({File? selectedImage, bool? isUploading}) {
    return NewPostState(
      selectedImage: selectedImage ?? this.selectedImage,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class NewPostNotifier extends StateNotifier<NewPostState> {
  NewPostNotifier() : super(const NewPostState());

  void setSelectedImage(File file) {
    state = state.copyWith(selectedImage: file);
  }

  void clearSelectedImage() {
    state = state.copyWith(selectedImage: null);
  }

  void setUploading(bool value) {
    state = state.copyWith(isUploading: value);
  }

  void reset() {
    state = const NewPostState();
  }
}

final newPostProvider =
    StateNotifierProvider<NewPostNotifier, NewPostState>((ref) {
  return NewPostNotifier();
});
