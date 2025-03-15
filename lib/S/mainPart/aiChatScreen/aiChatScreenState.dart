import 'dart:convert';
import 'dart:io';

import 'package:bartender/S/mainPart/aiChatScreen/aiChatScreenModel.dart';
import 'package:bartender/mainSettings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Provider to store the thread ID for the assistant
final assistantThreadProvider = StateProvider<String?>((ref) => null);

// Provider for chat suggestions
final chatSuggestionsProvider = Provider<List<ChatSuggestion>>((ref) {
  return [
    ChatSuggestion(
      id: '1',
      text: 'Tell me a joke',
      icon: 'sentiment_satisfied',
    ),
    ChatSuggestion(
      id: '2',
      text: 'Write a poem about nature',
      icon: 'auto_stories',
    ),
    ChatSuggestion(
      id: '3',
      text: 'Give me a recipe idea',
      icon: 'restaurant',
    ),
    ChatSuggestion(
      id: '4',
      text: 'Explain quantum physics simply',
      icon: 'science',
    ),
  ];
});

// Provider for saved chats
final savedChatsProvider =
    StateNotifierProvider<SavedChatsNotifier, List<SavedChat>>((ref) {
  return SavedChatsNotifier();
});

class SavedChatsNotifier extends StateNotifier<List<SavedChat>> {
  SavedChatsNotifier() : super([]) {
    _loadSavedChats(); // Initial load
  }

  // Load saved chats - made public so it can be refreshed
  Future<void> loadSavedChats() async {
    await _loadSavedChats();
  }

  Future<void> _loadSavedChats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        print('Loading saved chats for user: ${user.uid}');
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedChats')
            .orderBy('timestamp', descending: true)
            .get();

        print('Loaded ${snapshot.docs.length} saved chats');
        final chats = snapshot.docs
            .map((doc) => SavedChat(
                  id: doc.id,
                  title: doc['title'],
                  timestamp: (doc['timestamp'] as Timestamp).toDate(),
                  threadId: doc['threadId'],
                  previewText: doc['previewText'] ?? '',
                ))
            .toList();

