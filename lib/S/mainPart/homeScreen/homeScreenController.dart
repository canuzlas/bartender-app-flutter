import 'dart:io';

import 'package:bartender/S/mainPart/homeScreen/homeScreenState.dart';
import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:bartender/mainSettings.dart';

class HomeScreenController {
  final FirebaseAuth auth = FirebaseAuth.instance;

  String formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  void navigateToProfile(BuildContext context, String userId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == userId) {
      Navigator.pushNamed(context, '/botNavigation');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OtherUserProfileScreen(userId: userId),
        ),
      );
    }
  }

  // Update _pickImage to use newPostProvider
  Future<void> _pickImage(ImageSource source, context, ref) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024; // 10MB
        if (fileSize > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Selected image exceeds 10MB limit')));
          return;
        }
        ref.read(newPostProvider.notifier).setSelectedImage(file);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // Remove dialogSetState callback; simply call _pickImage after modal selection.
  Future<void> _showImageSourceActionSheet(context, ref) async {
    final isDarkTheme = ref.read(darkTheme.notifier).state;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkTheme ? const Color(0xFF252525) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDarkTheme ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: isDarkTheme
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: Text(
                'Gallery',
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, context, ref);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: isDarkTheme
                    ? Colors.green.withOpacity(0.2)
                    : Colors.green.withOpacity(0.1),
                child: const Icon(Icons.camera_alt, color: Colors.green),
              ),
              title: Text(
                'Camera',
                style: TextStyle(
                  color: isDarkTheme ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, context, ref);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Build new post dialog without StatefulBuilder, using provider state.
  void showNewPostDialog(bool darkThemeMain, String langMain, context, ref) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        backgroundColor: darkThemeMain ? const Color(0xFF252525) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    langMain == "tr" ? 'Yeni Gönderi' : 'New Post',
                    style: TextStyle(
                      color: darkThemeMain ? Colors.white : Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: darkThemeMain ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      ref.read(newPostProvider.notifier).reset();
                      Navigator.of(context).pop();
                    },
                  )
                ],
              ),
              const SizedBox(height: 16),
              Consumer(builder: (context, ref, child) {
                final newPostState = ref.watch(newPostProvider);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: darkThemeMain
                            ? const Color(0xFF303030)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: darkThemeMain
                              ? Colors.grey[700]!
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: TextField(
                        controller: textController,
                        maxLines: 5,
                        style: TextStyle(
                          color: darkThemeMain ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: langMain == "tr"
                              ? 'Neler oluyor?'
                              : 'What\'s happening?',
                          hintStyle: TextStyle(
                            color: darkThemeMain
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (newPostState.selectedImage != null)
                      GestureDetector(
                        onTap: () => _showFullImage(context, ref),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: darkThemeMain
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              newPostState.selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showImageSourceActionSheet(context, ref),
                            icon: const Icon(Icons.photo_library),
                            label: Text(
                              langMain == "tr" ? 'Fotoğraf Seç' : 'Add Photo',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  darkThemeMain ? Colors.white : Colors.black87,
                              side: BorderSide(
                                color: darkThemeMain
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (textController.text.trim().isEmpty) {
                                if (ref.read(newPostProvider).selectedImage !=
                                    null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        langMain == "tr"
                                            ? 'Sadece fotoğraf gönderemezsiniz'
                                            : 'Cannot send photo only',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        langMain == "tr"
                                            ? 'Lütfen içerik giriniz'
                                            : 'Please enter some text',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                              }
                              final notifier =
                                  ref.read(newPostProvider.notifier);
                              notifier.setUploading(true);
                              // Rest of your existing upload logic...
                              String photoURL = '';
                              if (newPostState.selectedImage != null) {
                                try {
                                  final storageRef = FirebaseStorage.instance
                                      .ref()
                                      .child(
                                          'tweet_photos/${DateTime.now().millisecondsSinceEpoch}.png');
                                  final uploadTask = storageRef
                                      .putFile(newPostState.selectedImage!);
                                  final snapshot =
                                      await uploadTask.whenComplete(() {});
                                  photoURL =
                                      await snapshot.ref.getDownloadURL();
                                  print('Image upload successful: $photoURL');
                                } catch (e) {
                                  print('Error uploading image: $e');
                                }
                              }

                              final userId =
                                  FirebaseAuth.instance.currentUser?.uid;

                              if (userId != null) {
                                try {
                                  // Fetch the current user data from Firestore users collection
                                  final userDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(userId)
                                      .get();

                                  if (userDoc.exists) {
                                    // Use user data from Firestore
                                    final userData = userDoc.data()!;

                                    FirebaseFirestore.instance
                                        .collection('tweets')
                                        .add({
                                      'userId': userId,
                                      'userName': userData['displayname'] ??
                                          'Unknown User',
                                      'userPhotoURL':
                                          userData['photoURL'] ?? '',
                                      'message': textController.text,
                                      'timestamp': Timestamp.now(),
                                      'likedBy': [],
                                      'photoURL': photoURL,
                                    });
                                  } else {
                                    // Fallback to FirebaseAuth data if user document doesn't exist
                                    final userName = FirebaseAuth
                                        .instance.currentUser?.displayName;
                                    final userPhotoURL = FirebaseAuth
                                        .instance.currentUser?.photoURL;

                                    FirebaseFirestore.instance
                                        .collection('tweets')
                                        .add({
                                      'userId': userId,
                                      'userName': userName ?? 'Unknown User',
                                      'userPhotoURL': userPhotoURL ?? '',
                                      'message': textController.text,
                                      'timestamp': Timestamp.now(),
                                      'likedBy': [],
                                      'photoURL': photoURL,
                                    });
                                  }

                                  notifier.reset();
                                  Navigator.of(context).pop();
                                  ref.refresh(sortedTweetsProvider);
                                } catch (e) {
                                  print('Error fetching user data: $e');
                                  // Handle the error, possibly show error message to user
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(langMain == "tr"
                                          ? 'Gönderi yayınlanırken bir hata oluştu'
                                          : 'Error publishing post'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                              notifier.setUploading(false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: darkThemeMain
                                  ? Colors.orangeAccent
                                  : Colors.deepOrange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              langMain == "tr" ? 'Gönder' : 'Post',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (newPostState.isUploading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  darkThemeMain
                                      ? Colors.orangeAccent
                                      : Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                langMain == "tr"
                                    ? 'Yükleniyor...'
                                    : 'Uploading...',
                                style: TextStyle(
                                  color: darkThemeMain
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Show full image using provider state (unchanged)
  void _showFullImage(context, ref) {
    final newPostState = ref.read(newPostProvider);
    if (newPostState.selectedImage == null) return;

    final isDarkTheme = ref.read(darkTheme.notifier).state;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.file(
                  newPostState.selectedImage!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 16,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to show full screen image view
  void showFullScreenImage(
      BuildContext context, String imageUrl, bool darkTheme) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Method to share post content
  void sharePost(BuildContext context, Map<String, dynamic> postData) {
    // Placeholder for share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sharing functionality would go here'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
