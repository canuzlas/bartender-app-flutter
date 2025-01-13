import 'package:cloud_firestore/cloud_firestore.dart';

class Tweet {
  final String id;
  final String message;
  final DateTime timestamp;
  final String userId;
  int likes;
  List<String> likedBy;

  Tweet(this.id, this.message, this.timestamp, this.userId,
      {this.likes = 0, this.likedBy = const []});

  factory Tweet.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Tweet(
      doc.id,
      data['message'] ?? '',
      (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data['userId'] ?? '',
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'likes': likes,
      'likedBy': likedBy,
    };
  }
}
