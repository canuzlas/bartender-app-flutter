import 'package:bartender/S/mainPart/profileScreen/profileScreenController.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bartender/mainSettings.dart';
import 'package:bartender/S/mainPart/storyWidget/storyViewerWidget.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StoryBarWidget extends ConsumerStatefulWidget {
  const StoryBarWidget({super.key});

  @override
  _StoryBarWidgetState createState() => _StoryBarWidgetState();
}

class _StoryBarWidgetState extends ConsumerState<StoryBarWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final language = ref.watch(lang);
    final refreshState = ref.watch(refreshingProvider); // For refreshing

    final primaryColor =
        darkThemeMain ? Colors.orangeAccent : Colors.deepOrange;
    final textColor = darkThemeMain ? Colors.white : Colors.black;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stories = snapshot.data?.docs ?? [];

          // Group stories by user
          final Map<String, List<QueryDocumentSnapshot>> userStories = {};
          for (var story in stories) {
            final Map<String, dynamic> data =
                story.data() as Map<String, dynamic>;
            final String userId = data['userId'] as String? ?? '';

            if (userId.isNotEmpty) {
              if (!userStories.containsKey(userId)) {
                userStories[userId] = [];
              }
              userStories[userId]!.add(story);
            }
          }

          if (userStories.isEmpty) {
            return ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Still show the create story option
                _buildCreateStoryItem(
                    darkThemeMain, textColor, language, primaryColor),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      language == 'tr' ? 'Hikaye yok' : 'No stories',
                      style: TextStyle(color: textColor.withOpacity(0.6)),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Your Story / Create Story item
              _buildCreateStoryItem(
                  darkThemeMain, textColor, language, primaryColor),

              // Other users' stories
              ...userStories.entries.map((entry) {
                final userId = entry.key;
                final userStoriesList = entry.value;

                // Skip current user as it's already shown as "My Story"
                if (userId == _auth.currentUser?.uid) {
                  return const SizedBox.shrink();
                }

                // Get the most recent story for display
                final latestStory =
                    userStoriesList.first.data() as Map<String, dynamic>;
                final bool hasUnviewed = userStoriesList.any((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final List<dynamic> viewedBy =
                      data['viewedBy'] as List<dynamic>? ?? [];
                  return !viewedBy.contains(_auth.currentUser?.uid);
                });

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get(),
                  builder: (context, userSnapshot) {
                    String userName = 'User';
                    String userPhotoURL = 'https://picsum.photos/100';

                    if (userSnapshot.hasData && userSnapshot.data != null) {
                      final userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      userName = userData?['displayname'] ?? 'User';
                      userPhotoURL =
                          userData?['photoURL'] ?? 'https://picsum.photos/100';
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _viewUserStories(
                                userStoriesList, userName, userPhotoURL),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      hasUnviewed ? primaryColor : Colors.grey,
                                  width: hasUnviewed ? 2 : 1,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(userPhotoURL),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName.length > 8
                                ? '${userName.substring(0, 8)}...'
                                : userName,
                            style: TextStyle(fontSize: 12, color: textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCreateStoryItem(
      bool darkTheme, Color textColor, String language, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              // Simply show bottom options instead of using tapDown position
              _checkForUserStories().then((hasStories) {
                _showStoryOptionsSnackBar(hasExistingStories: hasStories);
              });
            },
            child: Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: darkTheme ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(
                        _auth.currentUser?.photoURL ??
                            'https://picsum.photos/100',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: darkTheme ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            language == 'tr' ? 'Hikayem' : 'My Story',
            style: TextStyle(fontSize: 12, color: textColor),
          ),
        ],
      ),
    );
  }

  // Add helper method to check if user has active stories
  Future<bool> _checkForUserStories() async {
    if (_auth.currentUser == null) return false;

    try {
      // Check if the current user has any active stories
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .limit(1) // Only need one to confirm existence
          .get();

      return storiesSnapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error checking for user stories: $e");
      return false;
    }
  }

  Future<void> _pickStoryMedia({required bool isCamera}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        // Reduce image quality for smaller file size
        imageQuality: 50,
        // Limit the maximum width and height to reduce file size
        maxWidth: 1080,
        maxHeight: 1350,
      );

      if (pickedFile == null) {
        if (mounted) {
          // Check if widget is still mounted
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  ref.watch(lang) == 'tr' ? 'İptal edildi' : 'Cancelled')));
        }
        return;
      }

      setState(() {
        _isUploading = true;
      });

      // Upload to Firebase Storage
      final File imageFile = File(pickedFile.path);
      final String fileName = const Uuid().v4();
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child('${_auth.currentUser!.uid}')
          .child('$fileName.jpg');

      // Set metadata to further compress the image with JPEG format
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': pickedFile.path},
      );

      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);

      // Listen for possible errors during upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.state == TaskState.error) {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ref.watch(lang) == 'tr'
                  ? 'Yükleme başarısız oldu: Dosya boyutu çok büyük'
                  : 'Upload failed: File size too large'),
              backgroundColor: Colors.red,
            ));
          }
        }
      }, onError: (error) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref.watch(lang) == 'tr'
                ? 'Yükleme hatası: Dosya boyutu çok büyük olabilir'
                : 'Upload error: File size might be too large'),
            backgroundColor: Colors.red,
          ));
        }
      });

      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Create story document in Firestore
      final now = Timestamp.now();
      final expiresAt =
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));

      // Use a trimmed description to prevent document size issues
      await FirebaseFirestore.instance.collection('stories').add({
        'userId': _auth.currentUser!.uid,
        'userPhotoURL': _auth.currentUser!.photoURL,
        'userName': _auth.currentUser!.displayName,
        'media': downloadUrl,
        'description': '', // Empty description to save space
        'timestamp': now,
        'expiresAt': expiresAt,
        'viewedBy': [],
        'likedBy': [],
      });

      if (!mounted)
        return; // Check if widget is still mounted before continuing

      setState(() {
        _isUploading = false;
      });

      // Update state to show the new story
      ref.read(refreshingProvider.notifier).update((state) => !state);

      // Show success message with View button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ref.watch(lang) == 'tr' ? 'Hikaye paylaşıldı' : 'Story shared'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: ref.watch(lang) == 'tr' ? 'Görüntüle' : 'View',
            textColor: Colors.white,
            onPressed: () {
              _viewCurrentUserStories();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted)
        return; // Check if widget is still mounted before continuing

      setState(() {
        _isUploading = false;
      });

      // Check for specific Firebase error messages
      String errorMessage = e.toString();
      if (errorMessage.contains('message too long') ||
          errorMessage.contains('payload') ||
          errorMessage.contains('size')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ref.watch(lang) == 'tr'
              ? 'Dosya boyutu çok büyük. Lütfen daha küçük bir resim seçin.'
              : 'File size too large. Please choose a smaller image.'),
          backgroundColor: Colors.red,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _createTextStory() {
    final TextEditingController textController = TextEditingController();
    final bool isDarkTheme = ref.read(darkTheme);
    final String currentLang =
        ref.read(lang); // Use read instead of watch to safely capture value

    if (!mounted) return; // Safety check

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          currentLang == 'tr' ? 'Metin Hikayesi Oluştur' : 'Create Text Story',
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: textController,
          maxLines: 5,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: currentLang == 'tr'
                ? 'Hikayenizi yazın...'
                : 'Write your story...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDarkTheme ? Colors.black54 : Colors.grey[100],
          ),
          style: TextStyle(
            color: isDarkTheme ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              currentLang == 'tr' ? 'İptal' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) {
                return;
              }

              Navigator.pop(dialogContext);

              try {
                if (!mounted)
                  return; // Check if still mounted before updating state

                setState(() {
                  _isUploading = true;
                });

                // Create text story document in Firestore
                final now = Timestamp.now();
                final expiresAt = Timestamp.fromDate(
                    DateTime.now().add(const Duration(hours: 24)));

                await FirebaseFirestore.instance.collection('stories').add({
                  'userId': _auth.currentUser!.uid,
                  'userPhotoURL': _auth.currentUser!.photoURL,
                  'userName': _auth.currentUser!.displayName,
                  'media': null,
                  'description': textController.text.trim(),
                  'timestamp': now,
                  'expiresAt': expiresAt,
                  'viewedBy': [],
                  'likedBy': [],
                });

                if (!mounted) return; // Check again after async operation

                setState(() {
                  _isUploading = false;
                });

                // Update state to show the new story
                ref.read(refreshingProvider.notifier).update((state) => !state);

                // Show success message if still mounted
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(currentLang == 'tr'
                          ? 'Metin hikayesi paylaşıldı'
                          : 'Text story shared'),
                      backgroundColor: Colors.green,
                      action: SnackBarAction(
                        label: currentLang == 'tr' ? 'Görüntüle' : 'View',
                        textColor: Colors.white,
                        onPressed: () {
                          _viewCurrentUserStories();
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                // Check if still mounted before showing error
                if (mounted) {
                  setState(() {
                    _isUploading = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDarkTheme ? Colors.orangeAccent : Colors.deepOrange,
            ),
            child: Text(currentLang == 'tr' ? 'Paylaş' : 'Share'),
          ),
        ],
      ),
    );
  }

  void _viewUserStories(
      List<QueryDocumentSnapshot> stories, String userName, String userImage) {
    List<Map<String, dynamic>> storyItems = [];

    for (var story in stories) {
      Map<String, dynamic> storyData = story.data() as Map<String, dynamic>;
      storyItems.add({
        'id': story.id,
        'media': storyData['media'],
        'description': storyData['description'] ?? '',
        'timestamp': storyData['timestamp'],
        'userId': storyData['userId'],
        'viewedBy': storyData['viewedBy'] ?? [],
        'likedBy': storyData['likedBy'] ?? [],
      });
    }

    if (storyItems.isEmpty) return;

    // Use Navigator.push for better fullscreen experience
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) => StoryViewerWidget(
          stories: storyItems,
          userName: userName,
          userImage: userImage,
          onClose: () {
            // Don't navigate here, just handle any state changes if needed
            // Navigation is handled by the StoryViewerWidget
          },
          onLike: (String storyId, bool isLiked) {
            // Handle like without closing story
            _handleStoryLike(storyId, isLiked);
          },
          onSendMessage: (String storyId, String message) {
            // Handle sending message without closing story
            _handleSendMessage(storyId, message);
          },
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // Add a new method to handle story likes
  void _handleStoryLike(String storyId, bool isLiked) async {
    try {
      final String currentUserId = _auth.currentUser?.uid ?? '';
      if (currentUserId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .update({
        'likedBy': isLiked
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId])
      });
    } catch (e) {
      if (!mounted) return;

      print('Error updating story like: ${e.toString()}');
    }
  }

  // Fix implementation of the message handling method
  void _handleSendMessage(String storyId, String message) async {
    if (message.trim().isEmpty) return;

    try {
      final String currentUserId = _auth.currentUser?.uid ?? '';
      final String? currentUserName = _auth.currentUser?.displayName;
      final String? currentUserPhotoURL = _auth.currentUser?.photoURL;

      if (currentUserId.isEmpty) return;

      // Get the story to find the recipient user
      final storyDoc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .get();

      if (!storyDoc.exists) return;

      final storyData = storyDoc.data() as Map<String, dynamic>;
      final String recipientId = storyData['userId'] as String? ?? '';

      if (recipientId.isEmpty || recipientId == currentUserId) return;

      // Create messages using the new schema
      final senderMessage = {
        'senderId': currentUserId.toString(),
        'recipientId': recipientId.toString(),
        'content': message.trim(),
        'timestamp': Timestamp.now(),
        'isRead': false,
        'isSent': true,
        'isStoryReply': true,
        'storyId': storyId,
      };

      final recipientMessage = {
        'senderId': currentUserId.toString(),
        'recipientId': recipientId.toString(),
        'content': message.trim(),
        'timestamp': Timestamp.now(),
        'isRead': false,
        'isSent': true,
        'isStoryReply': true,
        'storyId': storyId,
      };

      final conversationIdSender = "$currentUserId-$recipientId";
      final conversationIdRecipient = "$recipientId-$currentUserId";
      final conversationRefSender = FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationIdSender);
      final conversationRefRecipient = FirebaseFirestore.instance
          .collection('messages')
          .doc(conversationIdRecipient);

      // Save sender's message
      final senderSnap = await conversationRefSender.get();
      if (senderSnap.exists) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final freshSnap = await transaction.get(conversationRefSender);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([senderMessage]),
            'lastMessage': senderMessage['content'],
            'timestamp': senderMessage['timestamp'],
          });
        });
      } else {
        await conversationRefSender.set({
          'senderId': currentUserId,
          'recipientId': recipientId,
          'messages': [senderMessage],
          'lastMessage': senderMessage['content'],
          'timestamp': senderMessage['timestamp'],
          'participants': [currentUserId, recipientId],
        });
      }

      // Save recipient's message
      final recipientSnap = await conversationRefRecipient.get();
      if (recipientSnap.exists) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final freshSnap = await transaction.get(conversationRefRecipient);
          transaction.update(freshSnap.reference, {
            'messages': FieldValue.arrayUnion([recipientMessage]),
            'lastMessage': recipientMessage['content'],
            'timestamp': recipientMessage['timestamp'],
          });
        });
      } else {
        await conversationRefRecipient.set({
          'senderId': recipientId,
          'recipientId': currentUserId,
          'messages': [recipientMessage],
          'lastMessage': recipientMessage['content'],
          'timestamp': recipientMessage['timestamp'],
          'participants': [recipientId, currentUserId],
        });
      }

      if (!mounted) return;

      // Show success indicator without closing story
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ref.watch(lang) == 'tr' ? 'Mesaj gönderildi' : 'Message sent'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      print('Error sending message: ${e.toString()}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.watch(lang) == 'tr'
              ? 'Mesaj gönderilemedi'
              : 'Failed to send message'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add a new method to view current user's stories
  void _viewCurrentUserStories() async {
    if (_auth.currentUser == null) return;

    try {
      // Fetch current user's stories that haven't expired
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: true)
          .get();

      if (storiesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.watch(lang) == 'tr'
                  ? 'Aktif hikayeniz bulunmuyor'
                  : 'You have no active stories'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      List<Map<String, dynamic>> storyItems = [];

      for (var story in storiesSnapshot.docs) {
        Map<String, dynamic> storyData = story.data();
        storyItems.add({
          'id': story.id,
          'media': storyData['media'],
          'description': storyData['description'] ?? '',
          'timestamp': storyData['timestamp'],
          'userId': storyData['userId'],
          'viewedBy': storyData['viewedBy'] ?? [],
          'likedBy': storyData['likedBy'] ?? [],
        });
      }

      // Get current user's name and photo
      String userName = _auth.currentUser!.displayName ?? 'You';
      String userImage =
          _auth.currentUser!.photoURL ?? 'https://picsum.photos/100';

      // Use same story viewer but with current user's info
      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => StoryViewerWidget(
              stories: storyItems,
              userName: userName,
              userImage: userImage,
              onClose: () {
                // Don't navigate here, just handle any state changes if needed
                // Navigation is handled by the StoryViewerWidget
              },
              onLike: (String storyId, bool isLiked) {
                _handleStoryLike(storyId, isLiked);
              },
              onSendMessage: (String storyId, String message) {
                _handleSendMessage(storyId, message);
              },
            ),
            transitionsBuilder: (context, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New method to show story options as a bottom SnackBar
  void _showStoryOptionsSnackBar({bool hasExistingStories = false}) {
    final isDarkTheme = ref.read(darkTheme);
    final language = ref.read(lang);
    final primaryColor = isDarkTheme ? Colors.orangeAccent : Colors.deepOrange;
    final backgroundColor =
        isDarkTheme ? const Color(0xFF212121) : Colors.white;
    final textColor = isDarkTheme ? Colors.white : Colors.black87;

    // Hide any existing SnackBars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 6),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull indicator
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12.0),
                decoration: BoxDecoration(
                  color: isDarkTheme ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_stories,
                      color: primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      language == 'tr' ? 'Hikaye Oluştur' : 'Create Story',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              // Replace the previous ListView with a Row that's centered
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStoryOptionButton(
                      icon: Icons.camera_alt,
                      label: language == 'tr' ? 'Kamera' : 'Camera',
                      color: Colors.purple,
                      isDarkTheme: isDarkTheme,
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        // Show upload starting SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(language == 'tr'
                              ? 'Hikaye yükleniyor...'
                              : 'Uploading story...'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blue,
                        ));
                        _pickStoryMedia(isCamera: true);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildStoryOptionButton(
                      icon: Icons.photo_library,
                      label: language == 'tr' ? 'Galeri' : 'Gallery',
                      color: Colors.blue,
                      isDarkTheme: isDarkTheme,
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        // Show upload starting SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(language == 'tr'
                              ? 'Hikaye yükleniyor...'
                              : 'Uploading story...'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blue,
                        ));
                        _pickStoryMedia(isCamera: false);
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildStoryOptionButton(
                      icon: Icons.text_fields,
                      label: language == 'tr' ? 'Metin' : 'Text',
                      color: Colors.green,
                      isDarkTheme: isDarkTheme,
                      onTap: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(language == 'tr'
                              ? 'Metin hikayesi hazırlanıyor...'
                              : 'Preparing text story...'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ));
                        _createTextStory();
                      },
                    ),
                    if (hasExistingStories)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: _buildStoryOptionButton(
                          icon: Icons.visibility,
                          label:
                              language == 'tr' ? 'Hikayelerim' : 'My Stories',
                          color: Colors.amber,
                          isDarkTheme: isDarkTheme,
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            _viewCurrentUserStories();
                          },
                        ),
                      ),
                    // Add delete story option when user has stories
                    if (hasExistingStories)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: _buildStoryOptionButton(
                          icon: Icons.delete,
                          label: language == 'tr' ? 'Sil' : 'Delete',
                          color: Colors.red,
                          isDarkTheme: isDarkTheme,
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            _showDeleteStoryDialog();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        behavior: SnackBarBehavior.fixed,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        elevation: 8,
      ),
    );
  }

  // Updated helper method for smaller story option buttons
  Widget _buildStoryOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkTheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      splashColor: color.withOpacity(0.2),
      highlightColor: color.withOpacity(0.1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 65, // Smaller width
        padding: const EdgeInsets.symmetric(vertical: 8.0), // Less padding
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10), // Smaller radius
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.7),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 6, // Smaller blur
              spreadRadius: 0,
              offset: const Offset(0, 2), // Smaller offset
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 22, // Smaller icon
            ),
            const SizedBox(height: 5), // Less spacing
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10, // Smaller text
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Add a method to show delete story dialog
  void _showDeleteStoryDialog() async {
    final language = ref.read(lang);
    final isDarkTheme = ref.read(darkTheme);

    if (_auth.currentUser == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(language == 'tr'
            ? 'Hikayeler yükleniyor...'
            : 'Loading stories...'),
        duration: const Duration(seconds: 2),
      ));

      // Fetch current user's stories that haven't expired
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt', descending: true)
          .get();

      if (storiesSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language == 'tr'
                  ? 'Silinecek hikaye bulunamadı'
                  : 'No stories to delete'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Prepare story list
      List<Map<String, dynamic>> stories = [];
      for (var doc in storiesSnapshot.docs) {
        final data = doc.data();
        stories.add({
          'id': doc.id,
          'preview': data['media'] != null
              ? 'Image'
              : (data['description'] as String).length > 20
                  ? '${(data['description'] as String).substring(0, 20)}...'
                  : data['description'],
          'isImage': data['media'] != null,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        });
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor:
                isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              language == 'tr' ? 'Hikaye Sil' : 'Delete Story',
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black,
              ),
            ),
            content: Container(
              width: double.maxFinite,
              height: stories.length > 3 ? 200 : null,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  final time = _formatTimestamp(story['timestamp']);

                  return ListTile(
                    leading: Icon(
                      story['isImage'] ? Icons.image : Icons.text_fields,
                      color: isDarkTheme ? Colors.white70 : Colors.black87,
                    ),
                    title: Text(
                      story['isImage']
                          ? (language == 'tr'
                              ? 'Resim hikayesi'
                              : 'Image story')
                          : '${story['preview']}',
                      style: TextStyle(
                        color: isDarkTheme ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      time,
                      style: TextStyle(
                        color: isDarkTheme ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteStory(story['id']);
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  language == 'tr' ? 'İptal' : 'Cancel',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add a method to delete story
  Future<void> _deleteStory(String storyId) async {
    final language = ref.read(lang);

    if (_auth.currentUser == null) return;

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            language == 'tr' ? 'Hikaye siliniyor...' : 'Deleting story...'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ));

      // Get the story document
      final storyDoc = await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .get();

      if (!storyDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                language == 'tr' ? 'Hikaye bulunamadı' : 'Story not found'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      final storyData = storyDoc.data() as Map<String, dynamic>;

      // Check if there's an image to delete from storage
      if (storyData['media'] != null) {
        try {
          // Extract the file path from the URL
          final String mediaUrl = storyData['media'] as String;
          // Create a reference to the file in Firebase Storage
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          // Delete the file
          await ref.delete();
        } catch (storageError) {
          print('Error deleting story media: $storageError');
          // Continue with deletion of Firestore document even if media deletion fails
        }
      }

      // Delete story document from Firestore
      await FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .delete();

      // Update state to reflect the deletion
      ref.read(refreshingProvider.notifier).update((state) => !state);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(language == 'tr'
              ? 'Hikaye başarıyla silindi'
              : 'Story deleted successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(language == 'tr'
              ? 'Hikaye silinirken hata oluştu'
              : 'Error deleting story'),
          backgroundColor: Colors.red,
        ));
        print('Error deleting story: $e');
      }
    }
  }

  // Helper method to format timestamp
  String _formatTimestamp(DateTime timestamp) {
    final language = ref.read(lang);
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return language == 'tr' ? 'Az önce' : 'Just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return language == 'tr'
          ? '$minutes dakika önce'
          : '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return language == 'tr'
          ? '$hours saat önce'
          : '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }

    final day = timestamp.day;
    final month = timestamp.month;
    final hour = timestamp.hour;
    final minute = timestamp.minute;

    // Format minute with leading zero if needed
    final formattedMinute = minute < 10 ? '0$minute' : '$minute';

    return language == 'tr'
        ? '$day/$month - $hour:$formattedMinute'
        : '$month/$day - $hour:$formattedMinute';
  }
}
