import 'dart:async';
import 'package:bartender/S/startingPart/openingScreen/osSettings.dart';
import 'package:bartender/firebase_options.dart';
import 'package:bartender/mainSettings.dart';
import 'package:bartender/notification/notificationMain.dart';
import 'package:bartender/router/router.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPrefsMain = await SharedPreferences.getInstance();

  // Initialize Firebase first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize notification service
  try {
    debugPrint('Initializing notification service');
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Error initializing notification service: $e');
  }

  runApp(ProviderScope(overrides: [
    sharedPreferences.overrideWithValue(sharedPrefsMain),
  ], child: const MyApp()));

  debugPrint('⭐ App started');
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkThemeMain = ref.watch(darkTheme);

    // Add emergency test after app starts
    Future.delayed(const Duration(seconds: 3), () async {
      // First try a direct local notification

      // Then after a few seconds, try with a Firestore document
      await Future.delayed(const Duration(seconds: 2));
    });

    return MaterialApp(
      debugShowMaterialGrid: false,
      showSemanticsDebugger: false,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: GeneratedRouter.router,
      theme: darkThemeMain ? AppTheme.darkTheme : AppTheme.lightTheme,
      initialRoute: "/",
    );
  }
}
