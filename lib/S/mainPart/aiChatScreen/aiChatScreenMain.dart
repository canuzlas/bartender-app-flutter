import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenState.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class AiChatScreenMain extends ConsumerStatefulWidget {
  const AiChatScreenMain({super.key});

  @override
  ConsumerState<AiChatScreenMain> createState() => _AiChatScreenMainState();
}

class _AiChatScreenMainState extends ConsumerState<AiChatScreenMain> {
  late ScrollController _scrollController;
  late TextEditingController _controller;
  bool _showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = TextEditingController();

    // Ensure we initialize the scroll controller correctly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Helper method for scrolling to bottom
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  // Enhanced message bubble with image support
  Widget _buildMessageBubble(ChatMessage message, bool darkThemeMain) {
    // Check if this is a typing indicator message
    if (message.text == "Rakun yazıyor..." ||
        message.text == "Raccon writing...") {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: darkThemeMain
                ? const Color(0xFF424242)
                : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypingIndicator(darkThemeMain),
            ],
          ),
        ),
      );
    }

    // Error message with different styling
    if (message.isError == true) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: darkThemeMain ? Colors.red[900] : Colors.red[50],
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: darkThemeMain ? Colors.redAccent : Colors.red,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: darkThemeMain ? Colors.white : Colors.red[800],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // Message with image
    if (message.imageUrl != null) {
      return Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: message.isUser
                ? (darkThemeMain
                    ? const Color(0xFFFF9800)
                    : const Color(0xFFE65100))
                : (darkThemeMain
                    ? const Color(0xFF424242)
                    : const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Image.network(
                  message.imageUrl!,
                  width: 280,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      width: 280,
                      color:
                          darkThemeMain ? Colors.grey[800] : Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color:
                              darkThemeMain ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      width: 280,
                      color:
                          darkThemeMain ? Colors.grey[800] : Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.error_outline,
                          color:
                              darkThemeMain ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : (darkThemeMain ? Colors.white : Colors.black87),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              // Add message actions for images
              if (!message.isUser && message.messageId != null)
                _buildMessageActions(message, darkThemeMain),
            ],
          ),
        ),
      );
    }

    // Regular message bubble
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: message.isUser
              ? (darkThemeMain
                  ? const Color(0xFFFF9800)
                  : const Color(0xFFE65100))
              : (darkThemeMain
                  ? const Color(0xFF424242)
                  : const Color(0xFFEEEEEE)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser
                    ? Colors.white
                    : (darkThemeMain ? Colors.white : Colors.black87),
                fontSize: 16,
                height: 1.4,
              ),
            ),
            // Only show actions for non-user, non-error messages
            if (!message.isUser &&
                message.messageId != null &&
                !message.isError)
              _buildMessageActions(message, darkThemeMain),
          ],
        ),
      ),
    );
  }

  // Message action buttons (thumbs up/down, copy, share, bookmark)
  Widget _buildMessageActions(ChatMessage message, bool darkThemeMain) {
    final String langMain = ref.watch(lang);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbs up
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              message.reactions?.containsKey('thumbsUp') == true &&
                      message.reactions?['thumbsUp'] == true
                  ? Icons.thumb_up
                  : Icons.thumb_up_outlined,
              size: 16,
              color: message.reactions?.containsKey('thumbsUp') == true &&
                      message.reactions?['thumbsUp'] == true
                  ? Colors.blue
                  : darkThemeMain
                      ? Colors.white70
                      : Colors.black54,
            ),
            onPressed: () {
              if (message.messageId != null) {
                ref
                    .read(chatProvider.notifier)
                    .reactToMessage(message.messageId!, 'thumbsUp');
              }
            },
          ),
          const SizedBox(width: 8),
          // Thumbs down
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              message.reactions?.containsKey('thumbsDown') == true &&
                      message.reactions?['thumbsDown'] == true
                  ? Icons.thumb_down
                  : Icons.thumb_down_outlined,
              size: 16,
              color: message.reactions?.containsKey('thumbsDown') == true &&
                      message.reactions?['thumbsDown'] == true
                  ? Colors.red
                  : darkThemeMain
                      ? Colors.white70
                      : Colors.black54,
            ),
            onPressed: () {
              if (message.messageId != null) {
                ref
                    .read(chatProvider.notifier)
                    .reactToMessage(message.messageId!, 'thumbsDown');
              }
            },
          ),
          const SizedBox(width: 12),
          // Copy text
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.copy_outlined,
              size: 16,
              color: darkThemeMain ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message.text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    langMain == "tr"
                        ? 'Mesaj panoya kopyalandı'
                        : 'Message copied to clipboard',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.black87,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Share
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.share_outlined,
              size: 16,
              color: darkThemeMain ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              Share.share(message.text);
            },
          ),
          const SizedBox(width: 12),
          // Bookmark
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              message.reactions?.containsKey('bookmark') == true &&
                      message.reactions?['bookmark'] == true
                  ? Icons.bookmark
                  : Icons.bookmark_border_outlined,
              size: 16,
              color: message.reactions?.containsKey('bookmark') == true &&
                      message.reactions?['bookmark'] == true
                  ? Colors.amber
                  : darkThemeMain
                      ? Colors.white70
                      : Colors.black54,
            ),
            onPressed: () {
              if (message.messageId != null) {
                ref
                    .read(chatProvider.notifier)
                    .reactToMessage(message.messageId!, 'bookmark');
              }
            },
          ),
        ],
      ),
    );
  }

  // Chat suggestions widget
  Widget _buildChatSuggestions(bool darkThemeMain) {
    final suggestions = ref.watch(chatSuggestionsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showSuggestions ? 60 : 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  _controller.text = suggestion.text;
                  setState(() {
                    _showSuggestions = false;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        darkThemeMain ? const Color(0xFF333333) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          darkThemeMain ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getIconData(suggestion.icon),
                        size: 16,
                        color:
                            darkThemeMain ? Colors.orange : Colors.deepOrange,
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 120,
                        child: Text(
                          suggestion.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                darkThemeMain ? Colors.white : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helper to convert string to IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'sentiment_satisfied':
        return Icons.sentiment_satisfied_alt_outlined;
      case 'auto_stories':
        return Icons.auto_stories_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'science':
        return Icons.science_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  // Typing indicator animation
  Widget _buildTypingIndicator(bool darkTheme) {
    return Row(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: _DotTypingIndicator(
            position: index,
            color: darkTheme ? Colors.white70 : Colors.black54,
          ),
        );
      }),
    );
  }

  // Enhanced chat input with modern styling and image upload button
  Widget _buildChatInput(bool darkThemeMain, String langMain) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: darkThemeMain ? const Color(0xFF212121) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            // Image upload button
            IconButton(
              icon: Icon(
                Icons.photo_outlined,
                color: darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              ),
              onPressed: () {
                ref.read(chatProvider.notifier).uploadAndSendImage(langMain);
              },
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(
                  color: darkThemeMain ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
                onChanged: (text) {
                  // Show suggestions when input is empty
                  if (text.isEmpty && !_showSuggestions) {
                    setState(() {
                      _showSuggestions = true;
                    });
                  } else if (text.isNotEmpty && _showSuggestions) {
                    setState(() {
                      _showSuggestions = false;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: langMain == "tr"
                      ? 'Bir mesaj yazın...'
                      : 'Type a message...',
                  hintStyle: TextStyle(
                    color: darkThemeMain ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: darkThemeMain
                      ? const Color(0xFF333333)
                      : const Color(0xFFF5F5F5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: darkThemeMain
                          ? Colors.orangeAccent
                          : Colors.deepOrange,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: darkThemeMain
                      ? [Colors.orangeAccent, Colors.orange.shade800]
                      : [Colors.deepOrange, Colors.deepOrange.shade700],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (darkThemeMain
                            ? Colors.orangeAccent
                            : Colors.deepOrange)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    if (_controller.text.isNotEmpty) {
                      ref
                          .read(chatProvider.notifier)
                          .sendMessage(_controller.text, langMain);
                      _controller.clear();
                      setState(() {
                        _showSuggestions = true;
                      });
                      // Add a small delay before scrolling
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _scrollToBottom();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final chatMessages = ref.watch(chatProvider);
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    // Listen for chat updates and scroll to bottom
    ref.listen<List<ChatMessage>>(chatProvider, (previous, current) {
      // Schedule scrolling after the frame is built
      if (previous == null || previous.length != current.length) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollToBottom();
        });
      }
    });

    return Scaffold(
      backgroundColor:
          darkThemeMain ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          langMain == "tr" ? "Rakun Yapay Zeka" : 'Raccon Chat Assistant',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A237E), // Deep blue
                Color(0xFF7B1FA2), // Deep purple
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Save chat button
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            tooltip: langMain == "tr" ? "Sohbeti Kaydet" : "Save Chat",
            onPressed: () => _showSaveChatDialog(langMain, darkThemeMain),
          ),
          // Clear chat button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon:
                  const Icon(Icons.delete_outline_rounded, color: Colors.white),
              tooltip: langMain == "tr" ? "Sohbeti Temizle" : "Clear Chat",
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    langMain == "tr" ? "Sohbeti Temizle" : "Clear Chat",
                  ),
                  content: Text(
                    langMain == "tr"
                        ? "Tüm mesajlar silinecek. Emin misiniz?"
                        : "All messages will be deleted. Are you sure?",
                  ),
                  actions: [
                    TextButton(
                      child: Text(
                        langMain == "tr" ? "İptal" : "Cancel",
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: Text(
                        langMain == "tr" ? "Temizle" : "Clear",
                        style: const TextStyle(color: Colors.red),
                      ),
                      onPressed: () {
                        ref.read(chatProvider.notifier).deleteChat();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Show suggestions at the top when there are messages
            if (chatMessages.isNotEmpty) _buildChatSuggestions(darkThemeMain),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  // Keep track of scroll position to detect user scroll events
                  return false;
                },
                child: chatMessages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 80,
                              color: darkThemeMain
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              langMain == "tr"
                                  ? "Yapay zeka ile sohbete başlayın!"
                                  : "Start chatting with AI!",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: darkThemeMain
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Show suggestions when empty
                            _buildChatSuggestions(darkThemeMain),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                            top: 16, left: 8, right: 8, bottom: 20),
                        itemCount: chatMessages.length,
                        itemBuilder: (context, index) {
                          final message = chatMessages[index];
                          return _buildMessageBubble(message, darkThemeMain);
                        },
                      ),
              ),
            ),
            _buildChatInput(darkThemeMain, langMain),
          ],
        ),
      ),
      // Scroll to bottom button
      floatingActionButton: chatMessages.length > 5
          ? FloatingActionButton(
              mini: true,
              backgroundColor:
                  darkThemeMain ? Colors.orange : Colors.deepOrange,
              onPressed: () => _scrollToBottom(),
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            )
          : null,
    );
  }

  // Save chat dialog
  void _showSaveChatDialog(String langMain, bool darkThemeMain) {
    final TextEditingController titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkThemeMain ? const Color(0xFF333333) : Colors.white,
        title: Text(
          langMain == "tr" ? 'Sohbeti Kaydet' : 'Save Chat',
          style: TextStyle(
            color: darkThemeMain ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: TextStyle(
            color: darkThemeMain ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: langMain == "tr" ? 'Sohbet başlığı' : 'Chat title',
            hintStyle: TextStyle(
              color: darkThemeMain ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              langMain == "tr" ? 'İptal' : 'Cancel',
              style: TextStyle(
                color: darkThemeMain ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: Text(langMain == "tr" ? 'Kaydet' : 'Save'),
            onPressed: () {
              String title = titleController.text.trim();
              if (title.isEmpty) {
                title = langMain == "tr" ? 'Adsız Sohbet' : 'Untitled Chat';
              }
              ref.read(chatProvider.notifier).saveCurrentChat(title, langMain);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// Custom dot typing indicator animation
class _DotTypingIndicator extends StatefulWidget {
  final int position;
  final Color color;

  const _DotTypingIndicator({
    super.key,
    required this.position,
    required this.color,
  });

  @override
  State<_DotTypingIndicator> createState() => _DotTypingIndicatorState();
}

class _DotTypingIndicatorState extends State<_DotTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 20.0,
      ),
    ]).animate(_controller);

    // Offset the start of animation based on position
    Future.delayed(Duration(milliseconds: widget.position * 180), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6 + (8 * _animation.value),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      },
    );
  }
}
