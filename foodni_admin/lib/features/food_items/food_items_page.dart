import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FoodItemsView extends StatefulWidget {
  const FoodItemsView({super.key});

  @override
  State<FoodItemsView> createState() => _FoodItemsViewState();
}

class _FoodItemsViewState extends State<FoodItemsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _sourceFilter = 'All';   // All | ai_scan | manual
  String _freshnessFilter = 'All'; // All | fresh | expiring_soon | expired
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _sourceOptions = ['All', 'ai_scan', 'manual'];
  static const _freshnessOptions = ['All', 'fresh', 'expiring_soon', 'expired'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _buildStream() {
    // Base: all foodItems; filtering done client-side to avoid composite indexes.
    return _firestore
        .collection('foodItems')
        .snapshots();
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    final q = _searchQuery.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Source filter
      if (_sourceFilter != 'All') {
        final src = (data['source'] as String?) ?? 'manual';
        if (src != _sourceFilter) return false;
      }

      // Freshness filter
      if (_freshnessFilter != 'All') {
        final status = (data['freshnessStatus'] as String?) ?? '';
        if (status != _freshnessFilter) return false;
      }

      // Search
      if (q.isNotEmpty) {
        final name = (data['foodName'] as String? ?? '').toLowerCase();
        final category = (data['category'] as String? ?? '').toLowerCase();
        if (!name.contains(q) && !category.contains(q)) return false;
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final aTs = (a.data() as Map)['scanDate'] as Timestamp?;
        final bTs = (b.data() as Map)['scanDate'] as Timestamp?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });
  }

  Future<void> _deleteItem(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Food Item'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('foodItems').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food item deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildItemImage(String? path,
      {required String source, double size = 56}) {
    if (path != null && path.startsWith('data:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              _buildImagePlaceholder(size: size, source: source),
        ),
      );
    }
    return _buildImagePlaceholder(size: size, source: source);
  }

  static Widget _buildImagePlaceholder(
      {required double size, required String source}) {
    final isAI = source == 'ai_scan';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isAI ? const Color(0xFFE8F0FE) : const Color(0xFFE8F3EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isAI ? Icons.qr_code_scanner : Icons.edit_note,
        size: size * 0.45,
        color: isAI ? const Color(0xFF1A73E8) : const Color(0xFF34A853),
      ),
    );
  }

  Future<void> _flagItem(
      String docId, String foodName, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Flag as Mislabeled'),
        content: const Text(
            'Flag this item as a mislabeled scan? The user will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Flag'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('foodItems').doc(docId).update({
        'flagged': true,
        'flaggedAt': FieldValue.serverTimestamp(),
        'flagReason': 'Mislabeled by AI scan',
      });
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'flag',
        'title': 'Item Flagged',
        'message':
            'An item in your inventory "$foodName" was flagged as a possible mislabeled scan. Please review it.',
        'foodItemId': docId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item flagged as mislabeled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _unflagItem(String docId) async {
    await _firestore.collection('foodItems').doc(docId).update({
      'flagged': false,
      'flagReason': FieldValue.delete(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item unflagged.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _sendReminder(
      String docId, String foodName, String userId) async {
    final messageController = TextEditingController(
      text:
          'Your food item "$foodName" is expiring soon. Please use or discard it to avoid waste.',
    );
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Reminder'),
        content: TextField(
          controller: messageController,
          maxLines: 4,
          decoration: InputDecoration(
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: 'Message…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent == true) {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'reminder',
        'title': 'Food Reminder',
        'message': messageController.text.trim(),
        'foodItemId': docId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }
    messageController.dispose();
  }

  void _showItemDetail(Map<String, dynamic> data, String docId) {
    final name = (data['foodName'] as String?) ?? 'Unknown';
    final category = (data['category'] as String?) ?? '–';
    final source = (data['source'] as String?) ?? 'manual';
    final isAI = source == 'ai_scan';
    final freshnessStatus = (data['freshnessStatus'] as String?) ?? '–';
    final freshnessScore = data['freshnessScore'];
    final quantity = data['quantity'];
    final rawUserId = (data['userId'] as String?) ?? '–';
    final displayUserId = rawUserId.length > 22
        ? '${rawUserId.substring(0, 22)}…'
        : rawUserId;
    final storage = (data['storageSuggestion'] as String?) ?? '–';
    final expiryDate = data['expiryDate'] as Timestamp?;
    final scanDate = data['scanDate'] as Timestamp?;
    final daysRemaining = data['estimatedDaysRemaining'];

    // AI scan only
    final calories = data['caloriesPer100g'];
    final description = (data['description'] as String?) ?? '';
    final detectedItems = _parseStringList(data['detectedItems']);
    final basicRecipes = _parseStringList(data['basicRecipes']);

    // Manual only
    final purchaseDate = data['purchaseDate'] as Timestamp?;
    final suggestedExpiryDate = data['suggestedExpiryDate'] as Timestamp?;

    final thumbnailPath = data['thumbnailPath'] as String?;
    final flagged = (data['flagged'] as bool?) ?? false;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            children: [
              // Top image (data URL only)
              if (thumbnailPath != null &&
                  thumbnailPath.startsWith('data:'))
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: Image.network(
                    thumbnailPath,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF052A1E),
                  borderRadius: thumbnailPath != null &&
                          thumbnailPath.startsWith('data:')
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(
                          top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2,
                        color: Color(0xFF34A853), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    _SourceBadge(source: source),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow('User ID', displayUserId),
                      _DetailRow('Category', category),
                      if (quantity != null)
                        _DetailRow('Quantity', quantity.toString()),
                      _DetailRow(
                        'Freshness',
                        '${freshnessStatus.replaceAll('_', ' ')}'
                            '${freshnessScore != null ? ' ($freshnessScore%)' : ''}',
                        valueColor: _freshnessColor(freshnessStatus),
                      ),
                      if (expiryDate != null)
                        _DetailRow(
                            'Expiry Date', _formatDate(expiryDate.toDate())),
                      if (daysRemaining != null)
                        _DetailRow('Days Remaining', '$daysRemaining days'),
                      _DetailRow('Storage', storage),
                      if (scanDate != null)
                        _DetailRow(
                          isAI ? 'Scan Date' : 'Added Date',
                          _formatDate(scanDate.toDate()),
                        ),

                      // Manual-only fields
                      if (!isAI && purchaseDate != null)
                        _DetailRow('Purchase Date',
                            _formatDate(purchaseDate.toDate())),
                      if (!isAI && suggestedExpiryDate != null)
                        _DetailRow('Suggested Expiry',
                            _formatDate(suggestedExpiryDate.toDate())),

                      // AI-scan-only fields
                      if (isAI && calories != null)
                        _DetailRow('Calories / 100g', '$calories kcal'),
                      if (isAI && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _DetailRow('Description', description),
                      ],
                      if (isAI && detectedItems.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Detected Items',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF052A1E),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        ...detectedItems.map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                const Icon(Icons.circle,
                                    size: 6, color: Color(0xFF34A853)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(item,
                                        style: const TextStyle(
                                            fontSize: 13))),
                              ]),
                            )),
                      ],
                      if (isAI && basicRecipes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Basic Recipes',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF052A1E),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        ...basicRecipes.map((recipe) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.restaurant_menu,
                                      size: 13,
                                      color: Color(0xFF34A853)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Text(recipe,
                                          style: const TextStyle(
                                              fontSize: 13))),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: flagged ? 'Unflag Item' : 'Flag as Mislabeled',
                      child: IconButton(
                        icon: Icon(
                          flagged
                              ? Icons.flag
                              : Icons.flag_outlined,
                          color: flagged ? Colors.green : Colors.amber,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (flagged) {
                            _unflagItem(docId);
                          } else {
                            _flagItem(docId, name, rawUserId);
                          }
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Send Reminder',
                      child: IconButton(
                        icon: const Icon(Icons.notifications_active_outlined,
                            color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context);
                          _sendReminder(docId, name, rawUserId);
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteItem(docId, name);
                      },
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF052A1E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Food Items',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF052A1E)),
              ),
              const SizedBox(height: 4),
              Text(
                'All food items saved by users — manual entries and AI scans.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // ── Filters row ───────────────────────────────────────────────
              Row(
                children: [
                  // Search
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search by name or category…',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.search,
                              size: 18, color: Colors.grey),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.grey),
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }),
                                ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Source filter
                  _FilterDropdown(
                    label: 'Source',
                    value: _sourceFilter,
                    options: _sourceOptions,
                    onChanged: (v) =>
                        setState(() => _sourceFilter = v ?? 'All'),
                  ),
                  const SizedBox(width: 12),

                  // Freshness filter
                  _FilterDropdown(
                    label: 'Freshness',
                    value: _freshnessFilter,
                    options: _freshnessOptions,
                    onChanged: (v) =>
                        setState(() => _freshnessFilter = v ?? 'All'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
            ],
          ),
        ),

        // ── Table ────────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF34A853)));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}'));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filtered = _applyFilters(
                  allDocs.cast<QueryDocumentSnapshot>());

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        allDocs.isEmpty
                            ? 'No food items found.'
                            : 'No items match the current filters.',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Count bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF052A1E)),
                        ),
                        if (filtered.length != allDocs.length)
                          Text(
                            ' of ${allDocs.length} total',
                            style: const TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  // Scrollable list
                  Expanded(
                    child: ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(32, 4, 32, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final doc = filtered[i];
                        final data =
                            doc.data() as Map<String, dynamic>;
                        final name =
                            (data['foodName'] as String?) ??
                                'Unknown';
                        final category =
                            (data['category'] as String?) ?? '–';
                        final source =
                            (data['source'] as String?) ?? 'manual';
                        final freshness =
                            (data['freshnessStatus'] as String?) ??
                                '–';
                        final scanDate =
                            data['scanDate'] as Timestamp?;
                        final userId =
                            (data['userId'] as String?) ?? '–';
                        final daysRemaining =
                            data['estimatedDaysRemaining'];
                        final thumbnailPath =
                            data['thumbnailPath'] as String?;
                        final flagged =
                            (data['flagged'] as bool?) ?? false;

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0xFFEEEEEE)),
                          ),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                _showItemDetail(data, doc.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  _buildItemImage(
                                    thumbnailPath,
                                    source: source,
                                    size: 56,
                                  ),
                                  const SizedBox(width: 14),

                                  // Name + meta
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        Color(0xFF052A1E)),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (flagged) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10),
                                                  border: Border.all(
                                                      color: Colors.red
                                                          .shade200),
                                                ),
                                                child: Text(
                                                  'Flagged',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color:
                                                        Colors.red.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          category,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Freshness badge
                                  Expanded(
                                    flex: 2,
                                    child: _FreshnessBadge(
                                        status: freshness,
                                        daysRemaining:
                                            daysRemaining),
                                  ),

                                  // Source badge
                                  Expanded(
                                    flex: 2,
                                    child: _SourceBadge(
                                        source: source),
                                  ),

                                  // User ID (truncated)
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      userId.length > 12
                                          ? '${userId.substring(0, 12)}…'
                                          : userId,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontFamily: 'monospace'),
                                    ),
                                  ),

                                  // Date
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      scanDate != null
                                          ? _formatDate(
                                              scanDate.toDate())
                                          : '–',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey),
                                    ),
                                  ),

                                  // Flag / Unflag
                                  IconButton(
                                    icon: Icon(
                                      flagged
                                          ? Icons.flag
                                          : Icons.flag_outlined,
                                      size: 18,
                                      color: flagged
                                          ? Colors.green
                                          : Colors.amber,
                                    ),
                                    tooltip: flagged
                                        ? 'Unflag Item'
                                        : 'Flag as Mislabeled',
                                    onPressed: () => flagged
                                        ? _unflagItem(doc.id)
                                        : _flagItem(doc.id, name,
                                            userId),
                                  ),

                                  // Reminder
                                  IconButton(
                                    icon: const Icon(
                                        Icons.notifications_active_outlined,
                                        size: 18,
                                        color: Colors.blue),
                                    tooltip: 'Send Reminder',
                                    onPressed: () => _sendReminder(
                                        doc.id, name, userId),
                                  ),

                                  // Delete
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () =>
                                        _deleteItem(doc.id, name),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static Color _freshnessColor(String status) {
    return switch (status) {
      'fresh' => const Color(0xFF34A853),
      'expiring_soon' => const Color(0xFFF57C00),
      'expired' => Colors.red,
      _ => Colors.grey,
    };
  }

  static String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? const Color(0xFF052A1E),
                  fontWeight: valueColor != null
                      ? FontWeight.bold
                      : FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Freshness badge ───────────────────────────────────────────────────────────

