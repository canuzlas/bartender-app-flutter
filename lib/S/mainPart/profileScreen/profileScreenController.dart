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
          return Consumer(
            builder: (context, widgetRef, child) {
              // Use widgetRef to watch the imageFile provider
              final imageFile = widgetRef.watch(profileImageFileProvider);

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
                              // Update provider instead of using setState
                              widgetRef
                                  .read(profileImageFileProvider.notifier)
                                  .state = File(image.path);
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
                                  ? FileImage(imageFile) as ImageProvider
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

                            await storageRef.putFile(imageFile);
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

  // Method to manage scheduled posts
  Future<void> saveScheduledPost(
    BuildContext context,
    String content,
    File? imageFile,
    DateTime scheduledDate,
    WidgetRef ref,
  ) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final langMain = ref.read(lang);

    try {
      // Show loading indicator
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

      String? photoURL;
      if (imageFile != null) {
        // Upload image
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('scheduled_posts')
            .child(
                '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(imageFile);
        photoURL = await storageRef.getDownloadURL();
      }

      // Get user information
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data();

      // Create scheduled post document
      await FirebaseFirestore.instance.collection('scheduled_posts').add({
        'userId': currentUser.uid,
        'userName': userData?['displayname'] ?? 'Unknown',
        'userPhotoURL': userData?['photoURL'] ?? '',
        'message': content,
        'photoURL': photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': scheduledDate,
        'published': false,
      });

      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            langMain == 'tr'
                ? 'Gönderi başarıyla planlandı'
                : 'Post scheduled successfully',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      try {
        Navigator.pop(context);
      } catch (_) {}

      print("Error scheduling post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            langMain == 'tr'
                ? 'Gönderi planlanırken bir hata oluştu'
                : 'An error occurred while scheduling the post',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to manage scheduled posts
  Future<void> getScheduledPosts(BuildContext context, WidgetRef ref) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final langMain = ref.read(lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    try {
      final scheduled = await FirebaseFirestore.instance
          .collection('scheduled_posts')
          .where('userId', isEqualTo: currentUser.uid)
          .where('published', isEqualTo: false)
          .orderBy('scheduledFor', descending: false)
          .get();

      if (scheduled.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              langMain == 'tr'
                  ? 'Planlanmış gönderi bulunmamaktadır'
                  : 'No scheduled posts found',
            ),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            langMain == 'tr' ? 'Planlanmış Gönderiler' : 'Scheduled Posts',
            style: TextStyle(color: textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: scheduled.docs.length,
              itemBuilder: (context, index) {
                final post = scheduled.docs[index].data();
                final scheduledDate =
                    (post['scheduledFor'] as Timestamp).toDate();
                final now = DateTime.now();
                final isOverdue = scheduledDate.isBefore(now);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isOverdue ? Colors.red.withOpacity(0.1) : null,
                  child: ListTile(
                    title: Text(
                      post['message'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year} - ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color:
                            isOverdue ? Colors.red : textColor.withOpacity(0.7),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: accentColor,
                          onPressed: () => _editScheduledPost(
                            context,
                            scheduled.docs[index].id,
                            post,
                            ref,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () => _deleteScheduledPost(
                              context, scheduled.docs[index].id, langMain, ref),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                langMain == 'tr' ? 'Kapat' : 'Close',
                style: TextStyle(color: accentColor),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error getting scheduled posts: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            langMain == 'tr'
                ? 'Planlanmış gönderiler alınırken bir hata oluştu'
                : 'An error occurred while getting scheduled posts',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper for scheduled posts
  Future<void> _editScheduledPost(
    BuildContext context,
    String postId,
    Map<String, dynamic> post,
    WidgetRef ref,
  ) async {
    // Implementation would be similar to saveScheduledPost but with updates
    // Not fully implemented to keep code concise
    Navigator.pop(context); // Close the list dialog

    final langMain = ref.read(lang);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          langMain == 'tr'
              ? 'Gönderi düzenleme yakında gelecek'
              : 'Post editing coming soon',
        ),
      ),
    );
  }

  Future<void> _deleteScheduledPost(
      BuildContext context, String postId, String langMain, ref) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(langMain == 'tr' ? 'Gönderiyi Sil' : 'Delete Post'),
        content: Text(
          langMain == 'tr'
              ? 'Bu planlanmış gönderiyi silmek istediğinizden emin misiniz?'
              : 'Are you sure you want to delete this scheduled post?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(langMain == 'tr' ? 'İptal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              langMain == 'tr' ? 'Sil' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('scheduled_posts')
            .doc(postId)
            .delete();

        // Refresh the scheduled posts list
        Navigator.pop(context);
        getScheduledPosts(context, ref);
      } catch (e) {
        print("Error deleting scheduled post: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              langMain == 'tr'
                  ? 'Gönderi silinirken bir hata oluştu'
                  : 'An error occurred while deleting the post',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method for linking social media accounts
  Future<void> manageSocialLinks(BuildContext context, WidgetRef ref) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final langMain = ref.read(lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    // Get current social links
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final socialLinks = userData['socialLinks'] as Map<String, dynamic>? ??
        {
          'instagram': '',
          'twitter': '',
          'facebook': '',
          'website': '',
        };

    // Controllers for each field
    final instagramController =
        TextEditingController(text: socialLinks['instagram'] ?? '');
    final twitterController =
        TextEditingController(text: socialLinks['twitter'] ?? '');
    final facebookController =
        TextEditingController(text: socialLinks['facebook'] ?? '');
    final websiteController =
        TextEditingController(text: socialLinks['website'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          langMain == 'tr' ? 'Sosyal Medya Hesapları' : 'Social Media Accounts',
          style: TextStyle(color: textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSocialField(
                context,
                Icons.alternate_email,
                'Instagram',
                instagramController,
                accentColor,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildSocialField(
                context,
                Icons.alternate_email,
                'Twitter',
                twitterController,
                accentColor,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildSocialField(
                context,
                Icons.facebook,
                'Facebook',
                facebookController,
                accentColor,
                textColor,
              ),
              const SizedBox(height: 10),
              _buildSocialField(
                context,
                Icons.language,
                langMain == 'tr' ? 'Web Sitesi' : 'Website',
                websiteController,
                accentColor,
                textColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              langMain == 'tr' ? 'İptal' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update social links
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .update({
                  'socialLinks': {
                    'instagram': instagramController.text.trim(),
                    'twitter': twitterController.text.trim(),
                    'facebook': facebookController.text.trim(),
                    'website': websiteController.text.trim(),
                  }
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      langMain == 'tr'
                          ? 'Sosyal medya hesapları güncellendi'
                          : 'Social media accounts updated',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );

                // Refresh the profile
                ref.read(refreshingProvider.notifier).update((state) => !state);
              } catch (e) {
                print("Error updating social links: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      langMain == 'tr'
                          ? 'Bir hata oluştu'
                          : 'An error occurred',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            child: Text(langMain == 'tr' ? 'Kaydet' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialField(
    BuildContext context,
    IconData icon,
    String label,
    TextEditingController controller,
    Color accentColor,
    Color textColor,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor),
        prefixIcon: Icon(icon, color: accentColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
      ),
    );
  }

  // Method to update story visibility settings
  Future<void> updateStoryPrivacy(BuildContext context, WidgetRef ref) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final langMain = ref.read(lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    // Get current settings
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final userData = userDoc.data() ?? {};
    final privacy = userData['privacySettings'] as Map<String, dynamic>? ??
        {
          'storyVisibility': 'everyone',
          'profileVisibility': 'everyone',
          'allowComments': true,
          'allowMessages': true,
        };

    // Story visibility options
    final storyOptions = [
      {'value': 'everyone', 'name': langMain == 'tr' ? 'Herkes' : 'Everyone'},
      {
        'value': 'followers',
        'name': langMain == 'tr' ? 'Takipçiler' : 'Followers'
      },
      {'value': 'none', 'name': langMain == 'tr' ? 'Hiç Kimse' : 'Nobody'},
    ];

    // Current selections
    String storyVisibility = privacy['storyVisibility'] ?? 'everyone';
    String profileVisibility = privacy['profileVisibility'] ?? 'everyone';
    bool allowComments = privacy['allowComments'] ?? true;
    bool allowMessages = privacy['allowMessages'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text(
              langMain == 'tr' ? 'Gizlilik Ayarları' : 'Privacy Settings',
              style: TextStyle(color: textColor),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Story visibility
                  Text(
                    langMain == 'tr'
                        ? 'Hikaye Görünürlüğü'
                        : 'Story Visibility',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...storyOptions.map((option) => RadioListTile<String>(
                        title: Text(
                          option['name'] as String,
                          style: TextStyle(color: textColor),
                        ),
                        value: option['value'] as String,
                        groupValue: storyVisibility,
                        activeColor: accentColor,
                        onChanged: (value) {
                          setState(() {
                            storyVisibility = value!;
                          });
                        },
                      )),

                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 15),

                  // Comment permission
                  SwitchListTile(
                    title: Text(
                      langMain == 'tr'
                          ? 'Yorumlara İzin Ver'
                          : 'Allow Comments',
                      style: TextStyle(color: textColor),
                    ),
                    value: allowComments,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        allowComments = value;
                      });
                    },
                  ),

                  // Direct message permission
                  SwitchListTile(
                    title: Text(
                      langMain == 'tr'
                          ? 'Mesajlara İzin Ver'
                          : 'Allow Messages',
                      style: TextStyle(color: textColor),
                    ),
                    value: allowMessages,
                    activeColor: accentColor,
                    onChanged: (value) {
                      setState(() {
                        allowMessages = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  langMain == 'tr' ? 'İptal' : 'Cancel',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({
                      'privacySettings': {
                        'storyVisibility': storyVisibility,
                        'profileVisibility': profileVisibility,
                        'allowComments': allowComments,
                        'allowMessages': allowMessages,
                      }
                    });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          langMain == 'tr'
                              ? 'Gizlilik ayarları güncellendi'
                              : 'Privacy settings updated',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("Error updating privacy settings: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          langMain == 'tr'
                              ? 'Bir hata oluştu'
                              : 'An error occurred',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(langMain == 'tr' ? 'Kaydet' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Method to view post statistics
  Future<void> viewPostStatistics(BuildContext context, WidgetRef ref) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final langMain = ref.read(lang);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final accentColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

    // Store context information locally before async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    bool isDialogDismissed = false;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          // Prevent back button from dismissing without setting our flag
          onWillPop: () async {
            isDialogDismissed = true;
            return true;
          },
          child: Center(
            child: CircularProgressIndicator(color: accentColor),
          ),
        ),
      );

      // Get posts with stats
      final posts = await FirebaseFirestore.instance
          .collection('tweets')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      // Calculate engagement
      int totalLikes = 0;
      int totalComments = 0;
      int postsCount = posts.docs.length;
      List<Map<String, dynamic>> postStats = [];

      for (var post in posts.docs) {
        final data = post.data();
        final likes = (data['likedBy'] as List<dynamic>?)?.length ?? 0;
        totalLikes += likes;

        // Get comments count
        final comments = await FirebaseFirestore.instance
            .collection('tweets')
            .doc(post.id)
            .collection('comments')
            .count()
            .get();

        final commentsCount = comments.count;
        totalComments += commentsCount!;

        postStats.add({
          'id': post.id,
          'message': data['message'],
          'timestamp': data['timestamp'],
          'likes': likes,
          'comments': commentsCount,
          'photoURL': data['photoURL'],
        });
      }

      // Sort posts by engagement (likes + comments)
      postStats.sort((a, b) => ((b['likes'] as int) + (b['comments'] as int))
          .compareTo((a['likes'] as int) + (a['comments'] as int)));

      // Calculate engagement rate if there are followers
      double engagementRate = 0;
      String engagementText = '';

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final userData = userDoc.data();
        if (userData != null) {
          final followersCount =
              (userData['followers'] as List<dynamic>?)?.length ?? 0;

          if (followersCount > 0 && postsCount > 0) {
            // Calculate average engagement per post divided by followers
            engagementRate = ((totalLikes + totalComments) / postsCount) /
                followersCount *
                100;

            engagementText = langMain == 'tr'
                ? 'Etkileşim oranı: ${engagementRate.toStringAsFixed(1)}%'
                : 'Engagement rate: ${engagementRate.toStringAsFixed(1)}%';
          }
        }
      } catch (e) {
        print("Error calculating engagement rate: $e");
      }

      // Close loading dialog safely
      if (!isDialogDismissed) {
        try {
          navigator.pop();
        } catch (e) {
          // Navigator might already be popped
          print("Error while popping dialog: $e");
        }
      }

      // Make sure we're not showing dialog if context is no longer valid
      if (!context.mounted) return;

      // Show stats
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            langMain == 'tr' ? 'Gönderi İstatistikleri' : 'Post Statistics',
            style: TextStyle(color: textColor),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatBox(
                            postsCount.toString(),
                            langMain == 'tr' ? 'Gönderi' : 'Posts',
                            Icons.post_add,
                            textColor,
                          ),
                          _buildStatBox(
                            totalLikes.toString(),
                            langMain == 'tr' ? 'Beğeni' : 'Likes',
                            Icons.favorite,
                            textColor,
                          ),
                          _buildStatBox(
                            totalComments.toString(),
                            langMain == 'tr' ? 'Yorum' : 'Comments',
                            Icons.comment,
                            textColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        postsCount > 0
                            ? (langMain == 'tr'
                                ? 'Gönderi başına ortalama ${(totalLikes / postsCount).toStringAsFixed(1)} beğeni'
                                : 'Average ${(totalLikes / postsCount).toStringAsFixed(1)} likes per post')
                            : (langMain == 'tr'
                                ? 'Henüz gönderi yok'
                                : 'No posts yet'),
                        style: TextStyle(color: textColor),
                      ),
                      if (engagementText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            engagementText,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (engagementRate > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildEngagementIndicator(
                            engagementRate,
                            isDark,
                            textColor,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),
                Text(
                  langMain == 'tr'
                      ? 'En Çok Etkileşim Alan Gönderiler'
                      : 'Most Engaging Posts',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),

                // Post list
                Expanded(
                  child: postStats.isEmpty
                      ? Center(
                          child: Text(
                            langMain == 'tr'
                                ? 'Gönderi bulunamadı'
                                : 'No posts found',
                            style: TextStyle(color: textColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: postStats.length,
                          itemBuilder: (innerContext, index) {
                            final post = postStats[index];
                            final messageText =
                                post['message']?.toString() ?? '';
                            final displayText = messageText.isEmpty
                                ? (langMain == 'tr'
                                    ? '(Boş gönderi)'
                                    : '(Empty post)')
                                : messageText.length > 30
                                    ? '${messageText.substring(0, 30)}...'
                                    : messageText;

                            return ListTile(
                              title: Text(
                                displayText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textColor),
                              ),
                              subtitle: Row(
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.red, size: 16),
                                  Text(' ${post['likes']} · ',
                                      style: TextStyle(
                                          color: textColor.withOpacity(0.7))),
                                  Icon(Icons.comment,
                                      color: accentColor, size: 16),
                                  Text(' ${post['comments']}',
                                      style: TextStyle(
                                          color: textColor.withOpacity(0.7))),
                                ],
                              ),
                              leading: post['photoURL'] != null &&
                                      post['photoURL'].toString().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        post['photoURL'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, e, s) => Icon(
                                          Icons.image_not_supported,
                                          color: textColor.withOpacity(0.5),
                                        ),
                                      ),
                                    )
                                  : Icon(Icons.text_snippet,
                                      color: accentColor),
                              trailing: IconButton(
                                icon: const Icon(Icons.bar_chart),
                                color: accentColor,
                                onPressed: () {
                                  // Show specific post analytics
                                  _showPostAnalytics(
                                    context,
                                    post,
                                    langMain,
                                    isDark,
                                    backgroundColor,
                                    textColor,
                                    accentColor,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                langMain == 'tr' ? 'Kapat' : 'Close',
                style: TextStyle(color: accentColor),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Try to close loading dialog safely if it's open
      try {
        if (!isDialogDismissed) {
          navigator.pop();
        }
      } catch (_) {
        // Navigator might already be popped
      }

      print("Error viewing post statistics: $e");

      // Only show snackbar if context is still valid
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              langMain == 'tr'
                  ? 'İstatistikler alınırken bir hata oluştu'
                  : 'An error occurred while getting statistics',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to build a stat box widget
  Widget _buildStatBox(
      String value, String label, IconData icon, Color textColor) {
    return Column(
      children: [
        Icon(icon, color: textColor.withOpacity(0.7), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Helper to build engagement indicator
  Widget _buildEngagementIndicator(double rate, bool isDark, Color textColor) {
    // Determine color based on engagement rate
    Color indicatorColor;
    String performanceText;

    if (rate >= 3.0) {
      indicatorColor = Colors.green;
      performanceText = 'Excellent';
    } else if (rate >= 1.5) {
      indicatorColor = Colors.amber;
      performanceText = 'Good';
    } else if (rate >= 0.5) {
      indicatorColor = Colors.orange;
      performanceText = 'Average';
    } else {
      indicatorColor = Colors.red;
      performanceText = 'Below Average';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: (rate > 5 ? 100 : rate * 20).clamp(0, 100) / 100 * 300,
              height: 8,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Text(
                performanceText,
                style: TextStyle(
                  color: indicatorColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '0%',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
              const Spacer(flex: 4),
              Text(
                '5%',
                style: TextStyle(
                  color: textColor.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Method to show analytics for a specific post
  void _showPostAnalytics(
    BuildContext context,
    Map<String, dynamic> post,
    String langMain,
    bool isDark,
    Color backgroundColor,
    Color textColor,
    Color accentColor,
  ) {
    final timestamp = post['timestamp'] as Timestamp;
    final postDate = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(postDate);

    // Days since posting
    final daysSincePosting = difference.inDays;

    // Calculate likes per day
    final likesPerDay = daysSincePosting > 0
        ? (post['likes'] as int) / daysSincePosting
        : post['likes'] as int;

    // Calculate comments per day
    final commentsPerDay = daysSincePosting > 0
        ? (post['comments'] as int) / daysSincePosting
        : post['comments'] as int;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text(
          langMain == 'tr' ? 'Gönderi Analizi' : 'Post Analysis',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black12 : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['photoURL'] != null &&
                      post['photoURL'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post['photoURL'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, s) => Container(
                          width: 60,
                          height: 60,
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
                          child: Icon(Icons.broken_image,
                              color: textColor.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['message'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(postDate, langMain),
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Engagement metrics
            _buildMetricRow(
              langMain == 'tr' ? 'Toplam Beğeniler' : 'Total Likes',
              post['likes'].toString(),
              Icons.favorite,
              Colors.red,
              textColor,
            ),

            _buildMetricRow(
              langMain == 'tr' ? 'Toplam Yorumlar' : 'Total Comments',
              post['comments'].toString(),
              Icons.comment,
              accentColor,
              textColor,
            ),

            _buildMetricRow(
              langMain == 'tr' ? 'Yaş (gün)' : 'Age (days)',
              daysSincePosting.toString(),
              Icons.calendar_today,
              textColor.withOpacity(0.7),
              textColor,
            ),

            _buildMetricRow(
              langMain == 'tr' ? 'Günlük Beğeni' : 'Likes per Day',
              likesPerDay.toStringAsFixed(1),
              Icons.trending_up,
              likesPerDay >= 1 ? Colors.green : Colors.orange,
              textColor,
            ),

            _buildMetricRow(
              langMain == 'tr' ? 'Günlük Yorum' : 'Comments per Day',
              commentsPerDay.toStringAsFixed(1),
              Icons.trending_up,
              commentsPerDay >= 0.5 ? Colors.green : Colors.orange,
              textColor,
            ),

            const SizedBox(height: 16),

            // Performance assessment
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langMain == 'tr'
                        ? 'Performans Değerlendirmesi'
                        : 'Performance Assessment',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getPerformanceText(post['likes'] as int,
                        post['comments'] as int, daysSincePosting, langMain),
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              langMain == 'tr' ? 'Kapat' : 'Close',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build metric row
  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get performance text
  String _getPerformanceText(
      int likes, int comments, int days, String langMain) {
    final totalEngagement = likes + comments;

    if (days == 0) days = 1;
    final engagementPerDay = totalEngagement / days;

    if (engagementPerDay >= 5) {
      return langMain == 'tr'
          ? 'Bu gönderi ortalamanın üzerinde performans gösteriyor. Benzer içerikler paylaşmayı düşünebilirsiniz.'
          : 'This post is performing above average. Consider posting similar content.';
    } else if (engagementPerDay >= 2) {
      return langMain == 'tr'
          ? 'Bu gönderi iyi performans gösteriyor. İçeriğin neden iyi çalıştığını analiz edin.'
          : 'This post is performing well. Analyze why this content is working.';
    } else if (engagementPerDay >= 1) {
      return langMain == 'tr'
          ? 'Bu gönderi ortalama performans gösteriyor. Daha fazla etkileşim için içeriği iyileştirmeyi düşünebilirsiniz.'
          : 'This post is showing average performance. Consider enhancing the content for more engagement.';
    } else {
      return langMain == 'tr'
          ? 'Bu gönderi ortalama altında performans gösteriyor. Farklı içerik türleri denemeyi düşünün.'
          : 'This post is performing below average. Consider trying different types of content.';
    }
  }

  // Helper to format date
  String _formatDate(DateTime date, String langMain) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }
} // This is the end of the ProfileScreenController class

// Move provider declarations out of the class scope and into the file scope
final selectedEmojiProvider = StateProvider<String>((ref) => "🍸");
final refreshingProvider = StateProvider<bool>((ref) => false);
final showArchivedProvider = StateProvider<bool>((ref) => false);
final tabIndexProvider = StateProvider<int>((ref) => 0);
final profileImageFileProvider = StateProvider<File?>((ref) => null);

// Additional providers for new features
final scheduledPostsProvider = StateProvider<bool>((ref) => false);
final profileThemeProvider = StateProvider<String>((ref) => 'Default');
final boldFontStyleProvider = StateProvider<bool>((ref) => false);
final headerImageProvider = StateProvider<String?>((ref) => null);
