import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Chat-only AI service for FoodNi.
///
/// Requests are proxied through the FoodNi Vercel backend, so no Groq API key
/// is required on the client.  The backend forwards messages to Groq (Qwen)
/// and returns only the assistant reply.
class AssistantChatService {
  AssistantChatService({http.Client? client}) : _client = client ?? http.Client();

  /// Vercel backend endpoint – update this after deploying.
  static const String _backendUrl =
      'https://foodni-chat-backend.vercel.app/api/chat';

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const String unavailableMessage =
      'The AI assistant is currently unavailable. Please try again later.';
  static const String emptyResponseMessage =
      'No response was received from the AI. Please try again.';

  /// Always true – API key is managed server-side.
  bool get hasApiKey => true;

  final http.Client _client;
  final List<Map<String, String>> _history = [];
  String _systemPrompt = '';

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

  Future<String> _requestCompletion() async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ..._history,
    ];

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'messages': messages}),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AssistantChatException._(
        'The AI assistant took too long to respond. Please try again.',
      );
    } catch (_) {
      throw const AssistantChatException.unavailable();
    }

    // ── Parse error body if present ────────────────────────────────────────
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AssistantChatException.unavailable();
    }

    if (response.statusCode == 429) {
      throw AssistantChatException._(
        (data['error'] as String?) ??
            'AI service rate limit reached. Please try again shortly.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantChatException._(
        (data['error'] as String?) ?? unavailableMessage,
      );
    }

    // ── Extract the reply ──────────────────────────────────────────────────
    final responseText = data['response'] as String?;
    if (responseText == null || responseText.trim().isEmpty) {
      throw const AssistantChatException.emptyResponse();
    }

    final cleaned = stripThinking(responseText.trim());
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
      RegExp(r'(?:^|\n)\s*redacted_thinking[\s\S]*$', caseSensitive: false),
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