class _FreshnessBadge extends StatelessWidget {
  const _FreshnessBadge({required this.status, this.daysRemaining});
  final String status;
  final dynamic daysRemaining;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'fresh' => (const Color(0xFF34A853), const Color(0xFFE8F5E9)),
      'expiring_soon' => (
          const Color(0xFFF57C00),
          const Color(0xFFFFF3E0)
        ),
      'expired' => (Colors.red, const Color(0xFFFFEBEE)),
      _ => (Colors.grey, const Color(0xFFF5F5F5)),
    };
    final label = status == '–' || status.isEmpty
        ? '–'
        : status.replaceAll('_', ' ');
    final days = daysRemaining != null ? ' · ${daysRemaining}d' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '$label$days',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Source badge ──────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final isAI = source == 'ai_scan';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAI
            ? const Color(0xFFE8F0FE)
            : const Color(0xFFE8F3EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAI ? Icons.auto_awesome : Icons.edit_note,
            size: 11,
            color: isAI
                ? const Color(0xFF1A73E8)
                : const Color(0xFF34A853),
          ),
          const SizedBox(width: 4),
          Text(
            isAI ? 'AI Scan' : 'Manual',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAI
                    ? const Color(0xFF1A73E8)
                    : const Color(0xFF34A853)),
          ),
        ],
      ),
    );
  }
}

// ── Filter dropdown ───────────────────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(
                      o == 'All' ? '$label: All' : o.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(
              color: Color(0xFF052A1E), fontSize: 13),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
