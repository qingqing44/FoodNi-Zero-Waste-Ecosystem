import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'add_item_screen.dart';
import 'calendar_screen.dart';
import 'inventory_details_screen.dart';

/// Displays the current user's scanned food inventory from Firestore.
/// Images are loaded from the local device path stored in [thumbnailPath].
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  bool _matchesFilters(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final foodName = (data['foodName'] as String? ?? '').toLowerCase();
    final category = data['category'] as String? ?? '';
    final freshnessStatus = data['freshnessStatus'] as String? ?? '';
    final query = _searchQuery.trim().toLowerCase();

    final matchesSearch =
        query.isEmpty ||
        foodName.contains(query) ||
        category.toLowerCase().contains(query) ||
        freshnessStatus.toLowerCase().contains(query);
    final matchesCategory =
        _selectedCategory == 'All' || category == _selectedCategory;
    final matchesStatus =
        _selectedStatus == 'All' || freshnessStatus == _selectedStatus;

    return matchesSearch && matchesCategory && matchesStatus;
  }

  List<String> _filterOptions(List<QueryDocumentSnapshot> docs, String field) {
    final options =
        docs
            .map(
              (doc) => (doc.data() as Map<String, dynamic>)[field] as String?,
            )
            .where((value) => value != null && value.trim().isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
    return ['All', ...options];
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _selectedStatus = 'All';
      _searchController.clear();
    });
  }

  Widget _buildSearchAndFilters({
    required List<String> categories,
    required List<String> statuses,
  }) {
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }
    if (!statuses.contains(_selectedStatus)) {
      _selectedStatus = 'All';
    }

    final hasActiveFilters =
        _searchQuery.trim().isNotEmpty ||
        _selectedCategory != 'All' ||
        _selectedStatus != 'All';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: 'Search food items...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedCategory,
                  items: categories,
                  icon: Icons.category_outlined,
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value ?? 'All'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  value: _selectedStatus,
                  items: statuses,
                  icon: Icons.eco_outlined,
                  onChanged: (value) =>
                      setState(() => _selectedStatus = value ?? 'All'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: hasActiveFilters ? _clearFilters : null,
                icon: const Icon(Icons.refresh),
                color: const Color(0xFF052A1E),
                tooltip: 'Clear filters',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF052A1E)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF34A853)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF052A1E),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InventoryCalendarScreen(),
                ),
              );
            },
            tooltip: 'View Calendar',
          ),
        ],
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
                    'No food items yet.\nEnter manually or tap the scanner to add some!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF666666), fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final categories = _filterOptions(docs, 'category');
          final statuses = _filterOptions(docs, 'freshnessStatus');
          final filteredDocs = docs.where(_matchesFilters).toList();

          return Column(
            children: [
              _buildSearchAndFilters(
                categories: categories,
                statuses: statuses,
              ),
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 56,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching food items found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: _clearFilters,
                              child: const Text(
                                'Clear search and filters',
                                style: TextStyle(color: Color(0xFF34A853)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InventoryDetailsScreen(item: doc),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: _InventoryCard(
                              data: data,
                              statusColor: _statusColor,
                            ),
                          );
                        },
                      ),
              ),
            ],
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

/// A single inventory card that shows the thumbnail, food name, freshness badge, category chip and estimated days remaining.
class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.data, required this.statusColor});

  final Map<String, dynamic> data;
  final Color Function(String?) statusColor;

  @override
  Widget build(BuildContext context) {
    final foodName = data['foodName'] as String? ?? 'Unknown Item';
    final category = data['category'] as String? ?? '';
    final freshnessStatus = data['freshnessStatus'] as String? ?? '';
    final freshnessScore = (data['freshnessScore'] as num?)?.toInt() ?? 0;
    final String expiryDate = data['expiryDate'] ?? 'N/A';
    int estimatedDaysRemaining =
        (data['estimatedDaysRemaining'] as num?)?.toInt() ?? 0;
    final thumbPath =
        (data['thumbnailPath'] as String?) ??
        (data['localImagePath'] as String?);

    final color = statusColor(freshnessStatus);

    try {
      final expiryParsed = DateFormat('MMM dd, yyyy').parse(expiryDate);
      final today = DateTime.now();

      final cleanToday = DateTime(today.year, today.month, today.day);
      final cleanExpiry = DateTime(
        expiryParsed.year,
        expiryParsed.month,
        expiryParsed.day,
      );
      estimatedDaysRemaining = cleanExpiry.difference(cleanToday).inDays;
    } catch (_) {
      // Keep the stored estimate if the legacy expiry value cannot be parsed.
    }

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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(thumbPath),
            ),
            const SizedBox(width: 14),

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
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
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
                        horizontal: 8,
                        vertical: 2,
                      ),
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
    if (_isNetworkLikePath(path)) {
      return Image.network(
        path!,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    if (path != null && !kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      }

      // Fallback: try to resolve path dynamically relative to current App Documents Directory
      return FutureBuilder<Directory>(
        future: getApplicationDocumentsDirectory(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final appDir = snapshot.data!;
            String? filename;
            if (path.contains('food_images')) {
              filename = path.substring(path.indexOf('food_images'));
            } else {
              filename = p.join('food_images', p.basename(path));
            }
            final resolvedFile = File(p.join(appDir.path, filename));
            if (resolvedFile.existsSync()) {
              return Image.file(
                resolvedFile,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              );
            }
          }
          return _placeholder();
        },
      );
    }
    return _placeholder();
  }

  bool _isNetworkLikePath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('http') || path.startsWith('data:') || path.startsWith('blob:');
  }

  Widget _placeholder() => Container(
    width: 90,
    height: 90,
    color: Colors.grey[200],
    child: const Icon(Icons.fastfood, color: Colors.grey),
  );
}
