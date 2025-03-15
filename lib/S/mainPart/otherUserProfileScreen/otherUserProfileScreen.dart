import 'package:bartender/S/mainPart/commentsScreen/commentsScreenMain.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bartender/S/mainPart/msgScreen/messagingPage.dart';
import 'package:intl/intl.dart';

class OtherUserProfileScreen extends ConsumerWidget {
  final String userId;

  const OtherUserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(userProvider(userId));
    final tweetCountAsyncValue = ref.watch(tweetCountProvider(userId));
    final darkThemeMain = ref.watch(darkTheme.notifier).state;
    final theme = Theme.of(context);
    final mutualFollowersAsyncValue =
        ref.watch(mutualFollowersProvider(userId));
    final isBlockedAsyncValue = ref.watch(isUserBlockedProvider(userId));
    final isBlockedByTargetAsyncValue =
        ref.watch(isBlockedByTargetUserProvider(userId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          isBlockedByTargetAsyncValue.when(
            data: (isBlockedByTarget) {
              if (isBlockedByTarget) {
                return const SizedBox
                    .shrink(); // Hide menu if blocked by target
              }
              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                onSelected: (value) {
                  if (value == 'block') {
                    _showBlockUserDialog(context, userId, ref);
                  } else if (value == 'report') {
                    _showReportUserDialog(context, userId);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isBlocked = isBlockedAsyncValue.asData?.value ?? false;
                  return [
                    PopupMenuItem<String>(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(isBlocked ? Icons.person_add : Icons.block,
                              color:
                                  isBlocked ? Colors.blue : Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(isBlocked ? 'Unblock User' : 'Block User'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Text('Report User'),
                        ],
                      ),
                    ),
                  ];
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: userAsyncValue.when(
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text('User not found'));
          }
          final isFollowing = ref.watch(followingProvider(userId));
          final joinDate = userData['createdAt'] != null
              ? (userData['createdAt'] as Timestamp).toDate()
              : null;

          // Extract user interests or tags
          final List<dynamic> userInterests = userData['interests'] ?? [];

          return isBlockedAsyncValue.when(
            data: (isBlocked) {
              final isBlockedByTargetAsyncValue =
                  ref.watch(isBlockedByTargetUserProvider(userId));
              return isBlockedByTargetAsyncValue.when(
                data: (isBlockedByTarget) {
                  if (isBlockedByTarget) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block,
                              size: 60,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You cannot view this profile',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This user has blocked you',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SafeArea(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(25)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -20),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Hero(
                                          tag: 'avatar-${userData['uid']}',
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: theme.cardColor,
                                                width: 4,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: 45,
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              backgroundImage: NetworkImage(
                                                userData['photoURL'] ??
                                                    'https://picsum.photos/200',
                                              ),
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: isBlocked
                                                  ? null
                                                  : () {
                                                      Navigator.of(context)
                                                          .push(
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              MessagingPage(
                                                                  recipientId:
                                                                      userId),
                                                        ),
                                                      );
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isBlocked
                                                    ? Colors.grey
                                                    : Colors.green,
                                                foregroundColor: Colors.white,
                                                elevation: 2,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              icon: const Icon(Icons.message,
                                                  size: 18),
                                              label: const Text('Message'),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: isBlocked
                                                  ? null
                                                  : () {
                                                      if (isFollowing) {
                                                        ref
                                                            .read(
                                                                followingProvider(
                                                                        userId)
                                                                    .notifier)
                                                            .unfollow();
                                                      } else {
                                                        ref
                                                            .read(
                                                                followingProvider(
                                                                        userId)
                                                                    .notifier)
                                                            .follow();
                                                      }
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: isBlocked
                                                    ? Colors.grey
                                                    : (isFollowing
                                                        ? Colors.grey.shade200
                                                        : theme.primaryColor),
                                                foregroundColor: isFollowing
                                                    ? Colors.black87
                                                    : Colors.white,
                                                elevation: 2,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                              ),
                                              icon: Icon(
                                                isFollowing
                                                    ? Icons.person_remove
                                                    : Icons.person_add,
                                                size: 18,
                                              ),
                                              label: Text(isFollowing
                                                  ? 'Unfollow'
                                                  : 'Follow'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, -15),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userData['displayname'] ?? 'Unknown',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userData['bio'] ?? 'No bio available',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: theme
                                                .textTheme.bodyMedium?.color
                                                ?.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (joinDate != null)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 16,
                                                color: theme
                                                    .textTheme.bodySmall?.color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Joined ${DateFormat('MMMM d, y').format(joinDate)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.textTheme
                                                      .bodySmall?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatsColumn(
                                              context,
                                              'Tweets',
                                              tweetCountAsyncValue.when(
                                                data: (count) => '$count',
                                                loading: () => '-',
                                                error: (_, __) => 'Err',
                                              ),
                                              darkThemeMain: darkThemeMain),
                                          _buildVerticalDivider(),
                                          _buildStatsColumn(
                                            context,
                                            'Following',
                                            userData['following']
                                                    ?.length
                                                    .toString() ??
                                                '0',
                                            darkThemeMain: darkThemeMain,
                                          ),
                                          _buildVerticalDivider(),
                                          _buildStatsColumn(
                                            context,
                                            'Followers',
                                            userData['followers']
                                                    ?.length
                                                    .toString() ??
                                                '0',
                                            darkThemeMain: darkThemeMain,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  mutualFollowersAsyncValue.when(
                                    data: (count) => count > 0
                                        ? Card(
                                            elevation: 0,
                                            color: theme.cardColor
                                                .withOpacity(0.7),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              side: BorderSide(
                                                  color: theme.dividerColor
                                                      .withOpacity(0.5)),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(12.0),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                      Icons.people_alt_outlined,
                                                      color: theme.primaryColor,
                                                      size: 20),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '$count mutual follower${count > 1 ? 's' : ''}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: theme.textTheme
                                                          .bodyMedium?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),

                                  // Add Interests/Tags Section
                                  if (userInterests.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Icon(Icons.tag,
                                            size: 18,
                                            color: theme
                                                .textTheme.bodySmall?.color),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Interests',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .textTheme.titleMedium?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          userInterests.map<Widget>((interest) {
                                        return Chip(
                                          backgroundColor: theme.primaryColor
                                              .withOpacity(0.1),
                                          side: BorderSide(
                                              color: theme.primaryColor
                                                  .withOpacity(0.3)),
                                          label: Text(
                                            interest.toString(),
                                            style: TextStyle(
                                              color: theme.primaryColor,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.format_quote, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Recent Tweets',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              theme.textTheme.titleLarge?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Consumer(
                          builder: (context, watch, child) {
                            final userTweetsAsyncValue =
                                ref.watch(userTweetsProvider(userId));

                            if (isBlocked) {
                              return SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.block,
                                          size: 60,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'You have blocked this user',
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () {
                                            _unblockUser(userId, ref);
                                          },
                                          child: const Text('Unblock'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return userTweetsAsyncValue.when(
                              data: (tweets) {
                                if (tweets.isEmpty) {
                                  return SliverToBoxAdapter(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.speaker_notes_off,
                                              size: 60,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No tweets found',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final tweet = tweets[index];
                                      final tweetData = tweet.data();
                                      final likeCount = tweetData['likes'] ?? 0;
                                      final commentCount =
                                          tweetData['comments'] ?? 0;
                                      final postPhotoURL =
                                          tweetData['photoURL'];
                                      final timestamp =
                                          tweetData['timestamp'] as Timestamp;
                                      final formattedDate =
                                          DateFormat('MMM d · h:mm a')
                                              .format(timestamp.toDate());

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: 8.0,
                                            left: 16.0,
                                            right: 16.0),
                                        child: Card(
                                          elevation: 1,
                                          margin: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (postPhotoURL != null &&
                                                  postPhotoURL
                                                      .toString()
                                                      .isNotEmpty)
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius
                                                          .vertical(
                                                          top: Radius.circular(
                                                              16)),
                                                  child: Image.network(
                                                    postPhotoURL,
                                                    width: double.infinity,
                                                    height: 200,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        Container(
                                                      height: 200,
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: Center(
                                                          child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors
                                                            .grey.shade400,
                                                        size: 40,
                                                      )),
                                                    ),
                                                  ),
                                                ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      tweetData['message'] ??
                                                          '',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      formattedDate,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Divider(),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceAround,
                                                      children: [
                                                        // Retrieve current user and determine like state
                                                        Builder(
                                                          builder: (context) {
                                                            final currentUser =
                                                                FirebaseAuth
                                                                    .instance
                                                                    .currentUser;
                                                            final likedBy =
                                                                (tweetData['likedBy']
                                                                        as List<
                                                                            dynamic>?) ??
                                                                    [];
                                                            final isLiked =
                                                                currentUser !=
                                                                        null &&
                                                                    likedBy.contains(
                                                                        currentUser
                                                                            .uid);
                                                            return _buildTweetActionButton(
                                                              icon: isLiked
                                                                  ? Icons
                                                                      .favorite
                                                                  : Icons
                                                                      .favorite_border,
                                                              label:
                                                                  '$likeCount',
                                                              color: isLiked
                                                                  ? Colors.red
                                                                  : null,
                                                              onTap: () async {
                                                                if (currentUser ==
                                                                    null) {
                                                                  return;
                                                                }
                                                                if (!isLiked) {
                                                                  await tweet
                                                                      .reference
                                                                      .update({
                                                                    'likes': FieldValue
                                                                        .increment(
                                                                            1),
                                                                    'likedBy':
                                                                        FieldValue
                                                                            .arrayUnion([
                                                                      currentUser
                                                                          .uid
                                                                    ])
                                                                  });
                                                                } else {
                                                                  await tweet
                                                                      .reference
                                                                      .update({
                                                                    'likes': FieldValue
                                                                        .increment(
                                                                            -1),
                                                                    'likedBy':
                                                                        FieldValue
                                                                            .arrayRemove([
                                                                      currentUser
                                                                          .uid
                                                                    ])
                                                                  });
                                                                }
                                                              },
                                                            );
                                                          },
                                                        ),
                                                        _buildTweetActionButton(
                                                          icon: Icons
                                                              .chat_bubble_outline,
                                                          label:
                                                              '$commentCount',
                                                          onTap: () {
                                                            Navigator.of(
                                                                    context)
                                                                .push(
                                                              MaterialPageRoute(
                                                                builder: (context) =>
                                                                    CommentsPage(
                                                                        tweetId:
                                                                            tweet.id),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                        _buildTweetActionButton(
                                                          icon: Icons
                                                              .share_outlined,
                                                          label: 'Share',
                                                          onTap: () {
                                                            // Share functionality
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text('Sharing coming soon')));
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: tweets.length,
                                  ),
                                );
                              },
                              loading: () => const SliverToBoxAdapter(
                                  child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )),
                              error: (error, stack) => const SliverToBoxAdapter(
                                  child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 40, color: Colors.red),
                                      SizedBox(height: 16),
                                      Text('Error loading tweets',
                                          style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              )),
                            );
                          },
                        ),
                        // Add some padding at the bottom
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 30),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error checking block status')),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Text('Error checking blocked status: $error'),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTweetActionButton({
    required IconData icon,
    required String label,
    required Function() onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsColumn(BuildContext context, String label, String value,
      {bool darkThemeMain = true}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: darkThemeMain ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  void _showBlockUserDialog(
      BuildContext context, String userId, WidgetRef ref) {
    final isBlockedAsyncValue = ref.watch(isUserBlockedProvider(userId));

    isBlockedAsyncValue.when(
      data: (isBlocked) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isBlocked ? 'Unblock User' : 'Block User'),
            content: Text(isBlocked
                ? 'Are you sure you want to unblock this user? You will be able to see their posts and messages again.'
                : 'Are you sure you want to block this user? They will be removed from your followers and following lists, and you will not see their posts or messages.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (isBlocked) {
                    _unblockUser(userId, ref);
                  } else {
                    _blockUser(userId, ref);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isBlocked
                          ? 'User unblocked successfully'
                          : 'User blocked successfully'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(
                  isBlocked ? 'Unblock' : 'Block',
                  style: TextStyle(color: isBlocked ? Colors.blue : Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error checking block status')),
      ),
    );
  }

  Future<void> _unblockUser(String userId, WidgetRef ref) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final firestore = FirebaseFirestore.instance;
    final currentUserRef = firestore.collection('users').doc(currentUser.uid);

    // Remove user from blocked list
    await currentUserRef.update({
      'blockedUsers': FieldValue.arrayRemove([userId]),
    });

    // Refresh the blocked status
    ref.refresh(isUserBlockedProvider(userId));
  }

  Future<void> _blockUser(String userId, WidgetRef ref) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get a reference to Firestore
    final firestore = FirebaseFirestore.instance;

    // Start a batch write to ensure all operations complete together
    final batch = firestore.batch();

    // References to both user documents
    final currentUserRef = firestore.collection('users').doc(currentUser.uid);
    final blockedUserRef = firestore.collection('users').doc(userId);

    // 1. Add user to blocked list
    batch.update(currentUserRef, {
      'blockedUsers': FieldValue.arrayUnion([userId]),
    });

    // 2. Remove blocked user from current user's following list (if present)
    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([userId]),
    });

    // 3. Remove blocked user from current user's followers list (if present)
    batch.update(currentUserRef, {
      'followers': FieldValue.arrayRemove([userId]),
    });

    // 4. Remove current user from blocked user's following list (if present)
    batch.update(blockedUserRef, {
      'following': FieldValue.arrayRemove([currentUser.uid]),
    });

    // 5. Remove current user from blocked user's followers list (if present)
    batch.update(blockedUserRef, {
      'followers': FieldValue.arrayRemove([currentUser.uid]),
    });

    // Execute all the updates in a single batch
    await batch.commit();

    // Refresh the blocked status
    ref.refresh(isUserBlockedProvider(userId));

    // If the blocked user was being followed, update the local state
    final isFollowing = ref.read(followingProvider(userId));
    if (isFollowing) {
      ref.read(followingProvider(userId).notifier).state = false;
    }
  }

  void _showReportUserDialog(BuildContext context, String userId) {
    final reasons = [
      'Spam',
      'Harassment',
      'Inappropriate content',
      'Fake account',
      'Other'
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select a reason for reporting:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: reasons
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedReason = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement report functionality
                _reportUser(userId, selectedReason);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportUser(String userId, String reason) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Create a report document
    await FirebaseFirestore.instance.collection('reports').add({
      'reportedUserId': userId,
      'reportedBy': currentUser.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }
}

final userProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  return userDoc.data();
});

final userTweetsProvider = StreamProvider.family<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>, String>((ref, userId) {
  final currentUser = FirebaseAuth.instance.currentUser;

  // First check if user is blocked
  if (currentUser != null) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final blockedUsers =
          snapshot.data()?['blockedUsers'] as List<dynamic>? ?? [];

      // If user is blocked, return empty list
      if (blockedUsers.contains(userId)) {
        return [];
      }

      // Otherwise return their tweets
      final tweetsSnapshot = await FirebaseFirestore.instance
          .collection('tweets')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return tweetsSnapshot.docs;
    });
  } else {
    // If not logged in, just return the tweets
    return FirebaseFirestore.instance
        .collection('tweets')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }
});

final followingProvider =
    StateNotifierProvider.family<FollowingNotifier, bool, String>(
  (ref, userId) => FollowingNotifier(userId),
);

class FollowingNotifier extends StateNotifier<bool> {
  final String userId;

  FollowingNotifier(this.userId) : super(false) {
    _loadInitialFollowingState();
  }

  Future<void> _loadInitialFollowingState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final following = userDoc.data()?['following'] as List<dynamic>? ?? [];
    state = following.contains(userId);
  }

  Future<void> follow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'following': FieldValue.arrayUnion([userId]),
    });
    state = true;
  }

  Future<void> unfollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .update({
      'following': FieldValue.arrayRemove([userId]),
    });
    state = false;
  }
}

final tweetCountProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('tweets')
      .where('userId', isEqualTo: userId)
      .get();
  return snapshot.size;
});

final mutualFollowersProvider =
    FutureProvider.family<int, String>((ref, userId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return 0;

  // Get current user's followers
  final currentUserDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();

  // Get other user's followers
  final otherUserDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

  final currentUserFollowers =
      List<String>.from(currentUserDoc.data()?['followers'] ?? []);
  final otherUserFollowers =
      List<String>.from(otherUserDoc.data()?['followers'] ?? []);

  // Find intersection (mutual followers)
  final mutualFollowers =
      currentUserFollowers.toSet().intersection(otherUserFollowers.toSet());

  return mutualFollowers.length;
});

final isUserBlockedProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return false;

  // Check if current user has blocked the target user
  final currentUserDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();
  final blockedByMe =
      currentUserDoc.data()?['blockedUsers'] as List<dynamic>? ?? [];

  // Check if target user has blocked the current user
  final targetUserDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final blockedByThem =
      targetUserDoc.data()?['blockedUsers'] as List<dynamic>? ?? [];

  // Return true if either user has blocked the other
  return blockedByMe.contains(userId) ||
      blockedByThem.contains(currentUser.uid);
});

final isBlockedByTargetUserProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return false;

  final targetUserDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();

  final blockedUsers =
      targetUserDoc.data()?['blockedUsers'] as List<dynamic>? ?? [];
  return blockedUsers.contains(currentUser.uid);
});
