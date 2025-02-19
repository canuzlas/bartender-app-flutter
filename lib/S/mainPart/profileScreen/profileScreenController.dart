import 'package:bartender/S/mainPart/profileScreen/emojiesButtons.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreenController {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late SharedPreferences sss;
  String selectedEmoji = "🍸"; // Add this line

  Future<void> loadSharedPreferences(WidgetRef ref) async {
    sss = await SharedPreferences.getInstance();
    ref.read(selectedEmojiProvider.notifier).state =
        sss.getString('selectedEmoji') ?? "🍸";
  }

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

  Future<void> confirmLogout(BuildContext context, String langMain) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(langMain == 'tr' ? 'Çıkış' : 'Logout'),
        content: Text(langMain == 'tr'
            ? 'Hesabından çıkış yapacaksın, emin misin?'
            : 'Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(
          context, '/loginScreen', (route) => false);
    }
  }

  Future<void> showSettingsDialog(BuildContext context, WidgetRef ref) async {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(langMain == 'tr' ? 'Ayarlar' : 'Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(langMain == 'tr' ? 'Karanlık tema' : 'Dark theme'),
              trailing: Consumer(
                builder: (context, watch, child) {
                  final darkThemeMain = ref.watch(darkTheme);
                  return Switch(
                    value: darkThemeMain,
                    onChanged: (value) {
                      sss.setBool("darkTheme", value);
                      ref.read(darkTheme.notifier).state = value;
                      Navigator.of(context).pop();
                      showSettingsDialog(context, ref);
                    },
                  );
                },
              ),
            ),
            ListTile(
              title: Text(langMain == 'tr' ? 'Dil' : 'Language'),
              trailing: Consumer(
                builder: (context, watch, child) {
                  final langMain = ref.watch(lang);
                  return DropdownButton<String>(
                    value: langMain,
                    items: [
                      DropdownMenuItem(
                        value: 'en',
                        child:
                            Text(langMain == 'tr' ? 'İngilizce' : ' English'),
                      ),
                      DropdownMenuItem(
                        value: 'tr',
                        child: Text(langMain == 'tr' ? 'Türkçe' : 'Turkish'),
                      ),
                    ],
                    onChanged: (value) {
                      sss.setString("lang", value.toString());
                      ref.read(lang.notifier).state = value!;
                      Navigator.of(context).pop();
                      showSettingsDialog(context, ref);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(langMain == 'tr' ? 'Kapat' : 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> showEmojiPicker(
      BuildContext context, String langMain, WidgetRef ref) async {
    final emoji = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          langMain == 'tr' ? 'Emojini Seç' : 'Select your emoji',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: returnEmojiesButtons(context)
                .map((emojiButton) => Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: emojiButton,
                    ))
                .toList()
                .cast<Widget>(), // Ensure the list is of type List<Widget>
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              langMain == 'tr' ? 'Kapat' : 'Close',
              style: TextStyle(
                  color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (emoji != null) {
      ref.read(selectedEmojiProvider.notifier).state = emoji;
      sss.setString('selectedEmoji', emoji); // Save the selected emoji
    }
  }

  Future<void> showUserListDialog(BuildContext context, String title,
      List<String> userIds, String langMain, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final userId = userIds[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      title: Text(
                          langMain == 'tr' ? 'Yükleniyor...' : 'Loading...'),
                    );
                  }
                  if (snapshot.hasError) {
                    return ListTile(
                      title: Text('Error: ${snapshot.error}'),
                    );
                  }
                  final userDoc = snapshot.data;
                  final userData = userDoc?.data() as Map<String, dynamic>?;
                  if (userData == null) {
                    return ListTile(
                      title: Text(langMain == 'tr' ? 'Bilgi yok' : 'Unknown'),
                    );
                  }
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(
                          userData['photoURL'] ?? 'https://picsum.photos/200'),
                    ),
                    title: Text(userData['displayname'] ?? 'Unknown'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(auth.currentUser!.uid)
                            .update({
                          title == 'Followers' || title == 'Takipçiler'
                              ? 'followers'
                              : 'following': FieldValue.arrayRemove([userId]),
                        });
                        userIds.removeAt(index);
                        Navigator.of(context).pop();
                        showUserListDialog(
                            context, title, userIds, langMain, ref);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

final selectedEmojiProvider = StateProvider<String>((ref) => "🍸");
final ProfileScreenController _controller = ProfileScreenController();
