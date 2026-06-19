import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';
import '../services/recipes/recipe_service.dart';
import 'recipe_details_screen.dart';

/// Screen displaying recipes matching a combination of selected food items.
/// Shows matched and missing ingredients clearly for each recipe card.
class RecipeMatchScreen extends StatefulWidget {
  const RecipeMatchScreen({super.key, required this.selectedItems});

  final List<FoodItem> selectedItems;

  @override
  State<RecipeMatchScreen> createState() => _RecipeMatchScreenState();
}

class _RecipeMatchScreenState extends State<RecipeMatchScreen> {
  bool _isLoading = true;
  List<Recipe> _recipes = [];
  String? _errorMessage;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const _darkGreen = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);
  static const _bgColor = Color(0xFFF9F8F4);
  static const _warningOrange = Color(0xFFE28743);

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    if (widget.selectedItems.isEmpty) {
      setState(() {
        _isLoading = false;
        _recipes = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use RecipeService to fetch recommendations scored by the selected items.
      final results = await RecipeService().getRecommendedRecipes(widget.selectedItems);
      setState(() {
        _recipes = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not retrieve matching recipes. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  // Helper to normalize and check if a recipe ingredient is matched by selected items.
  bool _isMatched(String recipeIngredient, List<FoodItem> selectedItems) {
    final normIng = recipeIngredient.trim().toLowerCase();
    for (final item in selectedItems) {
      final normItem = item.name.trim().toLowerCase();
      // Match if equal, or if one contains the other.
      if (normIng == normItem || normIng.contains(normItem) || normItem.contains(normIng)) {
        return true;
      }
    }
    return false;
  }

  List<String> _getMatchedIngredients(Recipe recipe) {
    return recipe.ingredients.where((ing) => _isMatched(ing, widget.selectedItems)).toList();
  }

  List<String> _getMissingIngredients(Recipe recipe) {
    return recipe.ingredients.where((ing) => !_isMatched(ing, widget.selectedItems)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkGreen),
        title: const Text(
          'Recipe Matcher',
          style: TextStyle(
            color: _darkGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // Displays a summary of the combined ingredients selected by the user.
  Widget _buildSelectionHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMBINING INGREDIENTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _accentGreen,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedItems.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3EF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF34A853).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: _accentGreen),
                    const SizedBox(width: 4),
                    Text(
                      _capitalize(item.name),
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _accentGreen),
            SizedBox(height: 16),
            Text(
              'Finding matching recipes...',
              style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchMatches,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No matching recipes found.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try selecting more or different ingredients to see match recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back to Inventory'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final matchedIngs = _getMatchedIngredients(recipe);
    final missingIngs = _getMissingIngredients(recipe);
    final matchPct = recipe.matchPercentage > 0
        ? recipe.matchPercentage
        : ((matchedIngs.length / recipe.ingredients.length) * 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecipeDetailsScreen(
                  recipe: recipe,
                  highlightItems: widget.selectedItems,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image + Badges
              Stack(
                children: [
                  recipe.imageUrl.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                  // Match % Badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _darkGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${matchPct.toStringAsFixed(0)}% Match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Source Badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: recipe.source == 'firebase'
                            ? _accentGreen.withValues(alpha: 0.95)
                            : Colors.grey.shade600.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        recipe.source == 'firebase' ? 'FoodNi' : 'External',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _darkGreen,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Prep time & Difficulty row
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          recipe.preparationTime > 0 ? '${recipe.preparationTime} min' : '–',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.bolt, size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(
                          recipe.difficulty,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),

                    // Owned ingredients section
                    if (matchedIngs.isNotEmpty) ...[
                      const Text(
                        'INGREDIENTS YOU HAVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _accentGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        matchedIngs.map(_capitalize).join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _darkGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Missing ingredients section
                    if (missingIngs.isNotEmpty) ...[
                      const Text(
                        'MISSING INGREDIENTS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _warningOrange,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        missingIngs.map(_capitalize).join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: _accentGreen),
                          SizedBox(width: 6),
                          Text(
                            'You have all ingredients!',
                            style: TextStyle(
                              fontSize: 12,
                              color: _accentGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        height: 140,
        color: const Color(0xFFD0E8D8),
        child: const Center(
          child: Icon(Icons.restaurant, color: _accentGreen, size: 40),
        ),
      );

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
