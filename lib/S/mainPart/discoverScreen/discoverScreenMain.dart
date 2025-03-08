import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenModel.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenState.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverPageController.dart';
import 'package:bartender/S/mainPart/discoverScreen/searchDelegate.dart';
import 'package:bartender/S/mainPart/otherUserProfileScreen/otherUserProfileScreen.dart';
import 'package:bartender/mainSettings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

final FirebaseAuth auth = FirebaseAuth.instance;

class DiscoveryScreenMain extends ConsumerStatefulWidget {
  @override
  _DiscoveryScreenMainState createState() => _DiscoveryScreenMainState();
}

class _DiscoveryScreenMainState extends ConsumerState<DiscoveryScreenMain> {
  final DiscoverPageController _controller = DiscoverPageController();

  @override
  Widget build(BuildContext context) {
    final tweetAsyncValue = ref.watch(tweetProvider);
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    return Scaffold(
      backgroundColor: darkThemeMain ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Your World',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: darkThemeMain ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: darkThemeMain ? Colors.black : Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              Icons.search,
              color: darkThemeMain ? Colors.white : Colors.black87,
              size: 28,
            ),
            onPressed: () {
              showSearch(
                context: context,
                delegate: UserSearchDelegate(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: tweetAsyncValue.when(
                data: (tweets) {
                  if (tweets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_off,
                            size: 70,
                            color: darkThemeMain
                                ? Colors.grey[700]
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts to discover yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: darkThemeMain
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    itemCount: tweets.length,
                    itemBuilder: (context, index) {
                      final tweet = tweets[index];
                      return FutureBuilder<String>(
                        future: _controller.getUserName(tweet.userId),
                        builder: (context, snapshot) {
                          final userName = snapshot.data ?? 'Loading...';
                          final userPhotoURL = tweet.userPhotoURL.isNotEmpty
                              ? tweet.userPhotoURL
                              : 'https://picsum.photos/200';
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              color: darkThemeMain
                                  ? Colors.grey[900]
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: darkThemeMain
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (FirebaseAuth
                                                  .instance.currentUser?.uid ==
                                              tweet.userId) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'You cannot view your own profile'),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                          } else {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        OtherUserProfileScreen(
                                                            userId:
                                                                tweet.userId)));
                                          }
                                        },
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: Colors.grey[300],
                                          backgroundImage:
                                              NetworkImage(userPhotoURL),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                if (FirebaseAuth.instance
                                                        .currentUser?.uid !=
                                                    tweet.userId) {
                                                  Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              OtherUserProfileScreen(
                                                                  userId: tweet
                                                                      .userId)));
                                                }
                                              },
                                              child: Text(
                                                userName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: darkThemeMain
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _controller
                                                  .timeAgo(tweet.timestamp),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: darkThemeMain
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 10),
                                  child: Text(
                                    tweet.message,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: darkThemeMain
                                          ? Colors.white
                                          : Colors.black87,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                if (tweet.postImageURL.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                0.4,
                                      ),
                                      width: double.infinity,
                                      child: Image.network(
                                        tweet.postImageURL,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: darkThemeMain
                                                  ? Colors.grey[800]
                                                  : Colors.grey[200],
                                            ),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  darkThemeMain
                                                      ? Colors.white70
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 200,
                                            color: darkThemeMain
                                                ? Colors.grey[800]
                                                : Colors.grey[200],
                                            child: Center(
                                              child: Icon(
                                                Icons.error_outline,
                                                color: darkThemeMain
                                                    ? Colors.grey[600]
                                                    : Colors.grey[400],
                                                size: 40,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                Divider(
                                  color: darkThemeMain
                                      ? Colors.grey[800]
                                      : Colors.grey[300],
                                  height: 1,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              tweet.likedBy.contains(
                                                      auth.currentUser?.uid)
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                            ),
                                            color: tweet.likedBy.contains(
                                                    auth.currentUser?.uid)
                                                ? Colors.redAccent
                                                : darkThemeMain
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                            onPressed: () {
                                              final userId =
                                                  auth.currentUser!.uid;
                                              if (tweet.likedBy
                                                  .contains(userId)) {
                                                FirebaseFirestore.instance
                                                    .collection('tweets')
                                                    .doc(tweet.id)
                                                    .update({
                                                  'likedBy':
                                                      FieldValue.arrayRemove(
                                                          [userId]),
                                                });
                                              } else {
                                                FirebaseFirestore.instance
                                                    .collection('tweets')
                                                    .doc(tweet.id)
                                                    .update({
                                                  'likedBy':
                                                      FieldValue.arrayUnion(
                                                          [userId]),
                                                });
                                              }
                                            },
                                          ),
                                          Text(
                                            tweet.likedBy.length.toString(),
                                            style: TextStyle(
                                              color: darkThemeMain
                                                  ? Colors.grey[400]
                                                  : Colors.grey[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.chat_bubble_outline,
                                          color: darkThemeMain
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          Navigator.of(context)
                                              .push(MaterialPageRoute(
                                            builder: (context) =>
                                                CommentsPage(tweetId: tweet.id),
                                          ));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      darkThemeMain ? Colors.white70 : Colors.grey[800]!,
                    ),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: darkThemeMain
                              ? Colors.redAccent
                              : Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading content',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                darkThemeMain ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: darkThemeMain
                                ? Colors.grey[500]
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
