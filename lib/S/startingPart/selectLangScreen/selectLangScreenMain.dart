import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Selectlangscreenmain extends ConsumerStatefulWidget {
  const Selectlangscreenmain({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SelectlangscreenmainState();
}

class _SelectlangscreenmainState extends ConsumerState<Selectlangscreenmain> {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              langMain == "tr" ? "Dil Seçimi" : "Select Language",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: darkThemeMain ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => {
                  sss.setString("lang", "tr"),
                  ref.read(lang.notifier).state = "tr"
                },
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: darkThemeMain
                        ? const Color.fromRGBO(23, 21, 59, 1)
                        : const Color.fromRGBO(249, 247, 247, 1),
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
                        "assets/trLang.png",
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "TÜRKÇE",
                        style: TextStyle(
                          color: darkThemeMain ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        langMain == "tr" ? "[SEÇİLEN]" : "",
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => {
                  sss.setString("lang", "en"),
                  ref.read(lang.notifier).state = "en"
                },
                child: Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: darkThemeMain
                        ? const Color.fromRGBO(23, 21, 59, 1)
                        : const Color.fromRGBO(249, 247, 247, 1),
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
                        "assets/enLang.png",
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "ENGLISH",
                        style: TextStyle(
                          color: darkThemeMain ? Colors.white : Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        langMain == "en" ? "[CHOSEN]" : "",
                        style: const TextStyle(
                          color: Color.fromARGB(255, 5, 126, 57),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                await sss.setBool("set", true);
                Navigator.pushNamed(context, '/loginScreen');
              },
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
                        ? "Dil seçimi, uygulamanın dilini değiştirir."
                        : "Language selection changes the app's language.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: darkThemeMain ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    langMain == "tr"
                        ? "Devam etmek için bir dil seçin."
                        : "Select a language to continue.",
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
    );
  }
}
