import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Selectthemescreenmain extends ConsumerStatefulWidget {
  const Selectthemescreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SelectthemescreenmainState();
}

class _SelectthemescreenmainState extends ConsumerState<Selectthemescreenmain> {
  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    final sss = ref.watch(sharedPreferences);
    return Scaffold(
      backgroundColor: darkThemeMain
          ? const Color.fromRGBO(23, 21, 59, 1)
          : const Color.fromRGBO(249, 247, 247, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                langMain == "tr" ? "Tema Seçimi" : "Select Theme",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkThemeMain ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => {
                  sss.setBool("darkTheme", true),
                  ref.read(darkTheme.notifier).state = true
                },
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(23, 21, 59, 1),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/openingPageDT.png",
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        langMain == "tr" ? "Koyu Tema" : "Dark Theme",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        darkThemeMain
                            ? langMain == "tr"
                                ? "[SEÇİLEN]"
                                : "[CHOSEN]"
                            : "",
                        style: const TextStyle(
                          color: Color.fromARGB(255, 205, 205, 6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => {
                  sss.setBool("darkTheme", false),
                  ref.read(darkTheme.notifier).state = false
                },
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(249, 247, 247, 1),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/openingPageLT.png",
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        langMain == "tr" ? "Açık Tema" : "Light Theme",
                        style: const TextStyle(
                          color: Color.fromRGBO(23, 21, 59, 1),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        darkThemeMain
                            ? ""
                            : langMain == "tr"
                                ? "[SEÇİLEN]"
                                : "[CHOSEN]",
                        style: const TextStyle(
                          color: Color.fromARGB(255, 5, 126, 57),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/selectLangScreen'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/selectThemeNext.png",
                      width: 70,
                      height: 60,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      langMain == "tr" ? "Devam Et" : "Continue",
                      style: TextStyle(
                        color: darkThemeMain
                            ? Colors.white
                            : const Color.fromRGBO(23, 21, 59, 1),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      langMain == "tr"
                          ? "Tema seçimi, uygulamanın görünümünü değiştirir."
                          : "Theme selection changes the appearance of the app.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: darkThemeMain ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      langMain == "tr"
                          ? "Devam etmek için bir tema seçin."
                          : "Select a theme to continue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: darkThemeMain ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
