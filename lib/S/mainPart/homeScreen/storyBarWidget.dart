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
            onTap: () => _createNewStory(),
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

  void _createNewStory() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          ref.watch(darkTheme) ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ref.watch(lang) == 'tr' ? 'Hikaye Oluştur' : 'Create Story',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ref.watch(darkTheme) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStoryOption(
                    Icons.camera_alt,
                    ref.watch(lang) == 'tr' ? 'Kamera' : 'Camera',
                    () => _pickStoryMedia(isCamera: true),
                  ),
                  _buildStoryOption(
                    Icons.photo_library,
                    ref.watch(lang) == 'tr' ? 'Galeri' : 'Gallery',
                    () => _pickStoryMedia(isCamera: false),
                  ),
                  _buildStoryOption(
                    Icons.text_fields,
                    ref.watch(lang) == 'tr' ? 'Yazı' : 'Text',
                    () => _createTextStory(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryOption(IconData icon, String label, VoidCallback onTap) {
    final primaryColor =
        ref.watch(darkTheme) ? Colors.orangeAccent : Colors.deepOrange;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 1),
            ),
            child: Icon(icon, color: primaryColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ref.watch(darkTheme) ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStoryMedia({required bool isCamera}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
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

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Create story document in Firestore
      final now = Timestamp.now();
      final expiresAt =
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24)));

      await FirebaseFirestore.instance.collection('stories').add({
        'userId': _auth.currentUser!.uid,
        'userPhotoURL': _auth.currentUser!.photoURL,
        'userName': _auth.currentUser!.displayName,
        'media': downloadUrl,
        'description': '',
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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            ref.watch(lang) == 'tr' ? 'Hikaye paylaşıldı' : 'Story shared'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted)
        return; // Check if widget is still mounted before continuing

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _createTextStory() {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            ref.watch(darkTheme) ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          ref.watch(lang) == 'tr'
              ? 'Metin Hikayesi Oluştur'
              : 'Create Text Story',
          style: TextStyle(
            color: ref.watch(darkTheme) ? Colors.white : Colors.black,
          ),
        ),
        content: TextField(
          controller: textController,
          maxLines: 5,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: ref.watch(lang) == 'tr'
                ? 'Hikayenizi yazın...'
                : 'Write your story...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: ref.watch(darkTheme) ? Colors.black54 : Colors.grey[100],
          ),
          style: TextStyle(
            color: ref.watch(darkTheme) ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              ref.watch(lang) == 'tr' ? 'İptal' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) {
                return;
              }

              Navigator.pop(context);

              try {
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

                if (!mounted)
                  return; // Check if widget is still mounted before continuing

                setState(() {
                  _isUploading = false;
                });

                // Update state to show the new story
                ref.read(refreshingProvider.notifier).update((state) => !state);

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ref.watch(lang) == 'tr'
                      ? 'Metin hikayesi paylaşıldı'
                      : 'Text story shared'),
                  backgroundColor: Colors.green,
                ));
              } catch (e) {
                if (!mounted)
                  return; // Check if widget is still mounted before continuing

                setState(() {
                  _isUploading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ref.watch(darkTheme)
                  ? Colors.orangeAccent
                  : Colors.deepOrange,
            ),
            child: Text(ref.watch(lang) == 'tr' ? 'Paylaş' : 'Share'),
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
          onClose: () => Navigator.pop(context),
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

  // Update the method to handle sending messages on stories
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
}
