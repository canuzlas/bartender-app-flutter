import 'package:flutter/material.dart';
import 'dart:math' as math;

// Model class to organize emojis into categories
class EmojiCategory {
  final String name;
  final String icon;
  final List<String> emojis;

  EmojiCategory({required this.name, required this.icon, required this.emojis});
}

// Reusable widget for emoji button with animation
class EmojiButton extends StatefulWidget {
  final String emoji;
  final BuildContext context;

  const EmojiButton({Key? key, required this.emoji, required this.context})
      : super(key: key);

  @override
  _EmojiButtonState createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Generate a semi-random rotation for each emoji
    final baseRotation = (widget.emoji.codeUnitAt(0) % 10 - 5) * math.pi / 180;

    // Get a color based on the emoji
    final colorCode = widget.emoji.codeUnitAt(0) % 5;
    final baseColors = [
      Colors.deepOrange,
      Colors.pink,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];
    final baseColor = baseColors[colorCode];

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
          _controller.forward();
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _controller.reverse();
        });
      },
      child: GestureDetector(
        onTap: () => Navigator.of(widget.context).pop(widget.emoji),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: baseRotation +
                    (_rotateAnimation.value * (baseRotation < 0 ? -1 : 1)),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isHovered
                          ? [baseColor.shade300, baseColor.shade100]
                          : [Colors.grey.shade200, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered
                            ? baseColor.withOpacity(0.4)
                            : Colors.black.withOpacity(0.1),
                        blurRadius: _isHovered ? 12 : 5,
                        offset: const Offset(0, 3),
                        spreadRadius: _isHovered ? 1 : 0,
                      ),
                    ],
                    border: Border.all(
                      color: _isHovered ? baseColor : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class CategorySelector extends StatelessWidget {
  final List<EmojiCategory> categories;
  final int selectedIndex;
  final Function(int) onSelected;

  const CategorySelector({
    Key? key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    categories[index].icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    categories[index].name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmojiPickerPage extends StatefulWidget {
  final BuildContext parentContext;

  const EmojiPickerPage({Key? key, required this.parentContext})
      : super(key: key);

  @override
  _EmojiPickerPageState createState() => _EmojiPickerPageState();
}

class _EmojiPickerPageState extends State<EmojiPickerPage> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Define categories with emojis
  final List<EmojiCategory> _categories = [
    EmojiCategory(
      name: "Drinks",
      icon: "🍸",
      emojis: [
        "🍸",
        "🍹",
        "🍺",
        "🍷",
        "🍾",
        "🍶",
        "🍵",
        "🍻",
        "🥂",
        "🥃",
        "🧃",
        "🧉",
        "🥤"
      ],
    ),
    EmojiCategory(
      name: "Travel",
      icon: "✈️",
      emojis: [
        "✈️",
        "🚀",
        "🚌",
        "🚙",
        "🏎️",
        "🚕",
        "🛵",
        "🏍️",
        "🚨",
        "🚔",
        "🚦",
        "🏝️",
        "⛱️",
        "🌅"
      ],
    ),
    EmojiCategory(
      name: "Faces",
      icon: "😃",
      emojis: [
        "😃",
        "🤩",
        "👽",
        "💀",
        "😂",
        "😘",
        "❤️",
        "😍",
        "🥰",
        "😎",
        "🤔",
        "😊",
        "🥳"
      ],
    ),
    EmojiCategory(
      name: "Activities",
      icon: "🎾",
      emojis: [
        "🎾",
        "🏐",
        "⚽",
        "🏀",
        "⚾",
        "🎯",
        "🎮",
        "🎭",
        "🎨",
        "🎬",
        "🎤",
        "🎧",
        "🎪"
      ],
    ),
    EmojiCategory(
      name: "Other",
      icon: "✨",
      emojis: [
        "✨",
        "🌴",
        "🧮",
        "🐹",
        "💬",
        "♋️",
        "⚔️",
        "💊",
        "🎁",
        "🔮",
        "💡",
        "📱",
        "💻"
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredEmojis {
    if (_searchQuery.isEmpty) {
      return _categories[_selectedCategoryIndex].emojis;
    } else {
      // Show emojis from all categories that match the search
      List<String> results = [];
      for (var category in _categories) {
        results.addAll(category.emojis);
      }
      return results; // In a real app, you'd implement actual search logic here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            "Select an Emoji",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Category selector
          if (_searchQuery.isEmpty)
            CategorySelector(
              categories: _categories,
              selectedIndex: _selectedCategoryIndex,
              onSelected: (index) {
                setState(() {
                  _selectedCategoryIndex = index;
                });
              },
            ),
          const SizedBox(height: 20),

          // Emoji grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _filteredEmojis.length,
              itemBuilder: (context, index) {
                return EmojiButton(
                  emoji: _filteredEmojis[index],
                  context: widget.parentContext,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Function to show emoji picker modal
Future<String?> showEmojiPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: EmojiPickerPage(parentContext: context),
      );
    },
  );
}

// Legacy function for compatibility
List<Widget> returnEmojiesButtons(context) {
  // Using the first category emojis for backward compatibility
  final drinks = ["🍸", "🍹", "🍺", "🍷", "🍾", "🍶", "🍵"];
  final travel = ["✈️", "🚀", "🚌", "🚙", "🏎️", "🚕", "🛵"];
  final faces = ["😃", "🤩", "👽", "💀", "😂", "😘", "❤️"];
  final activities = ["🎾", "🏐"];
  final other = ["✨", "🌴", "🧮", "🐹", "💬"];

  final allEmojis = [...drinks, ...travel, ...faces, ...activities, ...other];

  return allEmojis
      .map((emoji) => EmojiButton(emoji: emoji, context: context))
      .toList();
}
