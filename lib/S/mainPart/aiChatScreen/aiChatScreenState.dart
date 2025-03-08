import 'dart:convert';
import 'dart:io';

import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as Math;

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
          langMain == "tr" ? "Rakun yazıyor..." : "Raccon writing...";
      state = [...state, ChatMessage(writingIndicator, false)];
      // Fetch AI response
      _fetchAIResponse(message, langMain);
    }
  }

  Future<void> _fetchAIResponse(String message, String langMain) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      final assistantId = dotenv.env['OPENAI_ASSISTANT_ID'];

      if (apiKey == null || assistantId == null) {
        throw Exception('API Key or Assistant ID is not set');
      }

      final baseUrl = 'https://api.openai.com/v1';
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'OpenAI-Beta': 'assistants=v2'
      };

      print('Creating thread...');
      // Step 1: Create a thread
      final threadResponse = await http.post(
        Uri.parse('$baseUrl/threads'),
        headers: headers,
        body: jsonEncode({}),
      );

      if (threadResponse.statusCode != 200) {
        throw Exception('Failed to create thread: ${threadResponse.body}');
      }

      final threadData = jsonDecode(utf8.decode(threadResponse.bodyBytes));
      final threadId = threadData['id'];
      print('Thread created: $threadId');

      // Step 2: Add a message to the thread
      print('Adding message to thread...');
      final messageResponse = await http.post(
        Uri.parse('$baseUrl/threads/$threadId/messages'),
        headers: headers,
        body: jsonEncode({'role': 'user', 'content': message}),
      );

      if (messageResponse.statusCode != 200) {
        throw Exception('Failed to add message: ${messageResponse.body}');
      }
      print('Message added successfully');

      // Step 3: Run the assistant
      print('Running the assistant...');
      final runResponse = await http.post(
        Uri.parse('$baseUrl/threads/$threadId/runs'),
        headers: headers,
        body: jsonEncode({'assistant_id': assistantId}),
      );

      if (runResponse.statusCode != 200) {
        throw Exception('Failed to start run: ${runResponse.body}');
      }

      final runData = jsonDecode(utf8.decode(runResponse.bodyBytes));
      final runId = runData['id'];
      print('Run started with ID: $runId');

      // Step 4: Poll for completion
      String runStatus = runData['status'];
      print('Initial run status: $runStatus');

      // Poll until the run completes or fails
      while (runStatus == 'queued' || runStatus == 'in_progress') {
        // Wait before polling again
        await Future.delayed(const Duration(seconds: 2));

        print('Checking run status...');
        final checkResponse = await http.get(
          Uri.parse('$baseUrl/threads/$threadId/runs/$runId'),
          headers: headers,
        );

        if (checkResponse.statusCode != 200) {
          throw Exception('Failed to check run status: ${checkResponse.body}');
        }

        final checkData = jsonDecode(utf8.decode(checkResponse.bodyBytes));
        runStatus = checkData['status'];
        print('Current status: $runStatus');

        if (runStatus == 'failed' ||
            runStatus == 'cancelled' ||
            runStatus == 'expired') {
          final error = checkData['last_error'] ?? 'Unknown error';
          throw Exception('Assistant run $runStatus: $error');
        }
      }

      // Step 5: Get messages
      print('Retrieving messages...');
      final messagesResponse = await http.get(
        Uri.parse('$baseUrl/threads/$threadId/messages'),
        headers: headers,
      );

      if (messagesResponse.statusCode != 200) {
        throw Exception('Failed to get messages: ${messagesResponse.body}');
      }

      final messagesData = jsonDecode(utf8.decode(messagesResponse.bodyBytes));
      final messages = messagesData['data'];
      print('Retrieved ${messages.length} messages');

      // Process assistant messages
      String aiResponse = '';
      for (var message in messages) {
        if (message['role'] == 'assistant') {
          // Extract text from content array
          final contentList = message['content'];
          for (var content in contentList) {
            if (content['type'] == 'text') {
              aiResponse = content['text']['value'];
              break;
            }
          }
          if (aiResponse.isNotEmpty) {
            print(
                'Found assistant response: ${aiResponse.substring(0, Math.min(50, aiResponse.length))}...');
            break;
          }
        }
      }

      if (aiResponse.isEmpty) {
        throw Exception('No assistant response found in messages');
      }

      // Update UI with response
      state = state.sublist(0, state.length - 1); // Remove writing indicator
      state = [...state, ChatMessage(aiResponse, false)];

      // Save to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('aichat').add({
          'uid': user.uid,
          'text': aiResponse,
          'isUser': false,
          'timestamp': Timestamp.now(),
        });
      }

      print('AI response processing completed successfully');
    } catch (e) {
      print('Error in _fetchAIResponse: $e');
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
