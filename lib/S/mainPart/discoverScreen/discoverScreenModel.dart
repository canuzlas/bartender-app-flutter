import 'package:cloud_firestore/cloud_firestore.dart';

class Tweet {
  final String id;
  final String message;
  final DateTime timestamp;
  final String userId;
  int likes;
  List<String> likedBy;
  String userPhotoURL;
  String userName;
  String postImageURL; // New field for post image URL

  Tweet(this.id, this.message, this.timestamp, this.userId,
      {this.likes = 0,
      this.likedBy = const [],
      this.userPhotoURL = '',
      this.userName = '',
      this.postImageURL = ''}); // Default empty

  factory Tweet.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Tweet(
      doc.id,
      data['message'] ?? '',
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data['userId'] ?? '',
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      userPhotoURL: data['userPhotoURL'] ?? '',
      userName: data['userName'] ?? '',
      postImageURL: data['photoURL'] ?? '', // Extract post image URL
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'likes': likes,
      'likedBy': likedBy,
      'userPhotoURL': userPhotoURL,
      'userName': userName,
      'postImageURL': postImageURL, // Map the post image URL
    };
  }
}
