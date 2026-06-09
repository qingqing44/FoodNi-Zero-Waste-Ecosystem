import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chat-only AI service using Groq (separate quota from Firebase/Gemini camera).
///
/// Get a free API key at https://console.groq.com
/// Run with: flutter run --dart-define=GROQ_API_KEY=gsk_your_key_here
class AssistantChatService {
  AssistantChatService({http.Client? client}) : _client = client ?? http.Client();

  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const String unavailableMessage =
      'The AI assistant is currently unavailable. Please try again later.';
  static const String emptyResponseMessage =
      'No response was received from the AI. Please try again.';

  /// Only model enabled for the Foodni Groq project.
  static const String chatModel = 'qwen/qwen3-32b';

  final http.Client _client;
  final List<Map<String, String>> _history = [];

  String _systemPrompt = '';

  bool get hasApiKey => _apiKey.isNotEmpty;

  String get activeModel => chatModel;

  void startSession({
    required String systemPrompt,
    List<Map<String, String>>? history,
  }) {
    _systemPrompt = systemPrompt;
    _history
      ..clear()
      ..addAll(history ?? const []);
  }

  void updateSystemPrompt(String systemPrompt) {
    _systemPrompt = systemPrompt;
  }

  Future<String> sendMessage(String userText) async {
    if (!hasApiKey) {
      throw const AssistantChatException.unavailable();
    }

    _history.add({'role': 'user', 'content': userText});

    try {
      final reply = await _requestCompletion();
      _history.add({'role': 'assistant', 'content': reply});
      return reply;
    } catch (e) {
      _history.removeLast();
      rethrow;
    }
  }

  Map<String, dynamic> _buildRequestBody(List<Map<String, String>> messages) {
    return {
      'model': chatModel,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 1024,
      'reasoning_format': 'hidden',
      'reasoning_effort': 'none',
    };
  }

  Future<String> _requestCompletion() async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ..._history,
    ];

    final response = await _client.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(_buildRequestBody(messages)),
    ).timeout(_requestTimeout);

    if (response.statusCode == 401 ||
        response.statusCode == 403 ||
        response.statusCode == 408 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw const AssistantChatException.unavailable();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AssistantChatException.unavailable();
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw const AssistantChatException.emptyResponse();
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw const AssistantChatException.emptyResponse();
    }

    final cleaned = stripThinking(content);
    if (cleaned.isEmpty) {
      throw const AssistantChatException.emptyResponse();
    }

    return cleaned;
  }

  /// Removes model chain-of-thought blocks so only the user-facing answer shows.
  static String stripThinking(String text) {
    var result = text;

    final openThink = _xmlTag('think');
    final closeThink = _xmlTag('think', close: true);
    final openReasoning = _xmlTag('reasoning');
    final closeReasoning = _xmlTag('reasoning', close: true);

    final pairedPatterns = <RegExp>[
      RegExp(
        RegExp.escape(openThink) + r'[\s\S]*?' + RegExp.escape(closeThink),
        caseSensitive: false,
      ),
      RegExp(r'<\|im_start\|>think[\s\S]*?<\|im_end\|>', caseSensitive: false),
      RegExp(
        r'\[redacted_thinking\][\s\S]*?\[/redacted_thinking\]',
        caseSensitive: false,
      ),
      RegExp(
        RegExp.escape(openReasoning) +
            r'[\s\S]*?' +
            RegExp.escape(closeReasoning),
        caseSensitive: false,
      ),
    ];

    for (var pass = 0; pass < 5; pass++) {
      var changed = false;
      for (final pattern in pairedPatterns) {
        final next = result.replaceAll(pattern, '');
        if (next != result) {
          result = next;
          changed = true;
        }
      }
      if (!changed) break;
    }

    final unclosedPatterns = <RegExp>[
      RegExp(RegExp.escape(openThink) + r'[\s\S]*$', caseSensitive: false),
      RegExp(
        RegExp.escape(openReasoning) + r'[\s\S]*$',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:^|\n)\s*redacted_thinking[\s\S]*$',
        caseSensitive: false,
      ),
    ];
    for (final pattern in unclosedPatterns) {
      result = result.replaceAll(pattern, '');
    }

    return result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static String _xmlTag(String name, {bool close = false}) =>
      close ? '</$name>' : '<$name>';
}

class AssistantChatException implements Exception {
  const AssistantChatException._(this.userMessage);

  const AssistantChatException.unavailable()
    : this._(AssistantChatService.unavailableMessage);

  const AssistantChatException.emptyResponse()
    : this._(AssistantChatService.emptyResponseMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}
