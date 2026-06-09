import 'package:cloud_firestore/cloud_firestore.dart';

import 'assistant_chat_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

/// Persists assistant chat messages in the Firestore `assistantHistory` collection.
class AssistantHistoryService {
  AssistantHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const collectionName = 'assistantHistory';

  final FirebaseFirestore _firestore;

  Future<List<ChatMessage>> loadMessages(String userId) async {
    // Filter by userId only — avoids needing a composite Firestore index.
    // Sort by createdAt in memory instead of orderBy in the query.
    final snapshot = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();

    final docs = snapshot.docs.toList()
      ..sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return -1;
        if (bTime == null) return 1;
        return aTime.compareTo(bTime);
      });

    return docs
        .map((doc) {
          final data = doc.data();
          final rawText = data['text'] as String? ?? '';
          final isUser = data['isUser'] as bool? ?? false;
          final text = isUser ? rawText : AssistantChatService.stripThinking(rawText);
          return ChatMessage(text: text, isUser: isUser);
        })
        .where((message) => message.text.trim().isNotEmpty)
        .toList();
  }

  Future<void> saveMessage({
    required String userId,
    required String text,
    required bool isUser,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _firestore.collection(collectionName).add({
      'userId': userId,
      'text': trimmed,
      'isUser': isUser,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