        state = chats;
      } catch (e) {
        print('Error loading saved chats: $e');
      }
    }
  }

  Future<void> saveChat(
      String threadId, String title, String previewText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final timestamp = DateTime.now();
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedChats')
            .add({
          'title': title,
          'threadId': threadId,
          'timestamp': Timestamp.fromDate(timestamp),
          'previewText': previewText,
        });

        final newChat = SavedChat(
          id: docRef.id,
          title: title,
          timestamp: timestamp,
          threadId: threadId,
          previewText: previewText,
        );

        state = [newChat, ...state];
      } catch (e) {
        print('Error saving chat: $e');
      }
    }
  }

  Future<void> deleteChat(String chatId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedChats')
            .doc(chatId)
            .delete();

        state = state.where((chat) => chat.id != chatId).toList();
      } catch (e) {
        print('Error deleting saved chat: $e');
      }
    }
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  String? _threadId;
  final ImagePicker _picker = ImagePicker();

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
      rethrow;
    }
  }

  void sendMessage(String message, String langMain) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final messageId = const Uuid().v4();
      final timestamp = Timestamp.now();

      await FirebaseFirestore.instance.collection('aichat').add({
        'uid': user.uid,
        'text': message,
        'isUser': true,
        'timestamp': timestamp,
        'messageId': messageId,
        'threadId': _threadId, // Add thread ID to messages
      });

      state = [
        ...state,
        ChatMessage(
          message,
          true,
          messageId: messageId,
          timestamp: timestamp.toDate(),
        )
      ];

      // Add AI writing indicator
      final writingIndicator =
          langMain == "tr" ? "Rakun yazıyor..." : "Raccon writing...";
      state = [...state, ChatMessage(writingIndicator, false)];

      // Send to Assistants API and get response
      _sendToAssistantAPI(message, langMain);
    }
  }

  // Add method to handle image uploads
  Future<void> uploadAndSendImage(String langMain) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedImage == null) return;

      final imageFile = File(pickedImage.path);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show upload placeholder
      final messageId = const Uuid().v4();
      final timestamp = Timestamp.now();
      final uploadingMessage =
          langMain == "tr" ? "Görsel yükleniyor..." : "Uploading image...";

      state = [
        ...state,
        ChatMessage(
          uploadingMessage,
          true,
          messageId: messageId,
          timestamp: timestamp.toDate(),
          isUploading: true,
        )
      ];

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(
          'chat_images/${user.uid}/${messageId}_${DateTime.now().millisecondsSinceEpoch}');

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() => null);
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Replace placeholder with actual message
      state = state.where((msg) => msg.messageId != messageId).toList();

      // Ask user for image description
      await _showImageDescriptionPrompt(
          imageUrl, messageId, timestamp.toDate(), langMain);
    } catch (e) {
      print('Error uploading image: $e');
      final errorMessage = langMain == "tr"
          ? "Görsel yüklenemedi. Lütfen tekrar deneyin."
          : "Failed to upload image. Please try again.";

      state = [
        ...state,
        ChatMessage(
          errorMessage,
          false,
          isError: true,
        )
      ];
    }
  }

  // Handle image description prompt
  Future<void> _showImageDescriptionPrompt(String imageUrl, String messageId,
      DateTime timestamp, String langMain) async {
    final emptyDescription =
        langMain == "tr" ? "[Görsel paylaşıldı]" : "[Image shared]";

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('aichat').add({
        'uid': user.uid,
        'text': emptyDescription,
        'isUser': true,
        'timestamp': Timestamp.fromDate(timestamp),
        'messageId': messageId,
        'imageUrl': imageUrl,
        'threadId': _threadId, // Add thread ID to messages
      });

      state = [
        ...state,
        ChatMessage(
          emptyDescription,
          true,
          messageId: messageId,
          timestamp: timestamp,
          imageUrl: imageUrl,
        )
      ];

      // Add AI writing indicator
      final writingIndicator =
          langMain == "tr" ? "Rakun yazıyor..." : "Raccon writing...";
      state = [...state, ChatMessage(writingIndicator, false)];

      // Send message to Assistant API
      sendImageMessage(emptyDescription, imageUrl, langMain);
    }
  }

  // Add method to send image messages
  void sendImageMessage(
      String message, String imageUrl, String langMain) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // AI is already set to respond from the previous step, we just need to
      // send the right prompt to the API

      // Fetch AI response with image context using Assistants API
      _sendToAssistantAPIWithImage(
          langMain == "tr"
              ? "Kullanıcı bir görsel paylaştı. Görsel URL'i: $imageUrl. Görsel hakkında yorum yap."
              : "User shared an image. Image URL: $imageUrl. Please comment on the image.",
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

  // Send message with image to Assistant API
  Future<void> _sendToAssistantAPIWithImage(
      String message, String langMain) async {
    try {
      if (_threadId == null) {
        await _initializeAssistantThread();
        if (_threadId == null) {
          throw Exception('Failed to initialize assistant thread');
        }
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('API Key is not set');
      }

      // Add message to the thread
      final assistantId = dotenv.env['OPENAI_ASSISTANT_ID'] ?? 'asst_ABC123';
      await _addMessageToThread(message, apiKey);

      // Run the assistant on the thread
      final runId = await _runAssistantOnThread(apiKey, assistantId, langMain);

      // Retrieve the response
      final response = await _waitForAssistantResponse(apiKey, runId);
      _updateUIWithResponse(response, langMain);
    } catch (e) {
      print('Error in _sendToAssistantAPIWithImage: $e');
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
      rethrow;
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
      rethrow;
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
      rethrow;
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

    // Add AI response to state with a message ID
    final messageId = const Uuid().v4();
    final timestamp = DateTime.now();

    state = [
      ...state,
      ChatMessage(
        response,
        false,
        messageId: messageId,
        timestamp: timestamp,
      )
    ];

    // Save to Firestore
    _saveResponseToFirestore(response, messageId, timestamp);
  }

  // Helper to save response to Firestore
  Future<void> _saveResponseToFirestore(
    String response,
    String messageId,
    DateTime timestamp,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('aichat').add({
        'uid': user.uid,
        'text': response,
        'isUser': false,
        'timestamp': Timestamp.fromDate(timestamp),
        'messageId': messageId,
        'threadId': _threadId, // Add thread ID to messages
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
    if (_threadId == null) {
      print('_loadMessagesFromFirestore: threadId is null, skipping load');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        print('Loading messages for thread: $_threadId');

        final querySnapshot = await FirebaseFirestore.instance
            .collection('aichat')
            .where('uid', isEqualTo: user.uid)
            .orderBy('timestamp')
            .get();

        // Filter by thread ID in application code for reliability
        final filteredDocs = querySnapshot.docs.where((doc) {
          final data = doc.data();
          return data.containsKey('threadId') && data['threadId'] == _threadId;
        }).toList();

        print('Found ${filteredDocs.length} messages for thread: $_threadId');

        if (filteredDocs.isEmpty) {
          return; // No messages to load
        }

        final messages = filteredDocs.map((doc) {
          // Get data from document as a Map
          final data = doc.data();

          return ChatMessage(
            data['text'],
            data['isUser'],
            messageId: data['messageId'],
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            // Safely access the imageUrl field, which may not exist
            imageUrl: data.containsKey('imageUrl') ? data['imageUrl'] : null,
            isError: false,
            // Safely access the reactions field, which may not exist
            reactions: data.containsKey('reactions')
                ? Map<String, bool>.from(data['reactions'])
                : null,
          );
        }).toList();

        // Sort by timestamp
        messages.sort((a, b) => (a.timestamp?.millisecondsSinceEpoch ?? 0)
            .compareTo(b.timestamp?.millisecondsSinceEpoch ?? 0));

        state = messages;
      } catch (e) {
        print('Error loading messages from Firestore: $e');
      }
    }
  }

  Future<void> deleteChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final batch = FirebaseFirestore.instance.batch();
      final querySnapshot = await FirebaseFirestore.instance
          .collection('aichat')
          .where('uid', isEqualTo: user.uid)
          .where('threadId',
              isEqualTo: _threadId) // Only delete current thread messages
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

  // New function to toggle message reaction
  Future<void> reactToMessage(String messageId, String reactionType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || messageId.isEmpty) return;

      // Find message in state
      final index = state.indexWhere((msg) => msg.messageId == messageId);
      if (index == -1) return;

      final message = state[index];

      // Toggle reaction
      Map<String, bool> updatedReactions = {...message.reactions ?? {}};
      updatedReactions[reactionType] =
          !(updatedReactions[reactionType] ?? false);

      // Update in state
      final updatedMessage = ChatMessage(
        message.text,
        message.isUser,
        messageId: message.messageId,
        timestamp: message.timestamp,
        imageUrl: message.imageUrl,
        isError: message.isError,
        reactions: updatedReactions,
      );

      List<ChatMessage> newState = [...state];
      newState[index] = updatedMessage;
      state = newState;

      // Update in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('aichat')
          .where('messageId', isEqualTo: messageId)
          .where('uid', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docRef = querySnapshot.docs.first.reference;
        await docRef.update({
          'reactions': updatedReactions,
        });
      }
    } catch (e) {
      print('Error reacting to message: $e');
    }
  }

  // Save current chat with a title
  Future<void> saveCurrentChat(String title, String langMain) async {
    try {
      if (_threadId == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get preview from last AI message
      String previewText = '';
      for (int i = state.length - 1; i >= 0; i--) {
        if (!state[i].isUser) {
          previewText = state[i].text;
          if (previewText.length > 100) {
            previewText = '${previewText.substring(0, 97)}...';
          }
          break;
        }
      }

      // Save to savedChats
      await _ref.read(savedChatsProvider.notifier).saveChat(
            _threadId!,
            title,
            previewText,
          );

      // Create a new thread for continuing chat
      await _createAssistantThread();
      state = [];

      // Show success message
      final successMessage = langMain == "tr"
          ? "Sohbet başarıyla kaydedildi!"
          : "Chat saved successfully!";

      state = [ChatMessage(successMessage, false)];
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  // Load a saved chat by thread ID
  Future<void> loadSavedChat(String threadId, String loadingMessage) async {
    try {
      // First clear the current state and show loading
      state = [ChatMessage(loadingMessage, false)];

      print('Loading saved chat with thread ID: $threadId');

      // Set the thread ID
      _threadId = threadId;
      _ref.read(assistantThreadProvider.notifier).state = threadId;

      // Save the thread ID to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('assistantThread')
            .set({'threadId': threadId});

        print('Updated thread ID in Firestore to: $threadId');

        // Fetch messages for this thread from Firestore
        try {
          // Query directly with threadId filter to improve performance
          final querySnapshot = await FirebaseFirestore.instance
              .collection('aichat')
              .where('uid', isEqualTo: user.uid)
              .where('threadId',
                  isEqualTo: threadId) // Filter by threadId in the query
              .orderBy('timestamp')
              .get();

          print(
              'Found ${querySnapshot.docs.length} messages with thread ID: $threadId');

          if (querySnapshot.docs.isEmpty) {
            // If the query found no messages, try a more flexible approach
            print(
                'No messages found with direct query, trying backup approach');

            final allMessagesSnapshot = await FirebaseFirestore.instance
                .collection('aichat')
                .where('uid', isEqualTo: user.uid)
                .orderBy('timestamp')
                .get();

            print(
                'Found ${allMessagesSnapshot.docs.length} total messages for user');

            // Filter manually in case threadId field is missing or has different format
            final filteredDocs = allMessagesSnapshot.docs.where((doc) {
              final data = doc.data();
              // More flexible check - looking for any field that might contain threadId
              return (data.containsKey('threadId') &&
                      data['threadId'] == threadId) ||
                  (data.toString().contains(threadId));
            }).toList();

            print(
                'Found ${filteredDocs.length} messages after manual filtering');

            if (filteredDocs.isEmpty) {
              // Only if both approaches find no messages, show empty message
              final currentLang = langMain;
              state = [
                ChatMessage(
                    currentLang == "tr"
                        ? "Sohbet kaydı boş görünüyor. Yeni bir sohbet başlatın."
                        : "This chat history appears to be empty. Start a new conversation.",
                    false)
              ];
              return;
            }

            // Process messages from backup approach
            final messages = _processMessagesFromDocs(filteredDocs);
            state = messages;
            print('Loaded ${messages.length} messages using backup approach');
            return;
          }

          // Process messages from direct query approach
          final messages = _processMessagesFromDocs(querySnapshot.docs);

          // Update state with fetched messages
          state = messages;
          print('Loaded ${messages.length} messages for thread: $threadId');
        } catch (e) {
          print('Error fetching messages: $e');
          state = [
            ChatMessage("Error loading messages: $e", false, isError: true)
          ];
        }
      }
    } catch (e) {
      print('Error in loadSavedChat: $e');
      state = [
        ChatMessage("Error loading saved chat: $e", false, isError: true)
      ];
    }
  }

  // Helper method to process message documents into ChatMessage objects
  List<ChatMessage> _processMessagesFromDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final messages = docs.map((doc) {
      final data = doc.data();

      return ChatMessage(
        data['text'],
        data['isUser'],
        messageId: data['messageId'],
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        imageUrl: data.containsKey('imageUrl') ? data['imageUrl'] : null,
        isError: false,
        reactions: data.containsKey('reactions')
            ? Map<String, bool>.from(data['reactions'])
            : null,
      );
    }).toList();

    // Sort messages by timestamp to ensure correct order
    messages.sort((a, b) => (a.timestamp?.millisecondsSinceEpoch ?? 0)
        .compareTo(b.timestamp?.millisecondsSinceEpoch ?? 0));

    return messages;
  }

  // Helper method to determine language
  String get langMain {
    try {
      return _ref.read(lang);
    } catch (e) {
      return "en"; // Default to English if provider not available
    }
  }
}
