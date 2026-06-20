import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../models/recipe.dart';
import '../services/recipes/ai_recipe_service.dart';
import 'recipe_details_screen.dart';

class AiRecipeScreen extends StatefulWidget {
  const AiRecipeScreen({super.key, required this.selectedItems});

  final List<FoodItem> selectedItems;

  @override
  State<AiRecipeScreen> createState() => _AiRecipeScreenState();
}

class _AiRecipeScreenState extends State<AiRecipeScreen> {
  static const _brandColor = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  final _service = AiRecipeService();
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateRecipes();
  }

  Future<void> _generateRecipes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipes = await _service.generateRecipes(widget.selectedItems);
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } on AiRecipeException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not generate recipes right now. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _brandColor),
        title: const Text(
          'AI Recipe Ideas',
          style: TextStyle(color: _brandColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Generate again',
              onPressed: _generateRecipes,
            ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _error != null ? _buildError() : _buildRecipes(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _accentGreen),
            const SizedBox(height: 20),
            const Text(
              'Creating recipes from your selected ingredients...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _brandColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prioritising food that should be used sooner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 54, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Recipe generation is unavailable',
              style: TextStyle(
                color: _brandColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateRecipes,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipes() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _buildSelectionSummary(),
        const SizedBox(height: 16),
        ..._recipes.map(_buildRecipeCard),
        const SizedBox(height: 4),
        ElevatedButton.icon(
          onPressed: _generateRecipes,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate New Ideas'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF052A1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFFB8E6C5), size: 20),
              SizedBox(width: 8),
              Text(
                'AI-GENERATED FOR YOUR INVENTORY',
                style: TextStyle(
                  color: Color(0xFFB8E6C5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.selectedItems
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _capitalize(item.name),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final usedItems = recipe.ingredients.where(_isSelectedIngredient).toList();

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
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(
              recipe: recipe,
              highlightItems: widget.selectedItems,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecipeVisual(recipe),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        color: _brandColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 15, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text('${recipe.preparationTime} min', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.bolt_rounded, size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(recipe.difficulty, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    if (usedItems.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text(
                        'USES FROM YOUR INVENTORY',
                        style: TextStyle(
                          color: _accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        usedItems.map(_capitalize).join(', '),
                        style: const TextStyle(color: _brandColor, fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildRecipeVisual(Recipe recipe) {
    final palette = _visualPalette(recipe.title);
    return Container(
      height: 142,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'AI GENERATED',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Icon(_visualIcon(recipe), color: Colors.white, size: 56),
          ),
          const Align(
            alignment: Alignment.topRight,
            child: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  List<Color> _visualPalette(String title) {
    const palettes = [
      [Color(0xFF0A4A33), Color(0xFF34A853)],
      [Color(0xFF9A4D16), Color(0xFFE28743)],
      [Color(0xFF335C8B), Color(0xFF6F9DD1)],
      [Color(0xFF7E4A75), Color(0xFFB574A8)],
      [Color(0xFF7C6239), Color(0xFFC6A15B)],
    ];
    return palettes[title.hashCode.abs() % palettes.length];
  }

  IconData _visualIcon(Recipe recipe) {
    final text = '${recipe.title} ${recipe.ingredients.join(' ')}'.toLowerCase();
    if (text.contains('soup') || text.contains('stew')) return Icons.soup_kitchen_rounded;
    if (text.contains('salad')) return Icons.eco_rounded;
    if (text.contains('cake') || text.contains('bake')) return Icons.bakery_dining_rounded;
    if (text.contains('pasta') || text.contains('noodle')) return Icons.ramen_dining_rounded;
    return Icons.restaurant_rounded;
  }

  bool _isSelectedIngredient(String ingredient) {
    final normalized = ingredient.toLowerCase().trim();
    return widget.selectedItems.any((item) {
      final name = item.name.toLowerCase().trim();
      return normalized == name || normalized.contains(name) || name.contains(normalized);
    });
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
