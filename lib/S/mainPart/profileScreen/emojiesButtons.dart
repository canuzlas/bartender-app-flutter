import 'package:flutter/material.dart';

// Reusable widget for emoji button
class EmojiButton extends StatelessWidget {
  final String emoji;
  final BuildContext context;

  EmojiButton({required this.emoji, required this.context});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(this.context).pop(emoji),
      child: Text(emoji, style: TextStyle(fontSize: 24)),
    );
  }
}

returnEmojiesButtons(context) {
  return [
    EmojiButton(emoji: "🍸", context: context),
    EmojiButton(emoji: "🍹", context: context),
    EmojiButton(emoji: "🍺", context: context),
    EmojiButton(emoji: "🍷", context: context),
    EmojiButton(emoji: "🍾", context: context),
    EmojiButton(emoji: "🍶", context: context),
    EmojiButton(emoji: "🍵", context: context),
    EmojiButton(emoji: "✈️", context: context),
    EmojiButton(emoji: "👽", context: context),
    EmojiButton(emoji: "🤩", context: context),
    EmojiButton(emoji: "🌴", context: context),
    EmojiButton(emoji: "✨", context: context),
    EmojiButton(emoji: "🧮", context: context),
    EmojiButton(emoji: "🐹", context: context),
    EmojiButton(emoji: "😃", context: context),
    EmojiButton(emoji: "🎾", context: context),
    EmojiButton(emoji: "💬", context: context),
    EmojiButton(emoji: "💀", context: context),
    EmojiButton(emoji: "😂", context: context),
    EmojiButton(emoji: "🏐", context: context),
    EmojiButton(emoji: "♋️", context: context),
    EmojiButton(emoji: "🚌", context: context),
    EmojiButton(emoji: "🚀", context: context),
    EmojiButton(emoji: "😘", context: context),
    EmojiButton(emoji: "❤️", context: context),
    EmojiButton(emoji: "😍", context: context),
    EmojiButton(emoji: "🚙", context: context),
    EmojiButton(emoji: "🏎️", context: context),
    EmojiButton(emoji: "🚕", context: context),
    EmojiButton(emoji: "🛵", context: context),
    EmojiButton(emoji: "🏍️", context: context),
    EmojiButton(emoji: "🚨", context: context),
    EmojiButton(emoji: "🚔", context: context),
    EmojiButton(emoji: "🚦", context: context),
    EmojiButton(emoji: "🏝️", context: context),
    EmojiButton(emoji: "⛱️", context: context),
    EmojiButton(emoji: "🌅", context: context),
    EmojiButton(emoji: "🔫", context: context),
    EmojiButton(emoji: "⚔️", context: context),
    EmojiButton(emoji: "💊", context: context),
    // Add more emojis as needed
  ];
}
