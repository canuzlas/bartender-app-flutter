import 'package:bartender/S/mainPart/profileScreen/emojiesButtons.dart'
    as emojiPicker;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.exit_to_app,
              color: accentColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              langMain == 'tr' ? 'Çıkış' : 'Logout',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          langMain == 'tr'
              ? 'Hesabından çıkış yapacaksın, emin misin?'
              : 'Are you sure you want to log out?',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Logout',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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
    final backgroundColor =
        darkThemeMain ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = darkThemeMain ? Colors.white : Colors.black;
    final accentColor = darkThemeMain ? Colors.orangeAccent : Colors.deepOrange;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.settings,
              color: accentColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              langMain == 'tr' ? 'Ayarlar' : 'Settings',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: darkThemeMain ? Colors.black12 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  langMain == 'tr' ? 'Karanlık tema' : 'Dark theme',
                  style: TextStyle(color: textColor),
                ),
                trailing: Consumer(
                  builder: (context, watch, child) {
                    final darkThemeMain = ref.watch(darkTheme);
                    return Switch(
                      value: darkThemeMain,
                      activeColor: accentColor,
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
            ),
            Container(
              decoration: BoxDecoration(
                color: darkThemeMain ? Colors.black12 : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  langMain == 'tr' ? 'Dil' : 'Language',
                  style: TextStyle(color: textColor),
                ),
                trailing: Consumer(
                  builder: (context, watch, child) {
                    final langMain = ref.watch(lang);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentColor, width: 1),
                      ),
                      child: DropdownButton<String>(
                        value: langMain,
                        underline: const SizedBox(),
                        dropdownColor: backgroundColor,
                        style: TextStyle(color: accentColor),
                        icon: Icon(Icons.arrow_drop_down, color: accentColor),
                        items: [
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              langMain == 'tr' ? 'İngilizce' : ' English',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'tr',
                            child: Text(
                              langMain == 'tr' ? 'Türkçe' : 'Turkish',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          sss.setString("lang", value.toString());
                          ref.read(lang.notifier).state = value!;
                          Navigator.of(context).pop();
                          showSettingsDialog(context, ref);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              langMain == 'tr' ? 'Kapat' : 'Close',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> selectEmoji(
      BuildContext context, String langMain, WidgetRef ref) async {
    // Using the new showEmojiPicker function from emojiesButtons.dart
    final emoji = await emojiPicker.showEmojiPicker(context);

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
