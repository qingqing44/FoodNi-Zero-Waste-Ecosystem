import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/food_item.dart';

/// Full-page recipe detail view.
///
/// Receives a [Recipe] object passed via [Navigator.push] and renders:
/// - Hero cover image
/// - Title, source badge, prep time and difficulty meta-row
/// - Ingredient list
/// - Numbered cooking instructions
class RecipeDetailsScreen extends StatelessWidget {
  const RecipeDetailsScreen({
    super.key,
    required this.recipe,
    this.highlightItems,
  });

  final Recipe recipe;
  final List<FoodItem>? highlightItems;

  // ── Colors (shared with rest of FoodNi) ────────────────────────────────────
  static const _darkGreen = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);
  static const _bgColor = Color(0xFFF9F8F4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(),
                  const SizedBox(height: 12),
                  _buildMetaRow(),
                  const SizedBox(height: 24),
                  _buildSection('Ingredients', _buildIngredientsSection()),
                  const SizedBox(height: 24),
                  _buildSection('Instructions', _buildInstructions()),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── App bar with hero image ────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _darkGreen,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: recipe.imageUrl.isNotEmpty
            ? Image.network(
                recipe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imagePlaceholder(),
              )
            : _imagePlaceholder(),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    color: const Color(0xFFD0E8D8),
    child: const Center(
      child: Icon(Icons.restaurant, size: 64, color: Color(0xFF34A853)),
    ),
  );

  // ── Title + source badge ───────────────────────────────────────────────────

  Widget _buildTitleRow() {
    final isFirebase = recipe.source == 'firebase';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            recipe.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _SourceBadge(isFirebase: isFirebase),
      ],
    );
  }

  // ── Meta row: match %, time, difficulty ───────────────────────────────────

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (recipe.matchPercentage > 0)
          _MetaChip(
            icon: Icons.check_circle_outline,
            label: '${recipe.matchPercentage.toStringAsFixed(0)}% match',
            color: _accentGreen,
          ),
        _MetaChip(
          icon: Icons.access_time,
          label: recipe.preparationTime > 0
              ? '${recipe.preparationTime} min'
              : 'Time N/A',
          color: _darkGreen,
        ),
        _MetaChip(
          icon: Icons.bolt,
          label: recipe.difficulty,
          color: _darkGreen,
        ),
      ],
    );
  }

  // ── Section builder ────────────────────────────────────────────────────────

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkGreen,
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  // ── Ingredients list ───────────────────────────────────────────────────────

  Widget _buildIngredientsSection() {
    if (highlightItems != null) {
      return _buildIngredients(highlightItems!);
    }

    return FutureBuilder<List<FoodItem>>(
      future: _fetchInventory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(color: _accentGreen),
            ),
          );
        }
        final items = snapshot.data ?? [];
        return _buildIngredients(items);
      },
    );
  }

  Future<List<FoodItem>> _fetchInventory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('foodItems')
          .where('userId', isEqualTo: user.uid)
          .get();
      return snapshot.docs
          .map((doc) => FoodItem.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  bool _isMatched(String recipeIngredient, List<FoodItem> items) {
    final normIng = recipeIngredient.trim().toLowerCase();
    for (final item in items) {
      final normItem = item.name.trim().toLowerCase();
      if (normIng == normItem || normIng.contains(normItem) || normItem.contains(normIng)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildIngredients(List<FoodItem> items) {
    if (recipe.ingredients.isEmpty) {
      return const Text(
        'No ingredients listed.',
        style: TextStyle(color: Colors.grey),
      );
    }

    final matched = <String>[];
    final missing = <String>[];

    for (final ing in recipe.ingredients) {
      if (_isMatched(ing, items)) {
        matched.add(ing);
      } else {
        missing.add(ing);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Availability summary banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: missing.isEmpty
                ? const Color(0xFFE8F3EF)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: missing.isEmpty
                  ? const Color(0xFF34A853).withValues(alpha: 0.3)
                  : const Color(0xFFE28743).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                missing.isEmpty ? Icons.check_circle : Icons.shopping_cart_outlined,
                color: missing.isEmpty ? _accentGreen : const Color(0xFFE28743),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missing.isEmpty
                      ? 'You have all the ingredients for this recipe!'
                      : 'You have ${matched.length} of ${recipe.ingredients.length} ingredients. You are missing ${missing.length} items.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: missing.isEmpty ? _darkGreen : const Color(0xFF052A1E),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ingredients chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipe.ingredients.map((ing) {
            final hasIt = _isMatched(ing, items);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: hasIt ? const Color(0xFFE8F3EF) : const Color(0xFFFEEBEE).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasIt
                      ? const Color(0xFF34A853).withValues(alpha: 0.3)
                      : Colors.red.shade100,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasIt ? Icons.check_box_outlined : Icons.add_shopping_cart_outlined,
                    size: 16,
                    color: hasIt ? _accentGreen : Colors.red.shade400,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _capitalize(ing),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasIt ? _darkGreen : Colors.red.shade900,
                      decoration: hasIt ? null : TextDecoration.lineThrough,
                      decorationColor: Colors.red.shade300,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Instructions list ──────────────────────────────────────────────────────

  Widget _buildInstructions() {
    if (recipe.instructions.isEmpty) {
      return const Text(
        'No instructions available.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recipe.instructions.asMap().entries.map((entry) {
        final stepNumber = entry.key + 1;
        final step = entry.value;
        final isLast = stepNumber == recipe.instructions.length;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left timeline indicator
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3EF),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accentGreen, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '$stepNumber',
                        style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Right content card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isFirebase});

  final bool isFirebase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isFirebase
            ? const Color(0xFFE8F3EF)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFirebase
              ? const Color(0xFF34A853).withValues(alpha: 0.4)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFirebase ? Icons.local_fire_department : Icons.public,
            size: 12,
            color: isFirebase ? const Color(0xFF34A853) : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            isFirebase ? 'FoodNi' : 'External',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isFirebase
                  ? const Color(0xFF34A853)
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
