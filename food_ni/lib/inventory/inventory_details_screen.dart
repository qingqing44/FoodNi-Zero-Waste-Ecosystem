import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../notifications/expiry_notification_service.dart';
import 'edit_item_screen.dart';
import 'food_status_utils.dart';
import '../storage/storage_guide_screen.dart';

class InventoryDetailsScreen extends StatefulWidget {
  final QueryDocumentSnapshot item;

  const InventoryDetailsScreen({super.key, required this.item});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  bool _isDeleting = false;

  bool _isNetworkLikePath(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('http') ||
        path.startsWith('data:') ||
        path.startsWith('blob:');
  }

  Future<void> _editItem() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(item: widget.item),
      ),
    );

    if (!mounted || updated != true) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Item updated successfully')),
    );
  }

  // Method to handle item deletion from Firestore
  Future<void> _removeItem() async {
    // Show a confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Remove Item',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${widget.item['foodName'] ?? 'this item'}" from your inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await ExpiryNotificationService.instance.cancelReminder(widget.item.id);

      // Use the unique Firestore document ID to delete the exact record
      await FirebaseFirestore.instance
          .collection('foodItems')
          .doc(widget.item.id)
          .delete();

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        // Go back to the previous screen (Inventory List)
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Item successfully removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.item.data() as Map<String, dynamic>;
    const primaryColor = Color(0xFF052A1E);

    final String foodName = data['foodName'] ?? 'Unknown Item';
    final String category = data['category'] ?? 'Uncategorized';
    final String quantity = data['quantity'] ?? '1 unit';
    final String expiryDate = data['expiryDate'] ?? 'N/A';
    final String? thumbPath =
        (data['thumbnailPath'] as String?) ??
        (data['localImagePath'] as String?);
    int daysRemaining = (data['estimatedDaysRemaining'] as num?)?.toInt() ?? 0;
    final parsedDays = FoodStatusUtils.daysRemainingFromString(expiryDate);
    if (parsedDays != null) {
      daysRemaining = parsedDays;
    }
    final freshnessStatus = FoodStatusUtils.statusForDays(daysRemaining);
    final statusColor = FoodStatusUtils.statusColor(freshnessStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryColor),
        title: Text(
          foodName,
          style: const TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : _editItem,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit item',
          ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Food Image Display Banner
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isNetworkLikePath(thumbPath)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                thumbPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _placeholderDetails(),
                              ),
                            )
                          : thumbPath != null && !kIsWeb
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildLocalImageDetails(thumbPath),
                            )
                          : _placeholderDetails(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Freshness Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Freshness Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                        if (freshnessStatus.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              freshnessStatus.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Details Information Block
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(Icons.category, 'Category', category),
                        const Divider(height: 24, color: Color(0xFFF0F0F0)),
                        _buildDetailRow(Icons.scale, 'Quantity', quantity),
                        const Divider(height: 24, color: Color(0xFFF0F0F0)),
                        _buildDetailRow(
                          Icons.calendar_today,
                          'Expiry Date',
                          expiryDate,
                        ),
                        const Divider(height: 24, color: Color(0xFFF0F0F0)),
                        _buildDetailRow(
                          Icons.hourglass_bottom,
                          'Days Remaining',
                          daysRemaining >= 0
                              ? '$daysRemaining days left'
                              : 'Expired',
                          valueColor: statusColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildReminderCard(freshnessStatus),
                  const SizedBox(height: 20),

                  // ── Storage Guide or Expired Warning ──────────────────────
                  if (freshnessStatus == FoodStatusUtils.expired)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red.shade400,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Food is Expired',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'This item has passed its expiry date. Please check carefully before consuming or discard it if unsafe.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StorageGuideScreen(
                              foodName: foodName,
                              category: category,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF34A853)),
                        foregroundColor: const Color(0xFF052A1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.thermostat_rounded,
                        color: Color(0xFF34A853),
                      ),
                      label: const Text(
                        'View Storage Guide',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),

                  // ── Remove Button ──────────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: _removeItem,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 22),
                    label: const Text(
                      'Remove From Inventory',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _placeholderDetails() =>
      const Center(child: Icon(Icons.fastfood, size: 64, color: Colors.grey));

  Widget _buildReminderCard(String freshnessStatus) {
    final isExpired = freshnessStatus == FoodStatusUtils.expired;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: Color(0xFF34A853),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isExpired
                  ? 'Reminder: Not scheduled for expired items'
                  : 'Reminder: 1 day before expiry',
              style: const TextStyle(
                color: Color(0xFF052A1E),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalImageDetails(String path) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        errorBuilder: (_, _, _) => _placeholderDetails(),
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
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (_, _, _) => _placeholderDetails(),
            );
          }
        }
        return _placeholderDetails();
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF34A853), size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF052A1E),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
