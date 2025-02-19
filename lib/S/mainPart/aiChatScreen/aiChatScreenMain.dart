import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenState.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatScreenMain extends ConsumerWidget {
  const AiChatScreenMain({Key? key}) : super(key: key);

  // New helper method to build a message bubble.
  Widget _buildMessageBubble(ChatMessage message, bool darkThemeMain) => Align(
        alignment:
            message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: message.isUser
                ? (darkThemeMain ? Colors.orangeAccent : Colors.deepOrange)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ),
      );

  // New helper method to build the chat input area.
  Widget _buildChatInput(BuildContext context, TextEditingController controller,
          bool darkThemeMain, String langMain, WidgetRef ref) =>
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: langMain == "tr"
                      ? 'Bir mesaj yazın...'
                      : 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  ref
                      .read(chatProvider.notifier)
                      .sendMessage(controller.text, langMain);
                  controller.clear();
                }
              },
              child: const Icon(Icons.send),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatMessages = ref.watch(chatProvider);
    final TextEditingController _controller = TextEditingController();
    final ScrollController _scrollController = ScrollController();
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    ref.listen<List<ChatMessage>>(chatProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          langMain == "tr" ? "Rakun Yapay Zeka" : 'Raccon Chat Assistant',
          style: TextStyle(color: darkThemeMain ? Colors.white : Colors.black),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.deepPurpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => ref.read(chatProvider.notifier).deleteChat(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: chatMessages.length,
                itemBuilder: (context, index) {
                  final message = chatMessages[index];
                  return _buildMessageBubble(message, darkThemeMain);
                },
              ),
            ),
            _buildChatInput(context, _controller, darkThemeMain, langMain, ref),
          ],
        ),
      ),
    );
  }
}
