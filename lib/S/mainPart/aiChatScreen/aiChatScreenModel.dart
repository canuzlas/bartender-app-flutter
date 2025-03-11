class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? messageId;
  final DateTime? timestamp;
  final String? imageUrl;
  final bool isUploading;
  final Map<String, bool>? reactions;

  ChatMessage(
    this.text,
    this.isUser, {
    this.isError = false,
    this.messageId,
    this.timestamp,
    this.imageUrl,
    this.isUploading = false,
    this.reactions,
  });
}

class ChatSuggestion {
  final String id;
  final String text;
  final String icon;

  ChatSuggestion({
    required this.id,
    required this.text,
    required this.icon,
  });
}

class SavedChat {
  final String id;
  final String title;
  final DateTime timestamp;
  final String threadId;
  final String previewText;

  SavedChat({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.threadId,
    required this.previewText,
  });
}
