import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DiscoverPageController {
  String timeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  Future<String> getUserName(String userId) async {
    if (userId.isEmpty) {
      return 'Unknown';
    }
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['displayname'] ?? 'Unknown';
  }
}
