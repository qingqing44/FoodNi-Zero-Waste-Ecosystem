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

  Future<void> clearHistory(String userId) async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Stores one complete chat session in a single document so it can be
  /// reviewed, continued, or deleted independently.
  Future<String> saveConversation({
    String? conversationId,
    required String userId,
    required List<ChatMessage> messages,
  }) async {
    final meaningfulMessages = messages
        .where((message) => message.text.trim().isNotEmpty)
        .toList();
    final firstQuestion = meaningfulMessages.cast<ChatMessage?>().firstWhere(
          (message) => message?.isUser ?? false,
          orElse: () => null,
        );
    if (firstQuestion == null) return conversationId ?? '';

    final doc = conversationId == null
        ? _firestore.collection(collectionName).doc()
        : _firestore.collection(collectionName).doc(conversationId);
    await doc.set({
      'userId': userId,
      'title': firstQuestion.text.trim(),
      'messages': meaningfulMessages
          .map((message) => {'text': message.text, 'isUser': message.isUser})
          .toList(),
      'messageCount': meaningfulMessages.length,
      'lastAnswer': meaningfulMessages.isEmpty ? '' : meaningfulMessages.last.text,
      'updatedAt': FieldValue.serverTimestamp(),
      if (conversationId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return doc.id;
  }

  Future<void> deleteConversation(String conversationId) =>
      _firestore.collection(collectionName).doc(conversationId).delete();
}
