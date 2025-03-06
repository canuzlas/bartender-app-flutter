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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected image exceeds 10MB limit')));
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
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _pickImage(source, context, ref);
    }
  }

  // Build new post dialog without StatefulBuilder, using provider state.
  void showNewPostDialog(bool darkThemeMain, String langMain, context, ref) {
    final _textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        title: Text(
          langMain == "tr" ? 'Yeni Gönderi' : 'New Post',
          style: TextStyle(color: darkThemeMain ? Colors.white : Colors.black),
        ),
        content: Consumer(builder: (context, ref, child) {
          final newPostState = ref.watch(newPostProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _textController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      langMain == "tr" ? 'Neler oluyor?' : 'What\'s happening?',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              if (newPostState.selectedImage != null)
                GestureDetector(
                  onTap: () => _showFullImage(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      height: 150,
                      child: Image.file(newPostState.selectedImage!,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _showImageSourceActionSheet(context, ref),
                icon: const Icon(Icons.photo_library),
                label: Text(
                  langMain == "tr" ? 'Fotoğraf Seç' : 'Select Photo',
                  style: TextStyle(
                      color: darkThemeMain ? Colors.black : Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkThemeMain ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
              if (newPostState.isUploading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(),
                ),
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(newPostProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: Text(
              langMain == "tr" ? 'İptal' : 'Cancel',
              style: TextStyle(
                  color:
                      darkThemeMain ? Colors.orangeAccent : Colors.deepOrange),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (_textController.text.trim().isEmpty) {
                if (ref.read(newPostProvider).selectedImage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        langMain == "tr"
                            ? 'Sadece fotoğraf gönderemezsiniz'
                            : 'Cannot send photo only',
                      ),
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
                    ),
                  );
                  return;
                }
              }
              final notifier = ref.read(newPostProvider.notifier);
              notifier.setUploading(true);
              String photoURL = '';
              final newPostState = ref.read(newPostProvider);
              if (newPostState.selectedImage != null) {
                try {
                  final storageRef = FirebaseStorage.instance.ref().child(
                      'tweet_photos/${DateTime.now().millisecondsSinceEpoch}.png');
                  final uploadTask =
                      storageRef.putFile(newPostState.selectedImage!);
                  final snapshot = await uploadTask.whenComplete(() {});
                  photoURL = await snapshot.ref.getDownloadURL();
                  print('Image upload successful: $photoURL');
                } catch (e) {
                  print('Error uploading image: $e');
                }
              }
              final userId = FirebaseAuth.instance.currentUser?.uid;
              final userName = FirebaseAuth.instance.currentUser?.displayName;
              final userPhotoURL = FirebaseAuth.instance.currentUser?.photoURL;
              if (userId != null && userName != null) {
                FirebaseFirestore.instance.collection('tweets').add({
                  'userId': userId,
                  'userName': userName,
                  'userPhotoURL': userPhotoURL,
                  'message': _textController.text,
                  'timestamp': Timestamp.now(),
                  'likedBy': [],
                  'photoURL': photoURL,
                });
                notifier.reset();
                Navigator.of(context).pop();
                ref.refresh(sortedTweetsProvider);
              }
              notifier.setUploading(false);
            },
            icon: const Icon(Icons.send, color: Colors.white),
            label: Text(
              langMain == "tr" ? 'Gönder' : 'Post',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
        ],
      ),
    );
  }

  // Show full image using provider state (unchanged)
  void _showFullImage(context, ref) {
    final newPostState = ref.read(newPostProvider);
    if (newPostState.selectedImage == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            child: Image.file(newPostState.selectedImage!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
