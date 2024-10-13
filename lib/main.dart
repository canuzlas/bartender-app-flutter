
import 'package:bartender/S/openingScreen/osSettings.dart';
import 'package:bartender/mainSettings.dart';
import 'package:bartender/router/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    final darkThemeMain = ref.watch(darkTheme);
    return  MaterialApp(
      debugShowMaterialGrid: false,
      showSemanticsDebugger: false,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: GeneratedRouter.router,
      theme: darkThemeMain ? AppTheme.darkTheme:AppTheme.lightTheme,
      initialRoute: "/",
    );
  }
}