class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? messageId;
  final DateTime? timestamp;
  final String? imageUrl; // Add image URL property

  ChatMessage(
    this.text,
    this.isUser, {
    this.isError = false,
    this.messageId,
    this.timestamp,
    this.imageUrl, // Include in constructor
  });
}
