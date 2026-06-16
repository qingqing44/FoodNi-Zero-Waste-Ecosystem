import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Full-page recipe detail view.
///
/// Receives a [Recipe] object passed via [Navigator.push] and renders:
/// - Hero cover image
/// - Title, source badge, prep time and difficulty meta-row
/// - Ingredient list
/// - Numbered cooking instructions
class RecipeDetailsScreen extends StatelessWidget {
  const RecipeDetailsScreen({super.key, required this.recipe});

  final Recipe recipe;

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
                  _buildSection('Ingredients', _buildIngredients()),
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

  Widget _buildIngredients() {
    if (recipe.ingredients.isEmpty) {
      return const Text(
        'No ingredients listed.',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recipe.ingredients.map((ing) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: CircleAvatar(
                  radius: 3,
                  backgroundColor: _accentGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _capitalize(ing),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number badge
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _darkGreen,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF333333),
                    height: 1.5,
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
