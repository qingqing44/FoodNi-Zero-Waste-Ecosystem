import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Displays the Gemini analysis result for a scanned food item and lets the
/// user save it to their Firestore inventory or discard it.
class FoodDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> foodData;

  const FoodDetailsScreen({super.key, required this.foodData});

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  bool _isSaving = false;

  // ---------------------------------------------------------------------------
  // Helpers – freshness badge colours
  // ---------------------------------------------------------------------------

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'fresh') return const Color(0xFF34A853);       // green
    if (s == 'good') return const Color(0xFF1A73E8);        // blue
    if (s.contains('consume')) return Colors.orange;        // orange
    if (s == 'spoiled') return Colors.red;                  // red
    return Colors.grey;
  }

  Color _statusBg(String status) => _statusColor(status).withOpacity(0.12);

  // ---------------------------------------------------------------------------
  // Firestore save
  // ---------------------------------------------------------------------------

  Future<void> _saveToInventory() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      DateTime expiryDateTime;
      final rawAiDate = widget.foodData['expiryDate'];
      
      // Grab the actual shelf life value detected by your AI model
      final int aiDaysRemaining = (widget.foodData['estimatedDaysRemaining'] as num?)?.toInt() ?? 7;

      if (rawAiDate is DateTime) {
        expiryDateTime = rawAiDate;
      } else if (rawAiDate is String) {
        try {
          expiryDateTime = DateFormat('MMM dd, yyyy').parse(rawAiDate);
        } catch (_) {
          try {
            expiryDateTime = DateTime.parse(rawAiDate);
          } catch (_) {
            expiryDateTime = DateTime.now().add(Duration(days: aiDaysRemaining));
          }
        }
      } else {
        // Use the AI's detected remaining days instead of defaulting to a static 7 days
        expiryDateTime = DateTime.now().add(Duration(days: aiDaysRemaining));
      }

      // Format strings matching your manual entry screen setup
      final String formattedExpiryString = DateFormat('MMM dd, yyyy').format(expiryDateTime);
      
      // Zero out structural hourly variances to ensure daily countdown integrity
      final today = DateTime.now();
      final todayCleaned = DateTime(today.year, today.month, today.day);
      final expiryCleaned = DateTime(expiryDateTime.year, expiryDateTime.month, expiryDateTime.day);
      final int dynamicDaysRemaining = expiryCleaned.difference(todayCleaned).inDays;

      String calculatedStatus = 'Fresh';
      if (dynamicDaysRemaining <= 0) {
        calculatedStatus = 'Spoiled';
      } else if (dynamicDaysRemaining <= 3) {
        calculatedStatus = 'Good'; 
      }

      // Commit precisely aligned key maps to Firestore
      await FirebaseFirestore.instance.collection('foodItems').add({
        'userId': user.uid,
        'foodName': widget.foodData['foodName'] ?? widget.foodData['name'] ?? 'Scanned Item',
        'category': widget.foodData['category'] ?? 'Uncategorized',
        'quantity': widget.foodData['quantity'] ?? '1 pcs',
        'storageSuggestion': widget.foodData['storageSuggestion'] ?? widget.foodData['storage'] ?? 'No special storage suggestions provided.',
        'thumbnailPath': widget.foodData['thumbnailPath'] ?? widget.foodData['localImagePath'],
        'localImagePath': widget.foodData['localImagePath'],
        
        'expiryDate': formattedExpiryString, 
        'estimatedDaysRemaining': dynamicDaysRemaining, 
        'freshnessStatus': widget.foodData['freshnessStatus'] ?? calculatedStatus,
        'freshnessScore': widget.foodData['freshnessScore'] ?? (dynamicDaysRemaining > 0 ? 100 : 0),
        
        'scanDate': FieldValue.serverTimestamp(),
        'source': 'ai_scan'
      });

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanned food item saved to inventory!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save item: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = widget.foodData;

    final foodName = data['foodName'] as String? ?? 'Unknown Item';
    final category = data['category'] as String? ?? 'Other';
    final freshnessScore = (data['freshnessScore'] as num?)?.toInt() ?? 0;
    final freshnessStatus = data['freshnessStatus'] as String? ?? 'Unknown';
    final estimatedDaysRemaining =
        (data['estimatedDaysRemaining'] as num?)?.toInt() ?? 0;
    final confidence = (data['confidence'] as num?)?.toInt() ?? 0;
    final reasoning =
        data['reasoning'] as String? ?? 'No reasoning provided.';
    final localImagePath = data['localImagePath'] as String?;

    final statusColor = _statusColor(freshnessStatus);
    final statusBg = _statusBg(freshnessStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF052A1E)),
        title: const Text(
          'Scan Result',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Food image (local file) ──────────────────────────────────────
            _buildFoodImage(localImagePath),
            const SizedBox(height: 20),

            // ── Food name + category ─────────────────────────────────────────
            Text(
              foodName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF052A1E),
              ),
            ),
            const SizedBox(height: 4),
            _buildCategoryChip(category),
            const SizedBox(height: 20),

            // ── Freshness badge ──────────────────────────────────────────────
            _buildFreshnessBadge(
              freshnessStatus, freshnessScore, statusColor, statusBg),
            const SizedBox(height: 16),

            // ── Info cards ───────────────────────────────────────────────────
            _buildInfoCard(
              icon: Icons.access_time_rounded,
              title: 'Estimated Shelf Life',
              content: '$estimatedDaysRemaining day${estimatedDaysRemaining == 1 ? '' : 's'} remaining',
              bgColor: const Color(0xFFE8F3EF),
              iconColor: const Color(0xFF34A853),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.bar_chart_rounded,
              title: 'Confidence Score',
              content: '$confidence%',
              bgColor: const Color(0xFFE8F0FE),
              iconColor: const Color(0xFF1A73E8),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.analytics_outlined,
              title: 'AI Reasoning',
              content: reasoning,
              bgColor: const Color(0xFFF3E5F5),
              iconColor: Colors.purple,
            ),
          ],
        ),
      ),
      // ── Bottom action buttons ─────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildFoodImage(String? localImagePath) {
    Widget imageWidget;

    if (localImagePath != null && File(localImagePath).existsSync()) {
      imageWidget = Image.file(
        File(localImagePath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 250,
        errorBuilder: (_, __, ___) => _placeholderImage(),
      );
    } else {
      imageWidget = _placeholderImage();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: imageWidget,
    );
  }

  Widget _placeholderImage() => Container(
        height: 250,
        color: Colors.grey[200],
        child: const Icon(Icons.fastfood, size: 64, color: Colors.grey),
      );

  Widget _buildCategoryChip(String category) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F3EF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            category,
            style: const TextStyle(
              color: Color(0xFF34A853),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _buildFreshnessBadge(
    String status, int score, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'Freshness score: $score / 100',
                style: TextStyle(fontSize: 13, color: color.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF052A1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F8F4),
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          // Discard button
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFF052A1E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Discard',
                style: TextStyle(
                  color: Color(0xFF052A1E),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Save button
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveToInventory,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF052A1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save to Inventory',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
