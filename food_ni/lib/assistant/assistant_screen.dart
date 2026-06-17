import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../inventory/food_status_utils.dart';
import 'assistant_chat_service.dart';
import 'assistant_history_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _suggestedQuestions = [
    'How long can chicken stay in the fridge?',
    'Can I freeze cooked rice?',
    'How should I store apples?',
  ];

  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final AssistantChatService _chatService = AssistantChatService();
  final AssistantHistoryService _historyService = AssistantHistoryService();
  bool _isLoading = false;
  bool _isInitializing = true;
  int _inventoryCount = 0;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Loads pantry context, restores prior chat from Firestore, and starts session.
  Future<void> _initializeChat({bool refreshPantryOnly = false}) async {
    setState(() => _isInitializing = !refreshPantryOnly);

    final user = FirebaseAuth.instance.currentUser;
    _userId = user?.uid;
    final userName = (user?.displayName ?? '').trim();

    String inventoryContext;
    try {
      inventoryContext = await _buildInventoryContext(user);
    } catch (e) {
      inventoryContext =
          'The pantry data could not be loaded right now (error: $e). '
          'Answer using general food knowledge and let the user know their '
          'live inventory was unavailable.';
    }

    final systemPrompt = _buildSystemPrompt(
      userName: userName,
      inventoryContext: inventoryContext,
    );

    if (refreshPantryOnly) {
      _chatService.updateSystemPrompt(systemPrompt);
      if (!mounted) return;
      setState(() => _isInitializing = false);
      return;
    }

    List<ChatMessage> savedMessages = [];
    if (_userId != null) {
      try {
        savedMessages = await _historyService.loadMessages(_userId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load chat history: $e')),
          );
        }
      }
    }

    _chatService.startSession(
      systemPrompt: systemPrompt,
      history: _toGroqHistory(savedMessages),
    );

    if (!mounted) return;

    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages
          ..clear()
          ..addAll(savedMessages);
        _isInitializing = false;
      });
      return;
    }

    final greeting = _buildGreeting(userName);
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: greeting, isUser: false));
      _isInitializing = false;
    });

    if (_userId != null) {
      await _historyService.saveMessage(
        userId: _userId!,
        text: greeting,
        isUser: false,
      );
    }
  }

  Future<void> _resetConversation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Reset Chat',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to clear your chat history and start a new session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isInitializing = true;
    });

    if (_userId != null) {
      try {
        await _historyService.clearHistory(_userId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not clear chat history: $e')),
          );
        }
      }
    }

    await _initializeChat(refreshPantryOnly: false);
  }

  List<Map<String, String>> _toGroqHistory(List<ChatMessage> messages) {
    return messages
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
          },
        )
        .toList();
  }

  String _buildSystemPrompt({
    required String userName,
    required String inventoryContext,
  }) {
    final today = FoodStatusUtils.formatExpiryDate(
      FoodStatusUtils.malaysiaTodayDateOnly(),
    );
    final namePart = userName.isEmpty ? '' : "The user's name is $userName. ";

    return '''
You are the FoodNi AI assistant, a personalized food and zero-waste helper.
${namePart}Today's date is $today.

You must only answer questions related to food, recipes, cooking, pantry
management, food storage, and zero-waste sustainability. If a user asks about
anything else, politely decline and steer the conversation back to food.

PERSONALIZATION RULES:
- Always ground your answers in the user's real pantry inventory provided below.
- Prioritize recipes that reduce food waste and use ingredients expiring soon.
- Reference specific items, quantities, and how many days they have left when
  it is relevant.
- If the user asks "what can I cook?" or similar, propose dishes that mostly use
  what they already have, and clearly note any common extra ingredients needed.
- If an item is already expired, warn the user about food safety instead of
  recommending they eat it.
- If the pantry is empty or a needed item is missing, say so honestly and give
  general guidance.
- Keep answers practical, friendly, and concise.
- Never show internal reasoning, thinking steps, or analysis tags. Reply with
  only the final helpful answer the user should read.

===== USER'S CURRENT PANTRY INVENTORY =====
$inventoryContext
===========================================
''';
  }

  String _buildGreeting(String userName) {
    final hello = userName.isEmpty ? 'Hello!' : 'Hello, $userName!';
    if (_inventoryCount == 0) {
      return '$hello I am your FoodNi assistant. Your pantry looks empty right '
          'now — add or scan some items and I can suggest recipes that use them. '
          'How can I help with your cooking today?';
    }
    return '$hello I am your FoodNi assistant. I can see $_inventoryCount item'
        '${_inventoryCount == 1 ? '' : 's'} in your pantry. Ask me what to cook, '
        'how to store something, or how to use up items before they expire!';
  }

  Future<String> _buildInventoryContext(User? user) async {
    if (user == null) {
      _inventoryCount = 0;
      return 'No user is signed in, so there is no personal pantry data.';
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('foodItems')
        .where('userId', isEqualTo: user.uid)
        .get();

    _inventoryCount = snapshot.docs.length;
    if (snapshot.docs.isEmpty) {
      return 'The pantry is currently empty. The user has not added any food items yet.';
    }

    final expired = <String>[];
    final expiring = <String>[];
    final fresh = <String>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name = (data['foodName'] as String? ?? 'Unknown item').trim();
      final category = (data['category'] as String? ?? '').trim();
      final quantity = (data['quantity'] as String? ?? '').trim();
      final expiryDate = (data['expiryDate'] as String? ?? '').trim();
      final status = FoodStatusUtils.statusFromItemData(data);
      final days = FoodStatusUtils.daysRemainingFromString(expiryDate) ??
          (data['estimatedDaysRemaining'] as num?)?.toInt();

      final parts = <String>[name];
      if (quantity.isNotEmpty) parts.add('qty: $quantity');
      if (category.isNotEmpty) parts.add('category: $category');
      if (expiryDate.isNotEmpty && expiryDate != 'N/A') {
        parts.add('expires: $expiryDate');
      }
      if (days != null) {
        if (days < 0) {
          parts.add('${-days} day${days == -1 ? '' : 's'} past expiry');
        } else {
          parts.add('$days day${days == 1 ? '' : 's'} left');
        }
      }

      final line = '- ${parts.join(', ')}';
      switch (status) {
        case FoodStatusUtils.expired:
          expired.add(line);
          break;
        case FoodStatusUtils.nearExpiry:
        case FoodStatusUtils.expiringSoon:
          expiring.add(line);
          break;
        default:
          fresh.add(line);
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Total items: ${snapshot.docs.length}');
    buffer.writeln();
    buffer.writeln('EXPIRED (do not eat — handle for safety/disposal):');
    buffer.writeln(expired.isEmpty ? '- none' : expired.join('\n'));
    buffer.writeln();
    buffer.writeln('EXPIRING SOON (use these first to avoid waste):');
    buffer.writeln(expiring.isEmpty ? '- none' : expiring.join('\n'));
    buffer.writeln();
    buffer.writeln('FRESH:');
    buffer.writeln(fresh.isEmpty ? '- none' : fresh.join('\n'));

    return buffer.toString();
  }

  Future<void> _persistMessage(ChatMessage message) async {
    final userId = _userId;
    if (userId == null) return;

    await _historyService.saveMessage(
      userId: userId,
      text: message.text,
      isUser: message.isUser,
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isInitializing) return;

    final userMessage = ChatMessage(text: text, isUser: true);
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _controller.clear();
    });

    await _persistMessage(userMessage);

    try {
      final responseText = await _chatService.sendMessage(text);
      final assistantMessage = ChatMessage(text: responseText, isUser: false);

      setState(() {
        _isLoading = false;
        _messages.add(assistantMessage);
      });

      await _persistMessage(assistantMessage);
    } catch (e) {
      final fallbackMessage = e is AssistantChatException
          ? e.userMessage
          : AssistantChatService.unavailableMessage;
      final errorMessage = ChatMessage(text: fallbackMessage, isUser: false);
      setState(() {
        _isLoading = false;
        _messages.add(errorMessage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF052A1E)),
        title: const Text(
          'FoodNi Assistant',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset chat history',
            onPressed: _isInitializing ? null : _resetConversation,
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF34A853)),
                    SizedBox(height: 16),
                    Text(
                      'Reading your pantry...',
                      style: TextStyle(color: Color(0xFF666666)),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(color: Color(0xFF34A853)),
                    ),
                  if (_messages.length <= 1 && MediaQuery.of(context).viewInsets.bottom == 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _buildSuggestedQuestions(),
                    ),
                  SafeArea(
                    top: false,
                    child: _buildInputArea(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF052A1E) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF052A1E),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggested Questions',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedQuestions.map((question) {
            return ActionChip(
              label: Text(
                question,
                style: const TextStyle(
                  color: Color(0xFF052A1E),
                  fontSize: 12,
                ),
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              onPressed: _isLoading || _isInitializing
                  ? null
                  : () => _applySuggestedQuestion(question),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _applySuggestedQuestion(String question) {
    _controller
      ..text = question
      ..selection = TextSelection.collapsed(offset: question.length);
    setState(() {});
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask about food or recipes...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF9F8F4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF34A853), width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isLoading ? Colors.grey : const Color(0xFF34A853),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
