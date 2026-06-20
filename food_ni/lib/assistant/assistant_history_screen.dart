import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'assistant_screen.dart';

class AssistantHistoryScreen extends StatelessWidget {
  const AssistantHistoryScreen({super.key});

  static const _brand = Color(0xFF052A1E);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8F4),
        title: const Text('Conversation History',
            style: TextStyle(color: _brand, fontWeight: FontWeight.bold)),
      ),
      body: userId == null
          ? const Center(child: Text('Please log in to view your conversations.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('assistantHistory')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Could not load conversations.'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['messages'] is List;
                }).toList()
                  ..sort((a, b) {
                    final aTime = ((a.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bTime = ((b.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bTime.compareTo(aTime);
                  });
                if (docs.isEmpty) {
                  return const Center(child: Text('No saved conversations yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _ConversationCard(doc: docs[index]),
                );
              },
            ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.doc});

  final QueryDocumentSnapshot doc;
  static const _brand = Color(0xFF052A1E);

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final messages = (data['messages'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final title = (data['title'] as String? ?? 'FoodNi conversation').trim();
    final preview = (data['lastAnswer'] as String? ?? '').trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.forum_outlined, color: Color(0xFF34A853)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _brand, fontWeight: FontWeight.bold))),
            PopupMenuButton<String>(
              onSelected: (value) => value == 'continue'
                  ? Navigator.push(context, MaterialPageRoute(builder: (_) => AssistantScreen(conversationId: doc.id, initialMessages: messages)))
                  : _delete(context),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'continue', child: Text('Continue')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AssistantScreen(conversationId: doc.id, initialMessages: messages))),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Continue chat'),
          ),
        ]),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await doc.reference.delete();
  }
}
