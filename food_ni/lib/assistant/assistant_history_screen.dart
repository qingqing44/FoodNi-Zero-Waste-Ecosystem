import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'assistant_screen.dart';

class AssistantHistoryScreen extends StatelessWidget {
  const AssistantHistoryScreen({super.key});

  static const _brandColor = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: _brandColor),
        title: const Text(
          'Conversation History',
          style: TextStyle(color: _brandColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: user == null
          ? const Center(
              child: Text('Please log in to review your conversations'),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('assistantHistory')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accentGreen),
                  );
                }

                final docs = [...?snapshot.data?.docs]
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTimestamp =
                        (aData['updatedAt'] ?? aData['createdAt']) as Timestamp?;
                    final bTimestamp =
                        (bData['updatedAt'] ?? bData['createdAt']) as Timestamp?;
                    return (bTimestamp?.millisecondsSinceEpoch ?? 0)
                        .compareTo(aTimestamp?.millisecondsSinceEpoch ?? 0);
                  });

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildIntroCard();
                    }

                    final doc = docs[index - 1];
                    final data = doc.data() as Map<String, dynamic>;
                    return _ConversationCard(
                      conversationId: doc.id,
                      data: data,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: _accentGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review your complete assistant conversations',
                  style: TextStyle(
                    color: _brandColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Each saved entry represents one full chat session. Open any '
                  'conversation to revisit all the questions and replies inside it.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: _brandColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No saved conversations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _brandColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with the FoodNi assistant. Each full session will '
              'be saved here after you receive a reply.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 54, color: Colors.redAccent),
            const SizedBox(height: 14),
            const Text(
              'Could not load conversation history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _brandColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversationId,
    required this.data,
  });

  final String conversationId;
  final Map<String, dynamic> data;

  static const _brandColor = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] as String? ?? '').trim();
    final lastAnswer = (data['lastAnswer'] as String? ?? '').trim();
    final hasImage = data['hasImage'] as bool? ?? false;
    final messageCount = data['messageCount'] as int? ?? 0;
    final timestamp = (data['updatedAt'] ?? data['createdAt']) as Timestamp?;
    final formattedDate = timestamp == null
        ? 'Just now'
        : DateFormat('dd MMM yyyy, h:mm a').format(timestamp.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showConversationDetails(context, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasImage
                          ? Icons.photo_library_rounded
                          : Icons.forum_outlined,
                      color: _accentGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.isEmpty ? 'FoodNi conversation' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _brandColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildActionMenu(context),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                lastAnswer,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${messageCount ~/ 2} exchange${messageCount ~/ 2 == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      color: Colors.white,
      onSelected: (value) {
        if (value == 'continue') {
          _continueConversation(context, data);
        } else if (value == 'delete') {
          _confirmDelete(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'continue',
          child: Row(
            children: [
              Icon(Icons.play_arrow_rounded, color: _accentGreen),
              SizedBox(width: 10),
              Text('Continue'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Delete'),
            ],
          ),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(2),
        child: Icon(
          Icons.more_horiz_rounded,
          color: Colors.grey,
        ),
      ),
    );
  }

  void _continueConversation(BuildContext context, Map<String, dynamic> data) {
    final initialMessages = _messagesFromConversationData(data);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssistantScreen(
          conversationId: conversationId,
          initialMessages: initialMessages,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _messagesFromConversationData(
    Map<String, dynamic> data,
  ) {
    final rawMessages = data['messages'];
    if (rawMessages is List) {
      final messages = rawMessages
          .whereType<Map>()
          .map((message) => Map<String, dynamic>.from(message))
          .toList();
      if (messages.isNotEmpty) return messages;
    }

    final fallbackMessages = <Map<String, dynamic>>[];
    final question = (data['question'] as String? ?? data['lastQuestion'] as String? ?? '').trim();
    final answer = (data['answer'] as String? ?? data['lastAnswer'] as String? ?? '').trim();
    final hasImage = data['hasImage'] as bool? ?? false;

    if (question.isNotEmpty) {
      fallbackMessages.add({
        'text': question,
        'isUser': true,
        'hasImage': hasImage,
      });
    }
    if (answer.isNotEmpty) {
      fallbackMessages.add({
        'text': answer,
        'isUser': false,
        'hasImage': false,
      });
    }

    return fallbackMessages;
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Delete Conversation?',
          style: TextStyle(
            color: _brandColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently remove the saved conversation from your history.',
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _brandColor,
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('assistantHistory')
        .doc(conversationId)
        .delete();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation deleted'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showConversationDetails(BuildContext context, Map<String, dynamic> data) {
    final rawMessages = data['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map((message) => Map<String, dynamic>.from(message))
            .toList()
        : <Map<String, dynamic>>[];
    final timestamp = (data['updatedAt'] ?? data['createdAt']) as Timestamp?;
    final formattedDate = timestamp == null
        ? 'Just now'
        : DateFormat('dd MMM yyyy, h:mm a').format(timestamp.toDate());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9F8F4),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  (data['title'] as String? ?? 'FoodNi conversation').trim(),
                  style: const TextStyle(
                    color: _brandColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _ConversationBubble(message: message);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationBubble extends StatelessWidget {
  const _ConversationBubble({required this.message});

  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final isUser = message['isUser'] as bool? ?? false;
    final text = (message['text'] as String? ?? '').trim();
    final hasImage = message['hasImage'] as bool? ?? false;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF34A853) : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.white.withValues(alpha: 0.18)
                        : const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Included a photo',
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1A73E8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF052A1E),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
