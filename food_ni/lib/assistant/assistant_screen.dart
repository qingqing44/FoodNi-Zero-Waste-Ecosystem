import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'assistant_history_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.conversationId,
    this.initialMessages,
  });

  final String? conversationId;
  final List<Map<String, dynamic>>? initialMessages;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
  });

  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
}

class _AssistantScreenState extends State<AssistantScreen> {
  static const _brandColor = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  late final ChatSession _chat;
  Uint8List? _selectedImageBytes;
  bool _historySeeded = false;
  String? _conversationId;
  String? _conversationTranscript;
  bool _needsContextBootstrap = false;
  bool _isRestoringConversation = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.5-flash',
      systemInstruction: Content.system(
        'You are the FoodNi AI assistant. You must only answer questions '
        'related to food, recipes, cooking, pantry management, and '
        'zero-waste sustainability. If a user asks about anything else, '
        'politely decline and steer the conversation back to food or cooking.',
      ),
    );

    _chat = model.startChat();

    if (widget.conversationId != null) {
      _conversationId = widget.conversationId;
      _restoreConversation();
      return;
    }

    _messages.add(
      const ChatMessage(
        text:
            'Hello! I am your FoodNi assistant. How can I help you with your '
            'cooking or pantry today?',
        isUser: false,
      ),
    );
  }

  Future<void> _restoreConversation() async {
    final initialMessages = widget.initialMessages;
    if (initialMessages != null && initialMessages.isNotEmpty) {
      _hydrateConversation(initialMessages);
      return;
    }

    setState(() {
      _isRestoringConversation = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('assistantHistory')
          .doc(_conversationId)
          .get();

      final data = doc.data();
      final restoredMessages = data == null
          ? <Map<String, dynamic>>[]
          : _messagesFromConversationData(data);

      if (!mounted) return;

      if (restoredMessages.isEmpty) {
        setState(() {
          _isRestoringConversation = false;
          _messages.add(
            const ChatMessage(
              text:
                  'This saved conversation has no restorable text messages yet. '
                  'You can still continue asking a new question from here.',
              isUser: false,
            ),
          );
        });
        return;
      }

      _hydrateConversation(restoredMessages);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRestoringConversation = false;
        _messages.add(
          const ChatMessage(
            text:
                'We could not restore the earlier messages, but you can still '
                'continue asking a new question from here.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _hydrateConversation(List<Map<String, dynamic>> rawMessages) {
    _messages
      ..clear()
      ..addAll(
        rawMessages.map(
          (message) => ChatMessage(
            text: (message['text'] as String? ?? '').trim(),
            isUser: message['isUser'] as bool? ?? false,
          ),
        ),
      );

    _historySeeded = true;
    _conversationTranscript = _buildTranscript(rawMessages);
    _needsContextBootstrap = _conversationTranscript!.trim().isNotEmpty;

    setState(() {
      _isRestoringConversation = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final imageBytes = _selectedImageBytes;

    if (text.isEmpty && imageBytes == null) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          imageBytes: imageBytes,
        ),
      );
      _isLoading = true;
      _controller.clear();
      _selectedImageBytes = null;
    });
    _scrollToBottom();

    try {
      final Content content;
      final bootstrapText = _needsContextBootstrap
          ? _buildContextBootstrapPrompt(
              transcript: _conversationTranscript ?? '',
              latestQuestion: text,
            )
          : text;
      if (imageBytes != null) {
        content = Content.multi([
          if (bootstrapText.trim().isNotEmpty) TextPart(bootstrapText),
          InlineDataPart('image/jpeg', imageBytes),
        ]);
      } else {
        content = Content.text(bootstrapText);
      }

      final response = await _chat.sendMessage(content);
      final responseText =
          (response.text?.trim().isNotEmpty ?? false)
              ? response.text!.trim()
              : 'I am sorry, I could not generate a response.';

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(text: responseText, isUser: false));
      });
      _needsContextBootstrap = false;
      _conversationTranscript = _buildTranscript(
        _messages
            .map(
              (message) => {
                'text': message.text,
                'isUser': message.isUser,
                'hasImage': message.imageBytes != null,
              },
            )
            .toList(),
      );
      _scrollToBottom();
      await _saveConversationHistory();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(text: 'Error: $e', isUser: false));
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveConversationHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    ChatMessage? firstUserMessage;
    for (final message in _messages) {
      if (message.isUser) {
        firstUserMessage = message;
        break;
      }
    }
    if (firstUserMessage == null) return;

    final conversationTitle = firstUserMessage.text.trim().isNotEmpty
        ? firstUserMessage.text.trim()
        : 'Image-based food question';

    final messagesPayload = _messages
        .map(
          (message) => {
            'text': message.text,
            'isUser': message.isUser,
            'hasImage': message.imageBytes != null,
          },
        )
        .toList();

    final collection = FirebaseFirestore.instance.collection('assistantHistory');
    final isNewConversation = _conversationId == null;
    final docRef = isNewConversation ? collection.doc() : collection.doc(_conversationId);
    _conversationId ??= docRef.id;

    await docRef.set({
      'userId': user.uid,
      'title': conversationTitle,
      'messages': messagesPayload,
      'messageCount': messagesPayload.length,
      'hasImage': messagesPayload.any((message) => message['hasImage'] == true),
      'lastQuestion': firstUserMessage.text.trim().isNotEmpty
          ? firstUserMessage.text.trim()
          : 'Image-based food question',
      'lastAnswer': _messages.last.text,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNewConversation) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssistantHistoryScreen()),
    );
  }

  String _buildTranscript(List<Map<String, dynamic>> messages) {
    return messages
        .where((message) => (message['text'] as String? ?? '').trim().isNotEmpty)
        .map((message) {
          final role = (message['isUser'] as bool? ?? false) ? 'User' : 'Assistant';
          final text = (message['text'] as String? ?? '').trim();
          return '$role: $text';
        })
        .join('\n');
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
    final question =
        (data['question'] as String? ?? data['lastQuestion'] as String? ?? '')
            .trim();
    final answer =
        (data['answer'] as String? ?? data['lastAnswer'] as String? ?? '')
            .trim();
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

  String _buildContextBootstrapPrompt({
    required String transcript,
    required String latestQuestion,
  }) {
    if (transcript.trim().isEmpty) return latestQuestion;

    return '''
You are continuing an existing FoodNi assistant conversation.

Previous conversation:
$transcript

Now continue helping the user naturally based on that prior context.
Latest user message:
$latestQuestion
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F8F4),
        elevation: 0,
        iconTheme: const IconThemeData(color: _brandColor),
        title: const Text(
          'FoodNi Assistant',
          style: TextStyle(color: _brandColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
            color: _brandColor,
            tooltip: 'Review previous questions',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildReviewBanner(),
            Expanded(
              child: _isRestoringConversation
                  ? const Center(
                      child: CircularProgressIndicator(color: _accentGreen),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: CircularProgressIndicator(color: _accentGreen),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewBanner() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assistantHistory')
          .where(
            'userId',
            isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '',
          )
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final hasHistory = (snapshot.data?.docs.isNotEmpty ?? false);
        if (!hasHistory && _historySeeded) {
          return const SizedBox.shrink();
        }

        _historySeeded = hasHistory || _historySeeded;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          padding: const EdgeInsets.all(14),
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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasHistory
                          ? 'Review your previous questions'
                          : 'Your questions can be reviewed later',
                      style: const TextStyle(
                        color: _brandColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasHistory
                          ? 'Open History anytime to revisit past food advice.'
                          : 'Your new assistant conversations will be saved to History.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: hasHistory ? _openHistory : null,
                child: const Text('History'),
              ),
            ],
          ),
        );
      },
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
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? _accentGreen : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    message.imageBytes!,
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : _brandColor,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImageBytes != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _selectedImageBytes!,
                    height: 82,
                    width: 82,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  right: -8,
                  top: -8,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedImageBytes = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cancel,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_selectedImageBytes != null) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ask about food, storage, or recipes...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9F8F4),
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
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: _isLoading ? null : _pickImage,
                    ),
                  ),
                  onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isLoading ? null : _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLoading ? Colors.grey : _accentGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
