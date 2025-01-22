import 'package:bartender/S/startingPart/openingScreen/osSettings.dart';
import 'package:bartender/firebase_options.dart';
import 'package:bartender/mainSettings.dart';
import 'package:bartender/router/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPrefsMain = await SharedPreferences.getInstance();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  runApp(ProviderScope(overrides: [
    sharedPreferences.overrideWithValue(sharedPrefsMain),
  ], child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkThemeMain = ref.watch(darkTheme);
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
