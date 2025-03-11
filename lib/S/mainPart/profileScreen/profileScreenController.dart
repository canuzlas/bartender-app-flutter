import 'package:bartender/S/mainPart/profileScreen/emojiesButtons.dart'
    as emojiPicker;
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ProfileScreenController {
  final FirebaseAuth auth = FirebaseAuth.instance;
  late SharedPreferences sss;
  String selectedEmoji = "🍸";

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

  // New method for deleting a post
  Future<void> deletePost(
      BuildContext context, String postId, String langMain) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              langMain == 'tr' ? 'Gönderiyi Sil' : 'Delete Post',
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
              ? 'Bu gönderiyi silmek istediğinizden emin misiniz?'
              : 'Are you sure you want to delete this post?',
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
              langMain == 'tr' ? 'İptal' : 'Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              langMain == 'tr' ? 'Sil' : 'Delete',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      // First delete all comments
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .doc(postId)
          .collection('comments')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Then delete the post itself
      await FirebaseFirestore.instance
          .collection('tweets')
          .doc(postId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langMain == 'tr' ? 'Gönderi silindi' : 'Post deleted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // New method for editing profile with improved error handling
  Future<void> editProfile(BuildContext context, WidgetRef ref) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      _showErrorDialog(
          context,
          ref.read(lang) == 'tr'
              ? 'Oturum açmanız gerekiyor'
              : 'You need to be logged in',
          ref.read(lang));
      return;
    }

    try {
      // Show loading indicator while getting user data
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.orangeAccent
                : Colors.deepOrange,
          ),
        ),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Close loading dialog
      Navigator.of(context).pop();

      final userData = userDoc.data();
      if (userData == null) {
        _showErrorDialog(
            context,
            ref.read(lang) == 'tr'
                ? 'Kullanıcı bilgisi bulunamadı'
                : 'User data not found',
            ref.read(lang));
        return;
      }

      final darkThemeMain = ref.watch(darkTheme);
      final langMain = ref.watch(lang);

      final nameController =
          TextEditingController(text: userData['displayname']);
      final bioController = TextEditingController(text: userData['bio'] ?? '');
      File? imageFile;
      String? imageUrl = userData['photoURL'];

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black;
      final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: backgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.edit,
                      color: accentColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      langMain == 'tr' ? 'Profili Düzenle' : 'Edit Profile',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          try {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1000,
                              maxHeight: 1000,
                              imageQuality: 85,
                            );

                            if (image != null) {
                              setState(() {
                                imageFile = File(image.path);
                              });
                            }
                          } catch (e) {
                            print("Error picking image: $e");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  langMain == 'tr'
                                      ? 'Resim seçilirken hata oluştu'
                                      : 'Error selecting image',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: imageFile != null
                                  ? FileImage(imageFile!) as ImageProvider
                                  : NetworkImage(
                                      imageUrl ?? 'https://picsum.photos/200'),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: langMain == 'tr' ? 'İsim' : 'Name',
                          labelStyle: TextStyle(color: accentColor),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bioController,
                        style: TextStyle(color: textColor),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: langMain == 'tr' ? 'Biyografi' : 'Bio',
                          labelStyle: TextStyle(color: accentColor),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: accentColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: Text(
                      langMain == 'tr' ? 'İptal' : 'Cancel',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      );

                      try {
                        String photoURL = imageUrl ?? '';

                        // Upload new image if selected
                        if (imageFile != null) {
                          try {
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('profile_photos')
                                .child(
                                    '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

                            await storageRef.putFile(imageFile!);
                            photoURL = await storageRef.getDownloadURL();
                          } catch (e) {
                            print("Error uploading image: $e");

                            // Close loading dialog
                            Navigator.of(context).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  langMain == 'tr'
                                      ? 'Resim yüklenirken hata oluştu'
                                      : 'Error uploading image',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                        }

                        // Create a map with the fields to update
                        Map<String, dynamic> updateData = {
                          'displayname': nameController.text.trim(),
                          'bio': bioController.text.trim(),
                        };

                        // Only add photoURL if we have a valid one
                        if (photoURL.isNotEmpty) {
                          updateData['photoURL'] = photoURL;
                        }

                        // Update Firestore
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .update(updateData);

                        // Close loading dialog
                        Navigator.of(context).pop();
                        // Close edit dialog
                        Navigator.of(context).pop();

                        // Toggle refresh state to trigger UI update
                        ref
                            .read(refreshingProvider.notifier)
                            .update((state) => !state);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              langMain == 'tr'
                                  ? 'Profil güncellendi'
                                  : 'Profile updated successfully',
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      } catch (e) {
                        print("Error updating profile: $e");

                        // Close loading dialog
                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              langMain == 'tr'
                                  ? 'Bir hata oluştu: $e'
                                  : 'An error occurred: $e',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      langMain == 'tr' ? 'Kaydet' : 'Save',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      print("Exception in editProfile: $e");
      _showErrorDialog(
          context,
          ref.read(lang) == 'tr'
              ? 'İşlem sırasında bir hata oluştu'
              : 'An error occurred during the operation',
          ref.read(lang));
    }
  }

  void _showErrorDialog(BuildContext context, String message, String langMain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(langMain == 'tr' ? 'Hata' : 'Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(langMain == 'tr' ? 'Tamam' : 'OK'),
          ),
        ],
      ),
    );
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
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
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

      // Toggle refresh state to trigger UI update
      ref.read(refreshingProvider.notifier).update((state) => !state);

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            langMain == 'tr'
                ? 'Emoji güncellendi'
                : 'Emoji updated successfully',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> showUserListDialog(BuildContext context, String title,
      List<String> userIds, String langMain, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
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
                      icon: const Icon(Icons.delete, color: Colors.red),
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
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

final selectedEmojiProvider = StateProvider<String>((ref) => "🍸");
final refreshingProvider = StateProvider<bool>((ref) => false);
