import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/recipe_migration_service.dart';
import '../settings/profile_page.dart';
import '../users/user_management_page.dart';
import '../recipes/recipe_review_page.dart';
import '../food_items/food_items_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final DashboardService _dashboardService = DashboardService();

  @override
  void initState() {
    super.initState();
    RecipeMigrationService.migrateUnstatuedRecipes();
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardHomeView(
          dashboardService: _dashboardService,
          onNavigateToRecipes: () => setState(() => _selectedIndex = 3),
        );
      case 1:
        return const UserManagementView();
      case 2:
        return const FoodItemsView();
      case 3:
        return const RecipeReviewView();
      case 4:
        return const ProfileView();
      default:
        return const Center(child: Text('Module coming soon...'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────────
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'FoodNi Workspace',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF052A1E),
                    ),
                  ),
                ),
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.people, 'Users', 1),
                _buildNavItem(Icons.fastfood, 'Food Items', 2),
                _buildNavItem(Icons.menu_book, 'Recipes', 3),
                const Spacer(),
                const Divider(),
                _buildNavItem(Icons.settings, 'Profile & Settings', 4),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Topbar
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedIndex = 4),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F3EF),
                          child: Icon(Icons.admin_panel_settings,
                              color: Color(0xFF052A1E)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        onPressed: () => AuthService().logout(),
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBodyContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isActive = _selectedIndex == index;
    return Container(
      color: isActive ? const Color(0xFFE8F3EF) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon,
            color:
                isActive ? const Color(0xFF052A1E) : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFF052A1E) : Colors.grey,
            fontWeight:
                isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// ── Dashboard Home view ───────────────────────────────────────────────────────

class _DashboardHomeView extends StatelessWidget {
  const _DashboardHomeView({
    required this.dashboardService,
    required this.onNavigateToRecipes,
  });
  final DashboardService dashboardService;
  final VoidCallback onNavigateToRecipes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF052A1E)),
          ),
          const SizedBox(height: 24),

          // ── Live stats row ────────────────────────────────────────────────
          FutureBuilder<DashboardStats>(
            future: dashboardService.getAllStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data;
              final loading =
                  snapshot.connectionState != ConnectionState.done;

              String val(int? v) =>
                  loading ? '…' : (v?.toString() ?? '0');

              return Column(
                children: [
                  // Row 1: Users, Food Items, AI Scans, Community Recipes
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Users',
                          value: val(stats?.totalUsers),
                          icon: Icons.group,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Food Items Saved',
                          value: val(stats?.totalFoodItems),
                          icon: Icons.inventory,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'AI Food Scans',
                          value: val(stats?.totalFoodScans),
                          icon: Icons.qr_code_scanner,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Recipes Uploaded',
                          value: val(stats?.totalRecipes),
                          icon: Icons.menu_book,
                          color: const Color(0xFF34A853),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Row 2: Recipe moderation breakdown
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Review',
                          value: val(stats?.pendingRecipes),
                          icon: Icons.pending_actions,
                          color: const Color(0xFFF57C00),
                          badge: (stats?.pendingRecipes ?? 0) > 0
                              ? '!'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Approved Recipes',
                          value: val(stats?.approvedRecipes),
                          icon: Icons.check_circle,
                          color: const Color(0xFF34A853),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Approval rate card (computed from stats)
                      Expanded(
                        child: _StatCard(
                          title: 'Approval Rate',
                          value: (stats == null || stats.totalRecipes == 0)
                              ? (loading ? '…' : 'N/A')
                              : '${((stats.approvedRecipes / stats.totalRecipes) * 100).toStringAsFixed(0)}%',
                          icon: Icons.insights,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // FoodNi-curated seeded recipes
                      Expanded(
                        child: _StatCard(
                          title: 'FoodNi Recipes',
                          value: val(stats?.seededRecipes),
                          icon: Icons.auto_stories,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 36),

          // ── Recent pending recipes ────────────────────────────────────────
          _PendingRecipesPreview(
            dashboardService: dashboardService,
            onViewAll: onNavigateToRecipes,
          ),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ── Recent pending recipes preview ────────────────────────────────────────────

class _PendingRecipesPreview extends StatelessWidget {
  const _PendingRecipesPreview({
    required this.dashboardService,
    required this.onViewAll,
  });
  final DashboardService dashboardService;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Recipe Approvals',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('View All'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF34A853)),
              onPressed: onViewAll,
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: dashboardService.getRecentPendingRecipesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF34A853)));
            }

            // Sort client-side (no composite index required).
          final docs = [...(snapshot.data?.docs ?? [])]..sort((a, b) {
              final aTs = (a.data() as Map)['createdAt'] as Timestamp?;
              final bTs = (b.data() as Map)['createdAt'] as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });
          final recentDocs = docs.take(5).toList();

            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3EF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xFF34A853)),
                    SizedBox(width: 12),
                    Text(
                      'No recipes pending review. All caught up!',
                      style: TextStyle(color: Color(0xFF052A1E)),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: recentDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final title =
                    (data['title'] as String?) ?? 'Untitled';
                final authorName =
                    (data['authorName'] as String?) ?? 'Anonymous';
                final createdAt = data['createdAt'] as Timestamp?;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFFFF3E0),
                        child: Icon(Icons.restaurant,
                            color: Color(0xFFF57C00), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'by $authorName${createdAt != null ? ' · ${_formatDate(createdAt.toDate())}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF57C00)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
