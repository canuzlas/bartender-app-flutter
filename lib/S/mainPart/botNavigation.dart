import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenMain.dart';
import 'package:bartender/S/mainPart/homeScreen/homeScreenMain.dart';
import 'package:bartender/S/mainPart/msgScreen/msgScreenMain.dart';
import 'package:bartender/S/mainPart/profileScreen/profileScreenMain.dart';
import 'package:bartender/S/mainPart/discoverScreen/discoverScreenMain.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class Botnavigation extends ConsumerStatefulWidget {
  const Botnavigation({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _BotnavigationState();
}

class _BotnavigationState extends ConsumerState<Botnavigation> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.w600);
  static final List<Widget> _widgetOptions = <Widget>[
    const HomeScreenMain(),
    const MsgScreenMain(),
    const DiscoveryScreenMain(),
    const AiChatScreenMain(),
    const Profilescreenmain(),
    const Center(child: Text('Messages Page', style: optionStyle)),
  ];

  @override
  Widget build(BuildContext context) {
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);
    return Scaffold(
      backgroundColor: darkThemeMain
          ? const Color.fromRGBO(23, 21, 59, 1)
          : const Color.fromRGBO(249, 247, 247, 1),
      appBar: AppBar(
        backgroundColor: darkThemeMain
            ? const Color.fromRGBO(23, 21, 59, 1)
            : const Color.fromRGBO(249, 247, 247, 1),
        elevation: 20,
        centerTitle: true,
        title: Image.asset(
          darkThemeMain
              ? "assets/openingPageDT.png"
              : "assets/openingPageLT.png",
          width: 50,
          height: 50,
        ),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0), // Add padding
        child: SafeArea(
          child: SingleChildScrollView(
            // Add SingleChildScrollView
            scrollDirection: Axis.horizontal,
            child: GNav(
              backgroundColor: darkThemeMain
                  ? const Color.fromRGBO(23, 21, 59, 1)
                  : const Color.fromRGBO(249, 247, 247, 1),
              rippleColor: Colors.grey[300]!,
              hoverColor: Colors.grey[100]!,
              gap: 8,
              activeColor: darkThemeMain
                  ? const Color.fromRGBO(249, 247, 247, 1)
                  : const Color.fromRGBO(23, 21, 59, 1),
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: darkThemeMain
                  ? const Color.fromRGBO(23, 21, 59, 1)
                  : const Color.fromRGBO(249, 247, 247, 1),
              color: darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              tabs: [
                GButton(
                  icon: Icons.home,
                  text: langMain == "tr" ? "Anasayfa" : 'Home',
                ),
                GButton(
                  icon: Icons.message,
                  text: langMain == "tr" ? "Mesajlar" : 'Messages',
                ),
                GButton(
                  icon: Icons.search,
                  text: langMain == "tr" ? "Arama" : 'Search',
                ),
                GButton(
                  icon: Icons.smart_toy,
                  text: langMain == "tr" ? "Rakun" : 'Raccoon',
                ),
                GButton(
                  icon: Icons.person,
                  text: langMain == "tr" ? "Profil" : 'Profile',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
