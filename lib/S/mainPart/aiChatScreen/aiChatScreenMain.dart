import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenState.dart';
import 'package:bartender/mainSettings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatScreenMain extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatMessages = ref.watch(chatProvider);
    final TextEditingController _controller = TextEditingController();
    final ScrollController _scrollController = ScrollController();
    final darkThemeMain = ref.watch(darkTheme);
    final langMain = ref.watch(lang);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });

    ref.listen<List<ChatMessage>>(chatProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
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
        actions: [
          IconButton(
            icon: Icon(Icons.delete,
                color: darkThemeMain ? Colors.red : Colors.red),
            onPressed: () {
              ref.read(chatProvider.notifier).deleteChat();
            },
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
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 3, horizontal: 5),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? (darkThemeMain
                                ? Colors.orangeAccent
                                : Colors.deepOrange)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: message.isUser
                              ? Radius.circular(12)
                              : Radius.circular(0),
                          bottomRight: message.isUser
                              ? Radius.circular(0)
                              : Radius.circular(12),
                        ),
                      ),
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                message.text,
                                style: TextStyle(
                                    color: message.isUser
                                        ? Colors.white
                                        : Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: langMain == "tr"
                            ? 'Bir mesaj yazın...'
                            : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    color:
                        darkThemeMain ? Colors.orangeAccent : Colors.deepOrange,
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(_controller.text, langMain);
                        _controller.clear();
                      }
                    },
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
