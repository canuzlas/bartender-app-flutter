import 'dart:convert';
import 'dart:io';

import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as Math;

// Provider to store the thread ID for the assistant
final assistantThreadProvider = StateProvider<String?>((ref) => null);

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  String? _threadId;

  ChatNotifier(this._ref) : super([]) {
    _loadMessagesFromFirestore();
    _initializeAssistantThread();
  }

  // Initialize assistant thread
  Future<void> _initializeAssistantThread() async {
    // Check if we already have a stored thread ID (could be stored in shared prefs or similar)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Try to get thread ID from Firestore
        final threadDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('assistantThread')
            .get();

        if (threadDoc.exists && threadDoc.data()?['threadId'] != null) {
          _threadId = threadDoc.data()?['threadId'];
          _ref.read(assistantThreadProvider.notifier).state = _threadId;
          print('Retrieved existing thread ID: $_threadId');
        } else {
          // Create a new thread
          await _createAssistantThread();
        }
      } catch (e) {
        print('Error initializing thread: $e');
        await _createAssistantThread();
      }
    }
  }

  // Create a new assistant thread
  Future<void> _createAssistantThread() async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('API Key is not set');
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/threads'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Beta': 'assistants=v2', // Updated to v2
        },
        body: jsonEncode({}),
      );

      if (response.statusCode != 200) {
        print(
            'API error creating thread: ${response.statusCode}: ${response.body}');
        throw Exception('Failed to create assistant thread: ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _threadId = data['id'];
      _ref.read(assistantThreadProvider.notifier).state = _threadId;
      print('Created new thread ID: $_threadId');

      // Store the thread ID in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('assistantThread')
            .set({'threadId': _threadId});
      }
    } catch (e) {
      print('Error creating assistant thread: $e');
      throw e;
    }
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

      // Send to Assistants API and get response
      _sendToAssistantAPI(message, langMain);
    }
  }

  // Add method to send image messages
  void sendImageMessage(String message, String langMain) async {
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

      // Fetch AI response with image context using Assistants API
      _sendToAssistantAPI(
          langMain == "tr"
              ? "Kullanıcı bir görsel paylaştı. Görsel hakkında: $message"
              : "User shared an image. About the image: $message",
          langMain);
    }
  }

  // Send message to Assistant API and get response
  Future<void> _sendToAssistantAPI(String message, String langMain) async {
    try {
      if (_threadId == null) {
        // If no thread ID, try to initialize
        await _initializeAssistantThread();
        if (_threadId == null) {
          throw Exception('Failed to initialize assistant thread');
        }
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('API Key is not set');
      }

      // 1. Add message to the thread
      final assistantId = dotenv.env['OPENAI_ASSISTANT_ID'] ??
          'asst_ABC123'; // Replace with your actual assistant ID
      await _addMessageToThread(message, apiKey);

      // 2. Run the assistant on the thread
      final runId = await _runAssistantOnThread(apiKey, assistantId, langMain);

      // 3. Retrieve the response
      final response = await _waitForAssistantResponse(apiKey, runId);
      _updateUIWithResponse(response, langMain);
    } catch (e) {
      print('Error in _sendToAssistantAPI: $e');
      _showErrorMessage(langMain);
    }
  }

  // Add a message to the thread
  Future<void> _addMessageToThread(String message, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/threads/$_threadId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Beta': 'assistants=v2', // Updated to v2
        },
        body: jsonEncode({
          'role': 'user',
          'content': message,
        }),
      );

      if (response.statusCode != 200) {
        print(
            'API error adding message: ${response.statusCode}: ${response.body}');
        throw Exception('Failed to add message to thread: ${response.body}');
      }
    } catch (e) {
      print('Error adding message to thread: $e');
      throw e;
    }
  }

  // Run the assistant on the thread
  Future<String> _runAssistantOnThread(
      String apiKey, String assistantId, String langMain) async {
    try {
      final instructions = langMain == "tr"
          ? "Sen Rakun adlı bir yapay zeka sohbet asistanısın. Dost canlısı, esprili ve yardımcı ol. Daima Türkçe yanıt ver. Kendini asla bir yapay zeka veya AI olarak tanıtma, sadece bir arkadaşla konuşur gibi davran."
          : "You are Raccoon, an AI chat assistant. Be friendly, witty, and helpful. Never introduce yourself as an AI or assistant. Just talk like you're chatting with a friend.";

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/threads/$_threadId/runs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Beta': 'assistants=v2', // Updated to v2
        },
        body: jsonEncode({
          'assistant_id': assistantId,
          'instructions': instructions,
        }),
      );

      if (response.statusCode != 200) {
        print(
            'API error running assistant: ${response.statusCode}: ${response.body}');
        throw Exception('Failed to run assistant: ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['id'];
    } catch (e) {
      print('Error running assistant: $e');
      throw e;
    }
  }

  // Wait for and retrieve the assistant's response
  Future<String> _waitForAssistantResponse(String apiKey, String runId) async {
    bool isCompleted = false;
    int attempts = 0;
    const maxAttempts = 30; // Maximum wait time = 30 * 2 seconds = 1 minute

    try {
      while (!isCompleted && attempts < maxAttempts) {
        attempts++;

        // Check run status
        final statusResponse = await http.get(
          Uri.parse('https://api.openai.com/v1/threads/$_threadId/runs/$runId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'OpenAI-Beta': 'assistants=v2', // Updated to v2
          },
        );

        if (statusResponse.statusCode != 200) {
          print(
              'API error checking run status: ${statusResponse.statusCode}: ${statusResponse.body}');
          throw Exception('Failed to check run status: ${statusResponse.body}');
        }

        final statusData = jsonDecode(utf8.decode(statusResponse.bodyBytes));
        final runStatus = statusData['status'];

        if (runStatus == 'completed') {
          isCompleted = true;
        } else if (runStatus == 'failed' ||
            runStatus == 'cancelled' ||
            runStatus == 'expired') {
          throw Exception('Assistant run failed with status: $runStatus');
        } else {
          // Wait before checking again
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!isCompleted) {
        throw Exception('Assistant response timed out');
      }

      // Retrieve messages after completion
      final messagesResponse = await http.get(
        Uri.parse('https://api.openai.com/v1/threads/$_threadId/messages'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'OpenAI-Beta': 'assistants=v2', // Updated to v2
        },
      );

      if (messagesResponse.statusCode != 200) {
        print(
            'API error retrieving messages: ${messagesResponse.statusCode}: ${messagesResponse.body}');
        throw Exception(
            'Failed to retrieve messages: ${messagesResponse.body}');
      }

      final messagesData = jsonDecode(utf8.decode(messagesResponse.bodyBytes));
      final messages = messagesData['data'];

      // Get the latest assistant message
      for (var message in messages) {
        if (message['role'] == 'assistant') {
          // Assuming content is a list of content blocks
          if (message['content'] != null && message['content'].isNotEmpty) {
            // Extract text from content blocks
            final textContent = message['content'][0]['text']['value'];
            return textContent;
          }
        }
      }

      throw Exception('No assistant message found');
    } catch (e) {
      print('Error waiting for assistant response: $e');
      throw e;
    }
  }

  // Helper to update UI with AI response
  void _updateUIWithResponse(String response, String langMain) {
    // Remove typing indicator
    final writingIndicator =
        langMain == "tr" ? "Rakun yazıyor..." : "Raccon writing...";
    if (state.isNotEmpty && state.last.text == writingIndicator) {
      state = state.sublist(0, state.length - 1);
    }

    // Add AI response to state
    state = [...state, ChatMessage(response, false)];

    // Save to Firestore
    _saveResponseToFirestore(response);
  }

  // Helper to save response to Firestore
  Future<void> _saveResponseToFirestore(
    String response,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('aichat').add({
        'uid': user.uid,
        'text': response,
        'isUser': false,
        'timestamp': Timestamp.now(),
      });
    }
  }

  // Helper to show error message
  void _showErrorMessage(String langMain) {
    // Remove typing indicator
    final writingIndicator =
        langMain == "tr" ? "Rakun yazıyor..." : "Raccon writing...";
    if (state.isNotEmpty && state.last.text == writingIndicator) {
      state = state.sublist(0, state.length - 1);
    }

    final errorMessage = langMain == "tr"
        ? "Hata: Yanıt alınamadı. Lütfen daha sonra tekrar deneyin."
        : "Error: Unable to get response. Please try again later.";
    state = [...state, ChatMessage(errorMessage, false, isError: true)];
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
        return ChatMessage(
          doc['text'],
          doc['isUser'],
        );
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

      // When deleting chat, also create a new thread
      await _createAssistantThread();
    }
  }
}
