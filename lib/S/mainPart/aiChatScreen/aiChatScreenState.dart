import 'dart:convert';
import 'dart:io';

import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]) {
    _loadMessagesFromFirestore();
  }

  void sendMessage(String message, String langMain) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final timestamp = Timestamp.now();
      await FirebaseFirestore.instance.collection('aichat').add({
        'uid': user.uid,
        'text': message,
        'isUser': true,
        'timestamp': timestamp,
      });
      state = [...state, ChatMessage(message, true)];
      // Add AI writing indicator
      final writingIndicator =
          langMain == "tr" ? "Yapay Zeka yazıyor..." : "AI is writing...";
      state = [...state, ChatMessage(writingIndicator, false)];
      // Fetch AI response
      _fetchAIResponse(message, langMain);
    }
  }

  Future<void> _fetchAIResponse(String message, String langMain) async {
    try {
      final apiUrl = dotenv.env['OPENAI_API_URL'];
      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiUrl == null || apiKey == null) {
        throw Exception('API URL or API Key is not set');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': message}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final aiResponse = jsonResponse['choices'][0]['message']['content'];
        state = state.sublist(0, state.length - 1);
        state = [...state, ChatMessage(aiResponse, false)];
        // Save AI response to Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('aichat').add({
            'uid': user.uid,
            'text': aiResponse,
            'isUser': false,
            'timestamp': Timestamp.now(),
          });
        }
      } else {
        throw Exception('Failed to get AI response: ${response.body}');
      }
    } catch (e) {
      // Handle error
      print('Error fetching AI response: $e');
      state = state.sublist(0, state.length - 1);
      final errorMessage = langMain == "tr"
          ? "Hata: Yanıt alınamadı"
          : "Error: Unable to get response";
      state = [...state, ChatMessage(errorMessage, false)];
    }
  }

  Future<void> _loadMessagesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('aichat')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp')
          .get();
      final messages = querySnapshot.docs.map((doc) {
        return ChatMessage(doc['text'], doc['isUser']);
      }).toList();
      state = messages;
    }
  }

  Future<void> deleteChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('aichat')
          .where('uid', isEqualTo: user.uid)
          .get();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      state = [];
    }
  }
}
