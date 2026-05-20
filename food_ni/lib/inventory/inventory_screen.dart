import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_item_screen.dart';

/// Displays the current user's scanned food inventory from Firestore.
/// Images are loaded from the local device path stored in [thumbnailPath].
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  // ---------------------------------------------------------------------------
  // Freshness badge colour helpers (consistent with FoodDetailsScreen)
  // ---------------------------------------------------------------------------

  Color _statusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'fresh') return const Color(0xFF34A853);
    if (s == 'good') return const Color(0xFF1A73E8);
    if (s.contains('consume')) return Colors.orange;
    if (s == 'spoiled') return Colors.red;
    return Colors.grey;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view inventory')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF052A1E)),
        title: const Text(
          'My Inventory',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('foodItems')
            .where('userId', isEqualTo: user.uid)
            .orderBy('scanDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF052A1E)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.kitchen_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No food items yet.\nTap the scanner to add some!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _InventoryCard(data: data, statusColor: _statusColor);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemScreen()),
          );
        },
        backgroundColor: const Color(0xFF052A1E),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// A single inventory card that shows the thumbnail, food name, freshness badge,
/// category chip and estimated days remaining.
class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.data,
    required this.statusColor,
  });

  final Map<String, dynamic> data;
  final Color Function(String?) statusColor;

  @override
  Widget build(BuildContext context) {
    final foodName = data['foodName'] as String? ?? 'Unknown Item';
    final category = data['category'] as String? ?? '';
    final freshnessStatus = data['freshnessStatus'] as String? ?? '';
    final freshnessScore = (data['freshnessScore'] as num?)?.toInt() ?? 0;
    final estimatedDaysRemaining =
        (data['estimatedDaysRemaining'] as num?)?.toInt() ?? 0;

    // Prefer the faster thumbnail; fall back to full image if thumbnail is absent.
    final thumbPath =
        (data['thumbnailPath'] as String?) ?? (data['localImagePath'] as String?);

    final color = statusColor(freshnessStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shadowColor: Colors.black12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF0F0F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(thumbPath),
            ),
            const SizedBox(width: 14),

            // ── Details ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food name
                  Text(
                    foodName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF052A1E),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Freshness status badge
                  if (freshnessStatus.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Text(
                        '$freshnessStatus  •  $freshnessScore/100',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Days remaining
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        '$estimatedDaysRemaining day${estimatedDaysRemaining == 1 ? '' : 's'} remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Category chip
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F3EF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Color(0xFF34A853),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? path) {
    if (path != null && File(path).existsSync()) {
      return Image.file(
        File(path),
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 90,
        height: 90,
        color: Colors.grey[200],
        child: const Icon(Icons.fastfood, color: Colors.grey),
      );
}
