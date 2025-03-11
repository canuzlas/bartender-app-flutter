import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/button_list.dart';
import 'package:flutter_signin_button/button_view.dart';
import 'package:bartender/S/loginPart/loginScreen/loginScreenController.dart';

class Loginscreenmain extends ConsumerStatefulWidget {
  const Loginscreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _LoginscreenmainState();
}

class _LoginscreenmainState extends ConsumerState<Loginscreenmain> {
  Loginscreencontroller loginscreencontroller = Loginscreencontroller();

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    return Scaffold(
      backgroundColor: darkThemeMain
          ? const Color.fromRGBO(23, 21, 59, 1)
          : const Color.fromRGBO(249, 247, 247, 1),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                darkThemeMain
                    ? "assets/openingPageDT.png"
                    : "assets/openingPageLT.png",
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                langMain == "tr" ? "Bartender" : "Bartender",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: darkThemeMain ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Subtitle
              Text(
                langMain == "tr"
                    ? "Yenilikçi bir maceraya hazır mısın?"
                    : "Are you ready for an innovative adventure?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: darkThemeMain ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              // Google Sign In Button
              SignInButton(
                darkThemeMain ? Buttons.Google : Buttons.GoogleDark,
                text: langMain == "tr"
                    ? "Google ile giriş yap"
                    : "Sign in with Google",
                onPressed: () {
                  loginscreencontroller.signInWithGoogle(context);
                },
              ),
              const SizedBox(height: 20),
              // Footer
              Text(
                langMain == "tr"
                    ? "Giriş yaparak, kullanım şartlarını kabul etmiş olursunuz."
                    : "By signing in, you agree to our terms of use.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: darkThemeMain ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
