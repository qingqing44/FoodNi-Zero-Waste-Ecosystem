import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

class StorageGuideScreen extends StatefulWidget {
  final String foodName;
  final String category;

  const StorageGuideScreen({
    super.key,
    required this.foodName,
    required this.category,
  });

  @override
  State<StorageGuideScreen> createState() => _StorageGuideScreenState();
}

class _StorageGuideScreenState extends State<StorageGuideScreen> {
  static const _primaryColor = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  _StorageGuide? _guide;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchGuide();
  }

  Future<void> _fetchGuide() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final guide = await _generateStorageGuide(
        widget.foodName,
        widget.category,
      );
      if (mounted) {
        setState(() {
          _guide = guide;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<_StorageGuide> _generateStorageGuide(
    String foodName,
    String category,
  ) async {
    const candidateModels = [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
    ];

    final prompt = '''
You are a professional food storage expert.

Provide accurate, food-specific storage information for "$foodName" (category: $category).

Return ONLY valid JSON with these exact keys:
{
  "idealTemperatureRange": "",
  "storageLocation": "",
  "keepsDuration": "",
  "techniques": [],
  "spoilageSigns": [],
  "commonMistakes": [],
  "tip": ""
}

Field requirements:
- "idealTemperatureRange": The actual correct temperature range for storing "$foodName". Be specific (e.g. bananas: "13°C – 15°C", raw chicken: "0°C – 2°C", honey: "Room temperature 18°C – 24°C"). Do NOT default to 0–4°C unless that is genuinely correct for this food.
- "storageLocation": Exactly one of: Refrigerator, Freezer, Pantry, Counter — whichever is best for "$foodName".
- "keepsDuration": How long "$foodName" keeps in the recommended location (be specific).
- "techniques": 3–5 actionable storage steps specific to "$foodName".
- "spoilageSigns": 2–4 observable signs that "$foodName" has gone bad.
- "commonMistakes": 2–3 common storage mistakes people make with "$foodName".
- "tip": One concise pro tip for maximizing freshness of "$foodName".

Rules:
- Every answer must be specific to "$foodName", not generic food advice.
- Return valid JSON only. No markdown. No explanations outside JSON.
''';

    GenerateContentResponse? response;
    String? lastError;

    for (final modelName in candidateModels) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );
        response = await model.generateContent([
          Content.text(prompt),
        ]);
        break;
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }

    if (response == null) {
      throw Exception('Could not load storage guide. $lastError');
    }

    final rawText = response.text ?? '';
    if (rawText.trim().isEmpty) {
      throw Exception('AI returned an empty response.');
    }

    return _StorageGuide.fromJson(_parseJson(rawText));
  }

  Map<String, dynamic> _parseJson(String rawText) {
    try {
      return jsonDecode(rawText) as Map<String, dynamic>;
    } catch (_) {
      final cleaned = rawText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      try {
        return jsonDecode(cleaned) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Could not parse AI response: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.foodName,
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Storage Guide',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _fetchGuide,
              color: _primaryColor,
            ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : _buildGuide(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _accentGreen),
          const SizedBox(height: 20),
          Text(
            'Generating storage guide\nfor ${widget.foodName}…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Could not load storage guide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchGuide,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuide() {
    final g = _guide!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTemperatureCard(g),
          const SizedBox(height: 16),
          _buildDurationCard(g),
          const SizedBox(height: 16),
          _buildListCard(
            icon: Icons.checklist_rounded,
            title: 'Storage Techniques',
            iconColor: _accentGreen,
            bgColor: const Color(0xFFE8F3EF),
            items: g.techniques,
            numbered: true,
          ),
          const SizedBox(height: 16),
          _buildListCard(
            icon: Icons.warning_amber_rounded,
            title: 'Signs of Spoilage',
            iconColor: const Color(0xFFE85D3F),
            bgColor: const Color(0xFFFFF1F0),
            items: g.spoilageSigns,
            numbered: false,
          ),
          const SizedBox(height: 16),
          _buildListCard(
            icon: Icons.do_not_disturb_alt_rounded,
            title: 'Common Mistakes',
            iconColor: const Color(0xFFB26A00),
            bgColor: const Color(0xFFFFF4E5),
            items: g.commonMistakes,
            numbered: false,
          ),
          if (g.tip.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTipCard(g.tip),
          ],
        ],
      ),
    );
  }

  Widget _buildTemperatureCard(_StorageGuide g) {
    final locationData = _locationMeta(g.storageLocation);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor,
            const Color(0xFF0A4A33),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(locationData.icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.storageLocation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  g.idealTemperatureRange,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ideal Temperature',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard(_StorageGuide g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF1A73E8),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How Long It Keeps',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  g.keepsDuration,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
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

  Widget _buildListCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color bgColor,
    required List<String> items,
    required bool numbered,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      numbered ? '${entry.key + 1}' : '•',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: numbered ? 12 : 16,
                        fontWeight: FontWeight.bold,
                        height: numbered ? 1.2 : 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String tip) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pro Tip',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
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

  _LocationMeta _locationMeta(String location) {
    final l = location.toLowerCase();
    if (l.contains('freez')) {
      return _LocationMeta(Icons.ac_unit_rounded);
    } else if (l.contains('fridge') || l.contains('refriger')) {
      return _LocationMeta(Icons.kitchen_rounded);
    } else if (l.contains('pantry') || l.contains('cupboard')) {
      return _LocationMeta(Icons.shelves);
    } else {
      return _LocationMeta(Icons.countertops_rounded);
    }
  }
}

class _StorageGuide {
  final String idealTemperatureRange;
  final String storageLocation;
  final String keepsDuration;
  final List<String> techniques;
  final List<String> spoilageSigns;
  final List<String> commonMistakes;
  final String tip;

  const _StorageGuide({
    required this.idealTemperatureRange,
    required this.storageLocation,
    required this.keepsDuration,
    required this.techniques,
    required this.spoilageSigns,
    required this.commonMistakes,
    required this.tip,
  });

  factory _StorageGuide.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
      }
      return [];
    }

    return _StorageGuide(
      idealTemperatureRange: json['idealTemperatureRange']?.toString() ?? 'N/A',
      storageLocation: json['storageLocation']?.toString() ?? 'Refrigerator',
      keepsDuration: json['keepsDuration']?.toString() ?? 'Varies',
      techniques: parseList(json['techniques']),
      spoilageSigns: parseList(json['spoilageSigns']),
      commonMistakes: parseList(json['commonMistakes']),
      tip: json['tip']?.toString() ?? '',
    );
  }
}

class _LocationMeta {
  final IconData icon;
  const _LocationMeta(this.icon);
}
