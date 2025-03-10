import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Firestore subscription
  StreamSubscription<QuerySnapshot>? _subscription;

  // App state flag
  bool _appInForeground = true;

  // Initialization flag
  bool _initialized = false;

  NotificationService._internal();

  // Initialize notifications
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🔔 Initializing notification service');

      // Initialize notification plugin
      await _setupNotifications();

      // Setup app lifecycle observer
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver(
        onResume: () => _appInForeground = true,
        onPause: () => _appInForeground = false,
      ));

      // Setup auth listener
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          _startMessageListener(user.uid);
        } else {
          _stopMessageListener();
        }
      });

      _initialized = true;
      debugPrint('✅ Notification service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    }
  }

  // Setup notifications
  Future<void> _setupNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Create channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'chat_channel',
        'Chat Notifications',
        description: 'Notifications for new chat messages',
        importance: Importance.max,
        playSound: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    debugPrint('Local notifications setup complete');
  }

  // Start listening for messages
  void _startMessageListener(String userId) {
    _stopMessageListener(); // Clean up any existing subscription

    debugPrint('Starting message listener for user: $userId');

    _subscription = FirebaseFirestore.instance
        .collection('messages')
        .where('recipientId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) => _processSnapshot(snapshot, userId),
          onError: (e) => debugPrint('Message listener error: $e'),
        );
  }

  // Stop listening for messages
  void _stopMessageListener() {
    _subscription?.cancel();
    _subscription = null;
  }

  // Process message snapshot
  void _processSnapshot(QuerySnapshot snapshot, String userId) {
    // Skip if app is in foreground
    if (_appInForeground) {
      debugPrint('App in foreground, skipping notifications');
      return;
    }

    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added) {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        // Skip messages sent by current user
        final senderId = data['senderId'];
        if (senderId == userId) continue;

        // Check if message is recent (created in last minute)
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate()).inSeconds;
          if (diff > 60) continue; // Skip older messages
        }

        // Get message details
        final sender = data['senderName'] ?? 'Someone';
        final content = data['content'] ?? 'New message';

        // Show notification
        _showNotification(
          'Message from $sender',
          content,
        );
      }
    }
  }

  // Show notification
  Future<void> _showNotification(String title, String body) async {
    // Skip if app is in foreground
    if (_appInForeground) return;

    try {
      debugPrint('Showing notification: $title - $body');

      const androidDetails = AndroidNotificationDetails(
        'chat_channel',
        'Chat Notifications',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      int id = Random().nextInt(100000);
      await _notifications.show(id, title, body, details);

      debugPrint('✅ Notification sent');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _stopMessageListener();
    WidgetsBinding.instance.removeObserver(_AppLifecycleObserver(
      onResume: () {},
      onPause: () {},
    ));
  }
}

// App lifecycle observer
class _AppLifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResume;
  final VoidCallback onPause;

  _AppLifecycleObserver({required this.onResume, required this.onPause});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    } else if (state == AppLifecycleState.paused) {
      onPause();
    }
  }
}
