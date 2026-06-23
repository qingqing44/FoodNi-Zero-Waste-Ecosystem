import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RecipeReviewView extends StatefulWidget {
  const RecipeReviewView({super.key});

  @override
  State<RecipeReviewView> createState() => _RecipeReviewViewState();
}

class _RecipeReviewViewState extends State<RecipeReviewView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _tabs = ['Pending', 'Approved', 'Rejected', 'All'];
  static const _statusFilters = ['pending', 'approved', 'rejected', null];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Returns a query that avoids composite indexes by NOT using orderBy on the
  /// server. Sorting is handled client-side in [_buildTabContent].
  Query<Map<String, dynamic>> _buildQuery(String? statusFilter) {
    if (statusFilter != null) {
      return _firestore
          .collection('recipes')
          .where('status', isEqualTo: statusFilter);
    }
    // "All" tab: only community recipes (those that have a status field).
    // We filter client-side instead of using isNotEqualTo to avoid index needs.
    return _firestore.collection('recipes');
  }

  Future<void> _updateStatus(String docId, String newStatus,
      {String? rejectionReason}) async {
    final Map<String, dynamic> update = {
      'status': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      update['rejectionReason'] = rejectionReason;
    } else if (newStatus == 'approved') {
      update['rejectionReason'] = FieldValue.delete();
    }
    await _firestore.collection('recipes').doc(docId).update(update);
  }

  Future<void> _showApproveDialog(
      BuildContext ctx, String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Recipe',
            style: TextStyle(color: Color(0xFF052A1E))),
        content: Text('Approve "$title"? It will appear in the community feed.'),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34A853),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(docId, 'approved');
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Recipe approved and published.'),
            backgroundColor: Color(0xFF34A853),
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(
      BuildContext ctx, String docId, String title) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Recipe',
            style: TextStyle(color: Color(0xFF052A1E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "$title"? The author will not see a specific reason.'),
            const SizedBox(height: 16),
            const Text('Reason (optional, for admin records):',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Duplicate, inappropriate content…',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(docId, 'rejected',
          rejectionReason: reasonController.text.trim());
      reasonController.dispose();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Recipe rejected.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      reasonController.dispose();
    }
  }

  void _showRecipeDetail(BuildContext ctx, Map<String, dynamic> data,
      String docId, String status) {
    final isSeeded = status == 'seeded';

    final title = (data['title'] as String?) ?? 'Untitled';
    final description = (data['description'] as String?) ?? '';
    final authorName = (data['authorName'] as String?) ?? '';
    final userId = (data['userId'] as String?) ?? '';
    final cookingTime = (data['cookingTime'] as String?) ?? '';
    final preparationTime = data['preparationTime'];
    final difficulty = (data['difficulty'] as String?) ?? '';
    final steps = (data['steps'] as String?) ?? '';
    final instructions = _parseList(data['instructions']);
    final ingredients = _parseList(data['ingredients']);
    final imageBase64 = data['imageBase64'] as String?;
    final imageUrl = data['imageUrl'] as String?;
    final rejectionReason = data['rejectionReason'] as String?;

    // Prefer cookingTime; fall back to preparationTime (int minutes).
    final displayTime = cookingTime.isNotEmpty
        ? cookingTime
        : (preparationTime != null ? '$preparationTime min' : '');

    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header image
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: _buildImage(imageBase64, imageUrl: imageUrl, height: 200),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF052A1E))),
                          ),
                          _StatusBadge(status: status),
                        ],
                      ),
                      if (authorName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('by $authorName',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                      // Show truncated userId for community recipes.
                      if (!isSeeded && userId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'User: ${userId.length > 22 ? '${userId.substring(0, 22)}…' : userId}',
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
                      ],
                      if (displayTime.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.access_time,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(displayTime,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ]),
                      ],
                      if (difficulty.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.bar_chart,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('Difficulty: $difficulty',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ]),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Description',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E))),
                        const SizedBox(height: 6),
                        Text(description,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5)),
                      ],
                      if (ingredients.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Ingredients',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E))),
                        const SizedBox(height: 6),
                        ...ingredients.map((ing) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                const Icon(Icons.circle,
                                    size: 6, color: Color(0xFF34A853)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(ing,
                                        style: const TextStyle(
                                            fontSize: 14))),
                              ]),
                            )),
                      ],
                      // Numbered list when instructions list present;
                      // fall back to plain-text steps string.
                      if (instructions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Instructions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E))),
                        const SizedBox(height: 6),
                        ...instructions.asMap().entries.map((entry) =>
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF052A1E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(entry.value,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5)),
                                  ),
                                ],
                              ),
                            )),
                      ] else if (steps.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Steps',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E))),
                        const SizedBox(height: 6),
                        Text(steps,
                            style: const TextStyle(
                                fontSize: 14, height: 1.6)),
                      ],
                      if (rejectionReason != null &&
                          rejectionReason.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rejection note: $rejectionReason',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade700),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Action buttons only for community recipes that still need action.
              if (status == 'pending' || status == 'rejected')
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    children: [
                      if (status != 'approved')
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A853),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showApproveDialog(ctx, docId, title);
                            },
                          ),
                        ),
                      if (status != 'approved' && status != 'rejected')
                        const SizedBox(width: 12),
                      if (status != 'rejected')
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showRejectDialog(ctx, docId, title);
                            },
                          ),
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

  Widget _buildTabContent(String? statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildQuery(statusFilter).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF34A853)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // For status-filtered tabs the Firestore query already limits results.
        // For the "All" tab (statusFilter == null) we show every doc — seeded
        // and community alike — sorted by createdAt descending client-side.
        var docs = (snapshot.data?.docs ?? []).toList();

        docs.sort((a, b) {
          final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
          final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  statusFilter == null
                      ? 'No recipes found.'
                      : 'No $statusFilter recipes.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bool isSeeded = !data.containsKey('status');
            final status =
                isSeeded ? 'seeded' : ((data['status'] as String?) ?? 'pending');
            final title = (data['title'] as String?) ?? 'Untitled';
            final authorName =
                (data['authorName'] as String?) ?? 'Anonymous';
            final cookingTime =
                (data['cookingTime'] as String?) ?? '';
            final imageBase64 = data['imageBase64'] as String?;
            final imageUrl = data['imageUrl'] as String?;
            final ingredients = _parseList(data['ingredients']);
            final createdAt = data['createdAt'] as Timestamp?;

            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              color: Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    _showRecipeDetail(ctx, data, doc.id, status),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildImage(imageBase64,
                            imageUrl: imageUrl, height: 72, width: 72),
                      ),
                      const SizedBox(width: 16),
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF052A1E)),
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(status: status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'by $authorName',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            if (cookingTime.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.access_time,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(cookingTime,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey)),
                              ]),
                            ],
                            if (ingredients.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.list_alt,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${ingredients.length} ingredient${ingredients.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                ),
                              ]),
                            ],
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(createdAt.toDate()),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Actions
                      if (status == 'pending')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionButton(
                              icon: Icons.check,
                              color: const Color(0xFF34A853),
                              tooltip: 'Approve',
                              onTap: () =>
                                  _showApproveDialog(ctx, doc.id, title),
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              icon: Icons.close,
                              color: Colors.red,
                              tooltip: 'Reject',
                              onTap: () =>
                                  _showRejectDialog(ctx, doc.id, title),
                            ),
                          ],
                        )
                      else if (status == 'approved')
                        _ActionButton(
                          icon: Icons.close,
                          color: Colors.red,
                          tooltip: 'Revoke Approval',
                          onTap: () =>
                              _showRejectDialog(ctx, doc.id, title),
                        )
                      else if (status == 'rejected')
                        _ActionButton(
                          icon: Icons.restore,
                          color: const Color(0xFF34A853),
                          tooltip: 'Re-approve',
                          onTap: () =>
                              _showApproveDialog(ctx, doc.id, title),
                        ),
                      // seeded recipes: no action buttons
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recipe Review',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF052A1E)),
              ),
              const SizedBox(height: 4),
              Text(
                'Review and approve community-submitted recipes before they appear in the feed.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF052A1E),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF34A853),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: List.generate(
              _tabs.length,
              (i) => _buildTabContent(_statusFilters[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildImage(String? imageBase64,
      {String? imageUrl, double height = 200, double? width}) {
    Uint8List? bytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        bytes = base64Decode(imageBase64);
      } catch (_) {}
    }

    if (bytes != null) {
      return Image.memory(
        bytes,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height, width),
      );
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _imagePlaceholder(height, width),
      );
    }

    return _imagePlaceholder(height, width);
  }

  Widget _imagePlaceholder(double height, double? width) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: const Color(0xFFE8F3EF),
      child: const Icon(Icons.restaurant, color: Color(0xFF34A853), size: 28),
    );
  }

  static List<String> _parseList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Status badge widget ───────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (status) {
      'approved' => (
          const Color(0xFF34A853),
          const Color(0xFFE8F5E9),
          'Approved'
        ),
      'rejected' => (Colors.red, const Color(0xFFFFEBEE), 'Rejected'),
      'seeded' => (Colors.teal, const Color(0xFFE0F2F1), 'Seeded'),
      _ => (const Color(0xFFF57C00), const Color(0xFFFFF3E0), 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

// ── Action button widget ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
