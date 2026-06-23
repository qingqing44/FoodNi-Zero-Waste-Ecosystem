import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'authentication/profile_screen.dart';
import 'camera/camera_service.dart';
import 'camera/details_screen.dart';
import 'inventory/inventory_screen.dart';
import 'assistant/assistant_screen.dart';
import 'inventory/add_item_screen.dart';
import 'models/recipe.dart';
import 'models/food_item.dart';
import 'recipes/recipe_details_screen.dart';
import 'services/recipes/recipe_service.dart';
import 'notifications/expiry_notification_service.dart';
import 'social/upload_recipe_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Recipes';

  // ── Recipe recommendation state ──────────────────────────────────────────
  final _recipeService = RecipeService();
  List<Recipe>? _recommendedRecipes;
  bool _recipeLoading = false;
  String? _recipeError;

  // ── Profile avatar state ──────────────────────────────────────────────────
  String? _localAvatarUrl;

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedCategory != 'All Recipes';

  List<_Recipe> _filteredRecipes(List<_Recipe> uploadedRecipes) {
    final query = _searchQuery.trim().toLowerCase();

    return uploadedRecipes.where((recipe) {
      final matchesSearch =
          query.isEmpty ||
          recipe.title.toLowerCase().contains(query) ||
          recipe.description.toLowerCase().contains(query) ||
          recipe.authorName.toLowerCase().contains(query) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesCategory =
          _selectedCategory == 'All Recipes' ||
          recipe.category == _selectedCategory ||
          recipe.tags.contains(_selectedCategory);

      return matchesSearch && matchesCategory;
    }).toList();
  }

  static bool _isApprovedCommunityRecipe(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.trim().toLowerCase();
    return status == 'approved';
  }

  static int _compareRecipeDocsByCreatedAt(
    QueryDocumentSnapshot a,
    QueryDocumentSnapshot b,
  ) {
    final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
    if (aTs == null && bTs == null) return 0;
    if (aTs == null) return 1;
    if (bTs == null) return -1;
    return bTs.compareTo(aTs);
  }

  List<_Recipe> _uploadedRecipesFromSnapshot(QuerySnapshot? snapshot) {
    if (snapshot == null) return const [];

    final docs = snapshot.docs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          return _isApprovedCommunityRecipe(data);
        })
        .toList()
      ..sort(_compareRecipeDocsByCreatedAt);

    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final authorName = (data['authorName'] as String?)?.trim();
      final cookingTime = (data['cookingTime'] as String?)?.trim();
      final parsedTags = _parseStringList(data['tags']);

      return _Recipe(
        id: doc.id,
        image: (data['imageUrl'] as String?)?.trim() ?? '',
        imageBase64: data['imageBase64'] as String?,
        title: (data['title'] as String?)?.trim().isNotEmpty == true
            ? (data['title'] as String).trim()
            : 'Untitled Recipe',
        description: (data['description'] as String?)?.trim() ?? '',
        tags: parsedTags.isNotEmpty ? parsedTags : const ['Community'],
        category: (data['category'] as String?)?.trim() ?? 'All Recipes',
        ingredients: _parseStringList(data['ingredients']),
        steps: (data['steps'] as String?)?.trim() ?? '',
        authorName: authorName != null && authorName.isNotEmpty
            ? authorName
            : 'Anonymous',
        authorImage:
            'https://ui-avatars.com/api/?name=${Uri.encodeComponent(authorName ?? 'Anonymous')}&background=random',
        time: cookingTime != null && cookingTime.isNotEmpty
            ? cookingTime
            : 'Recipe',
        level: 'Uploaded',
      );
    }).toList();
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  void _openSocialRecipeDetails(_Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailsScreen(
          recipe: Recipe(
            id: recipe.id,
            title: recipe.title,
            imageUrl: recipe.image,
            imageBase64: recipe.imageBase64,
            ingredients: recipe.ingredients,
            instructions: _splitRecipeSteps(recipe.steps, recipe.description),
            preparationTime: _parseRecipeMinutes(recipe.time),
            difficulty: recipe.level,
            source: recipe.imageBase64 == null ? 'firebase' : 'community',
          ),
        ),
      ),
    );
  }

  static List<String> _splitRecipeSteps(String steps, String fallback) {
    final text = steps.trim().isNotEmpty ? steps.trim() : fallback.trim();
    if (text.isEmpty) return const [];

    return text
        .split(RegExp(r'\r?\n'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .map((step) => step.replaceFirst(RegExp(r'^\d+[\).\s-]*'), '').trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  static int _parseRecipeMinutes(String time) {
    final match = RegExp(r'\d+').firstMatch(time);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadLocalAvatar();
  }

  /// Load locally saved profile avatar from SharedPreferences.
  Future<void> _loadLocalAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final localPath = prefs.getString('local_avatar_path_$uid');
    if (localPath != null && File(localPath).existsSync()) {
      if (mounted) setState(() => _localAvatarUrl = localPath);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Recipe recommendation loading ─────────────────────────────────────────

  /// Fetches the current user's inventory from Firestore, extracts ingredient
  /// names, and passes them to [RecipeService] to get ranked recommendations.
  Future<void> _loadRecommendations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!mounted) return;
    setState(() {
      _recipeLoading = true;
      _recipeError = null;
    });

    try {
      // Fetch the user's food items from Firestore.
      final snapshot = await FirebaseFirestore.instance
          .collection('foodItems')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Extract and normalise ingredient names.
      final items = snapshot.docs
          .map((doc) => FoodItem.fromFirestore(doc.data(), doc.id))
          .toList();

      final recipes = await _recipeService.getRecommendedRecipes(items);

      if (mounted) {
        setState(() {
          _recommendedRecipes = recipes;
          _recipeLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recipeError = 'Could not load recommendations. Tap to retry.';
          _recipeLoading = false;
        });
      }
    }

    // After loading recommendations, fire off the daily check in the background.
    Future.microtask(
      () => ExpiryNotificationService.instance
          .checkAndSendDailyExpiryNotifications(),
    );
  }

  // ── Social feed filter methods ────────────────────────────────────────────

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _resetRecipeFilters() {
    setState(() {
      _selectedCategory = 'All Recipes';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showFilterSheet() {
    final categories = [
      'All Recipes',
      'Zero Waste',
      'Quick & Easy',
      'Pantry Staples',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E),
                ),
              ),
              const SizedBox(height: 12),
              ...categories.map(
                (category) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _selectedCategory == category
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: const Color(0xFF34A853),
                  ),
                  title: Text(category),
                  onTap: () {
                    Navigator.pop(context);
                    _selectCategory(category);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.refresh, color: Color(0xFF052A1E)),
                title: const Text('Reset search and filters'),
                onTap: () {
                  Navigator.pop(context);
                  _resetRecipeFilters();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search inspiration',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    _buildFilterRow(context),
                    const SizedBox(height: 16),
                    _buildCategoryChips(),
                    const SizedBox(height: 24),

                    // ── Use Soon ────────────────────────────────────────────
                    _buildRecommendedSection(),
                    const SizedBox(height: 24),

                    // ── Social Feed ─────────────────────────────────────────
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('recipes')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF34A853),
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'Community recipes could not be loaded. '
                              'Pull to refresh or try again later.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 13,
                              ),
                            ),
                          );
                        }

                        final uploadedRecipes = _uploadedRecipesFromSnapshot(
                          snapshot.data,
                        );
                        final recipes = _filteredRecipes(uploadedRecipes);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildRecipeFeed(
                            recipes,
                            approvedCount: uploadedRecipes.length,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Use Soon section ───────────────────────────────────────────

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Use Soon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF052A1E),
              ),
            ),
            // Retry / refresh button shown after loading completes or on error
            if (_recipeError != null || _recommendedRecipes != null)
              GestureDetector(
                onTap: () {
                  _recipeService.invalidateCache();
                  _loadRecommendations();
                },
                child: const Icon(
                  Icons.refresh,
                  color: Color(0xFF34A853),
                  size: 20,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Recipes to help you reduce food waste',
          style: TextStyle(color: Color(0xFF888888), fontSize: 12),
        ),
        const SizedBox(height: 14),

        // ── State handling ────────────────────────────────────────────────
        if (_recipeLoading)
          _buildRecommendedLoading()
        else if (_recipeError != null)
          _buildRecommendedError()
        else if (_recommendedRecipes == null || _recommendedRecipes!.isEmpty)
          _buildRecommendedEmpty()
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedRecipes!.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildRecommendedCard(
                  context,
                  _recommendedRecipes![index],
                );
              },
            ),
          ),
      ],
    );
  }

  /// A single horizontally-scrollable recipe recommendation card.
  Widget _buildRecommendedCard(BuildContext context, Recipe recipe) {
    final isFirebase = recipe.source == 'firebase';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(recipe: recipe),
          ),
        );
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image with badges ─────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: recipe.imageUrl.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl,
                          height: 110,
                          width: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _recipeImagePlaceholder(),
                        )
                      : _recipeImagePlaceholder(),
                ),
                // Match % badge (top-left)
                if (recipe.matchPercentage > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF052A1E).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${recipe.matchPercentage.toStringAsFixed(0)}% match',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Source badge (top-right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isFirebase
                          ? const Color(0xFF34A853).withValues(alpha: 0.9)
                          : Colors.grey.shade600.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isFirebase ? 'FoodNi' : 'External',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Card body ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF052A1E),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 11,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        recipe.preparationTime > 0
                            ? '${recipe.preparationTime} min'
                            : '–',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.bolt,
                        size: 11,
                        color: Color(0xFF888888),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          recipe.difficulty,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (recipe.expiringIngredientsUsed.isNotEmpty) ...[
                    const Text(
                      '🔥 Use Soon',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Uses: ${recipe.expiringIngredientsUsed.join(' • ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '✓ Pantry Friendly',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34A853),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shimmer-style loading placeholder row (4 ghost cards).
  Widget _buildRecommendedLoading() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Container(
                  height: 110,
                  width: 180,
                  color: Colors.grey.shade300,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 10,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF34A853),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown when the inventory is empty or no recipes matched.
  Widget _buildRecommendedEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.kitchen_outlined, size: 36, color: Color(0xFF34A853)),
          SizedBox(height: 8),
          Text(
            'No recommendations yet.',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF052A1E),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add items to your inventory to get personalised recipe ideas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF666666), fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Shown when the recommendation fetch failed. Tapping retries.
  Widget _buildRecommendedError() {
    return GestureDetector(
      onTap: () {
        _recipeService.invalidateCache();
        _loadRecommendations();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _recipeError ?? 'Something went wrong. Tap to retry.',
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generic image placeholder for recipe cards without an image URL.
  Widget _recipeImagePlaceholder() => Container(
    height: 110,
    width: 180,
    color: const Color(0xFFD0E8D8),
    child: const Icon(Icons.restaurant, color: Color(0xFF34A853), size: 36),
  );

  // ── Social feed ───────────────────────────────────────────────────────────

  List<Widget> _buildRecipeFeed(
    List<_Recipe> recipes, {
    required int approvedCount,
  }) {
    if (recipes.isEmpty) {
      final hasApprovedRecipes = approvedCount > 0;
      final message = hasApprovedRecipes && _hasActiveFilters
          ? 'No community recipes match your search or filters.'
          : hasApprovedRecipes
          ? 'No community recipes to show right now.'
          : 'No approved community recipes yet. Upload one and check back after review.';

      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 15,
                  ),
                ),
                if (hasApprovedRecipes && _hasActiveFilters) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _resetRecipeFilters,
                    child: const Text('Clear search and filters'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < recipes.length; i++) {
      if (!_hasActiveFilters && i == 3) {
        widgets.add(_buildSocialStatsCard());
        widgets.add(const SizedBox(height: 24));
      }

      if (!_hasActiveFilters && i == 3) {
        widgets.add(_buildZeroWasteCard());
        widgets.add(const SizedBox(height: 24));
      }

      final recipe = recipes[i];
      widgets.add(
        _buildRecipeCard(
          image: recipe.image,
          imageBase64: recipe.imageBase64,
          title: recipe.title,
          description: recipe.description,
          tags: recipe.tags,
          authorName: recipe.authorName,
          authorImage: recipe.authorImage,
          time: recipe.time,
          level: recipe.level,
          onTap: () => _openSocialRecipeDetails(recipe),
        ),
      );
      widgets.add(const SizedBox(height: 24));
    }

    return widgets;
  }

  /// Returns the correct [ImageProvider] for the user's avatar.
  /// Prefers a locally saved file; falls back to Firebase photoURL.
  ImageProvider? _buildAvatarImage() {
    if (_localAvatarUrl != null && File(_localAvatarUrl!).existsSync()) {
      return FileImage(File(_localAvatarUrl!));
    }
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return NetworkImage(photoUrl);
    }
    return null;
  }

  void _showNotificationsSheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.notifications, color: Color(0xFF052A1E)),
                  SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF052A1E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
                    .where('read', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF34A853)));
                  }
                  final docs = (snapshot.data?.docs ?? [])
                    ..sort((a, b) {
                      final aTs =
                          (a.data() as Map)['createdAt'] as Timestamp?;
                      final bTs =
                          (b.data() as Map)['createdAt'] as Timestamp?;
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
                          Icon(Icons.notifications_none,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No unread notifications',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final type = (data['type'] as String?) ?? '';
                      final title = (data['title'] as String?) ?? '';
                      final message = (data['message'] as String?) ?? '';
                      final createdAt =
                          data['createdAt'] as Timestamp?;
                      final isFlag = type == 'flag';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isFlag
                              ? Colors.orange.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            isFlag
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_active,
                            color:
                                isFlag ? Colors.orange : Colors.blue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF052A1E)),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666)),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _relativeTime(createdAt.toDate()),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          FirebaseFirestore.instance
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'read': true});
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildAppBar(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.menu, color: Color(0xFF052A1E)),
          const Text(
            'FoodNi',
            style: TextStyle(
              color: Color(0xFF052A1E),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              // Notification bell with live unread badge
              StreamBuilder<QuerySnapshot>(
                stream: uid == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('notifications')
                        .where('userId', isEqualTo: uid)
                        .where('read', isEqualTo: false)
                        .snapshots(),
                builder: (context, snapshot) {
                  final hasUnread =
                      (snapshot.data?.docs.isNotEmpty) ?? false;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: _showNotificationsSheet,
                        icon: const Icon(Icons.notifications_none,
                            color: Color(0xFF052A1E)),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(
                tooltip: 'Add Recipe',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UploadRecipeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.post_add, color: Color(0xFF052A1E)),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyProfileScreen(),
                  ),
                ).then((_) => _loadLocalAvatar()),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8F3EF),
                  backgroundImage: _buildAvatarImage(),
                  child: _buildAvatarImage() == null
                      ? const Icon(
                          Icons.person,
                          size: 20,
                          color: Color(0xFF052A1E),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: Colors.grey),
          hintText: 'Ingredients, dish types, or flavors...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E6C9).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune, color: Color(0xFF052A1E), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(
                      color: Color(0xFF052A1E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddItemScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF052A1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      'All Recipes',
      'Zero Waste',
      'Quick & Easy',
      'Pantry Staples',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (category) => GestureDetector(
                onTap: () => _selectCategory(category),
                child: _buildChip(category, _selectedCategory == category),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF052A1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : const Color(0xFFE0E0E0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF052A1E),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildRecipeCard({
    required String image,
    String? imageBase64,
    required String title,
    required String description,
    String? rating,
    required List<String> tags,
    required String authorName,
    required String authorImage,
    String time = '15 min',
    String level = 'Beginner',
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: _buildRecipeImage(
                    image: image,
                    imageBase64: imageBase64,
                  ),
                ),
                if (rating != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
                  Row(
                    children: tags
                        .map(
                          (tag) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F3EF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFF34A853),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF052A1E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(authorImage),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: Color(0xFF052A1E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF052A1E),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.bolt,
                        size: 16,
                        color: Color(0xFF052A1E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        level,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF052A1E),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.bookmark_outline,
                        size: 20,
                        color: Color(0xFF052A1E),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZeroWasteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF052A1E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.eco, color: Color(0xFF34A853), size: 28),
              Text(
                'Community Tip',
                style: TextStyle(
                  color: const Color(0xFF34A853).withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero-Waste Stocks',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save your vegetable scraps in the freezer for the ultimate homemade broth.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStatsCard() {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').count().get(),
      builder: (context, snapshot) {
        final count = snapshot.data?.count ?? 0;
        final label = count >= 1000
            ? '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}k'
            : '$count';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFC8E6C9).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.group, color: Color(0xFF052A1E)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          width: 32,
                          height: 24,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF052A1E),
                            ),
                          ),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF052A1E),
                          ),
                        ),
                  const Text(
                    'Active Home Cooks',
                    style: TextStyle(color: Color(0xFF052A1E), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecipeImage({required String image, String? imageBase64}) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageBase64),
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildRecipeImagePlaceholder(),
        );
      } catch (_) {
        return _buildRecipeImagePlaceholder();
      }
    }

    if (image.isNotEmpty) {
      return Image.network(
        image,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildRecipeImagePlaceholder(),
      );
    }

    return _buildRecipeImagePlaceholder();
  }

  Widget _buildRecipeImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFFE8F3EF),
      child: const Icon(Icons.restaurant, color: Color(0xFF34A853), size: 42),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            Icons.inventory_2_outlined,
            'INVENTORY',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InventoryScreen(),
                ),
              );
            },
          ),
          _buildNavItem(Icons.group_outlined, 'SOCIAL', true),
          _buildScanButton(context),
          _buildNavItem(
            Icons.auto_awesome_outlined,
            'ASSISTANT',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AssistantScreen(),
                ),
              );
            },
          ),
          _buildNavItem(
            Icons.person_outline,
            'PROFILE',
            false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _onScanTap(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF052A1E),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
      ),
    );
  }

  /// Shows a bottom sheet so the user can pick Camera or Gallery, then runs
  /// the scan workflow.
  Future<void> _onScanTap(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scan Food',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an image source',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F3EF),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF34A853),
                  ),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF1A73E8),
                  ),
                ),
                title: const Text('Gallery'),
                subtitle: const Text('Pick from your photos'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return; // User dismissed the sheet
    if (!context.mounted) return;

    // Show loading overlay while image is saved + analysed.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF34A853)),
              SizedBox(height: 20),
              Text(
                'Analyzing food freshness...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final foodData = await CameraService().scanFoodItem(source: source);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (foodData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoodDetailsScreen(foodData: foodData),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        final message = e is FoodScanException
            ? e.userMessage
            : const FoodScanException.unavailable().userMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF34A853) : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF34A853) : Colors.grey.shade400,
              fontSize: 9,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _Recipe {
  const _Recipe({
    this.id = '',
    required this.image,
    this.imageBase64,
    required this.title,
    required this.description,
    required this.tags,
    required this.category,
    this.ingredients = const [],
    this.steps = '',
    required this.authorName,
    required this.authorImage,
    this.time = '15 min',
    this.level = 'Beginner',
  });

  final String id;
  final String image;
  final String? imageBase64;
  final String title;
  final String description;
  final List<String> tags;
  final String category;
  final List<String> ingredients;
  final String steps;
  final String authorName;
  final String authorImage;
  final String time;
  final String level;
}
