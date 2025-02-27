import 'package:bartender/S/mainPart/homeScreen/homeScreenState.dart';
import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenController.dart';
import 'dart:io'; // added for File
import 'package:image_picker/image_picker.dart'; // added for image picking
import 'package:firebase_storage/firebase_storage.dart'; // added for storage upload

class HomeScreenMain extends ConsumerStatefulWidget {
  const HomeScreenMain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenMainState();
}

class _HomeScreenMainState extends ConsumerState<HomeScreenMain> {
  final HomeScreenController _controller = HomeScreenController();
  File? _selectedImage; // new variable for selected image
  bool _isUploading = false; // new variable for upload status

  // Update _pickImage to accept ImageSource and check file size
  Future<void> _pickImage(ImageSource source) async {
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
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // Update _showImageSourceActionSheet to accept a setState callback from the dialog
  Future<void> _showImageSourceActionSheet(
      void Function(void Function()) dialogSetState) async {
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
      await _pickImage(source);
      dialogSetState(() {}); // refresh dialog after picking image
    }
  }

  void _navigateToProfile(BuildContext context, String userId) {
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

  // New method to build post card widget
  Widget _buildPostCard(dynamic post) {
    final postData = post.data() as Map<String, dynamic>?;
    if (postData == null) return SizedBox.shrink();
    final darkThemeMain = ref.watch(darkTheme);
    final isLiked = ref.watch(likeProvider(post.id));
    final likeCount = ref.watch(likeProvider(post.id).notifier).likeCount;
    // Get current user for checking profile id
    final currentUser = FirebaseAuth.instance.currentUser;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      elevation: 5,
      child: Column(
        children: [
          // Post header
          ListTile(
            leading: GestureDetector(
              onTap: () {
                if (currentUser != null &&
                    currentUser.uid == postData['userId']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'You cannot view your own profile'), // alert text
                    ),
                  );
                } else {
                  _navigateToProfile(context, postData['userId']);
                }
              },
              child: CircleAvatar(
                backgroundImage: NetworkImage(
                  postData['userPhotoURL'] ?? 'https://picsum.photos/200',
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                if (currentUser != null &&
                    currentUser.uid == postData['userId']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'You cannot view your own profile'), // alert text
                    ),
                  );
                } else {
                  _navigateToProfile(context, postData['userId']);
                }
              },
              child: Text(
                postData['message'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            subtitle: Text(
              'Updated by: ${postData['userName'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              _controller.formatTimestamp(postData['timestamp']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // New: Display photo if available
          if (postData['photoURL'] != null &&
              (postData['photoURL'] as String).trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.network(
                postData['photoURL'],
                fit: BoxFit.cover,
              ),
            ),
          // Post actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.thumb_up),
                      color: isLiked ? Colors.blue : Colors.grey,
                      onPressed: () =>
                          ref.read(likeProvider(post.id).notifier).toggleLike(),
                    ),
                    Text('$likeCount likes'),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.comment),
                  color: Colors.grey,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsPage(tweetId: post.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // New method to show the new post dialog
  void _showNewPostDialog(bool darkThemeMain, String langMain) {
    showDialog(
      context: context,
      builder: (context) {
        final _textController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              title: Text(
                langMain == "tr" ? 'Yeni Gönderi' : 'New Post',
                style: TextStyle(
                  color: darkThemeMain ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: langMain == "tr"
                          ? 'Neler oluyor?'
                          : 'What\'s happening?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                  // New: Wrap image preview with a GestureDetector to show full image on tap
                  if (_selectedImage != null)
                    GestureDetector(
                      onTap: _showFullImage,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          height: 150,
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  // Updated: pass dialog's setState so image preview refreshes upon selection
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showImageSourceActionSheet(setDialogState),
                    icon: const Icon(Icons.photo_library),
                    label: Text(
                      langMain == "tr" ? 'Fotoğraf Seç' : 'Select Photo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkThemeMain
                          ? Colors.orangeAccent
                          : Colors.deepOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                  if (_isUploading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _selectedImage = null;
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    langMain == "tr" ? 'İptal' : 'Cancel',
                    style: TextStyle(
                      color: darkThemeMain
                          ? Colors.orangeAccent
                          : Colors.deepOrange,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // New: Alert if trying to send only a photo without text
                    if (_textController.text.trim().isEmpty) {
                      if (_selectedImage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(langMain == "tr"
                                ? 'Sadece fotoğraf gönderemezsiniz'
                                : 'Cannot send photo only'),
                          ),
                        );
                        return;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(langMain == "tr"
                                ? 'Lütfen içerik giriniz'
                                : 'Please enter some text'),
                          ),
                        );
                        return;
                      }
                    }
                    if (!_isUploading) {
                      setDialogState(() {
                        _isUploading = true;
                      });
                      String photoURL = '';
                      if (_selectedImage != null) {
                        try {
                          final storageRef = FirebaseStorage.instance.ref().child(
                              'tweet_photos/${DateTime.now().millisecondsSinceEpoch}.png');
                          final uploadTask =
                              storageRef.putFile(_selectedImage!);
                          final snapshot = await uploadTask.whenComplete(() {});
                          photoURL = await snapshot.ref.getDownloadURL();
                          print('Image upload successful: $photoURL');
                        } catch (e) {
                          print('Error uploading image: $e');
                          photoURL = '';
                        }
                      }
                      final userId = FirebaseAuth.instance.currentUser?.uid;
                      final userName =
                          FirebaseAuth.instance.currentUser?.displayName;
                      final userPhotoURL =
                          FirebaseAuth.instance.currentUser?.photoURL;
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
                        _selectedImage = null;
                        Navigator.of(context).pop();
                        ref.refresh(sortedTweetsProvider);
                      }
                      setDialogState(() {
                        _isUploading = false;
                      });
                    }
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
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // New method to show the full selected image in a dialog
  void _showFullImage() {
    if (_selectedImage == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black,
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final sortedTweetsAsyncValue = ref.watch(sortedTweetsProvider);

    return Scaffold(
      body: SafeArea(
        child: sortedTweetsAsyncValue.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Center(
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(seconds: 2),
                  child: Text(
                    langMain == "tr"
                        ? 'Kimseyi takip etmiyorsunuz.'
                        : 'You are not following anyone.',
                    style: TextStyle(
                      fontSize: 18,
                      color: darkThemeMain ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.refresh(sortedTweetsProvider);
              },
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return _buildPostCard(post);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
        onPressed: () => _showNewPostDialog(darkThemeMain, langMain),
        child: const Icon(Icons.add, color: Colors.white),
        mini: true,
      ),
    );
  }
}
