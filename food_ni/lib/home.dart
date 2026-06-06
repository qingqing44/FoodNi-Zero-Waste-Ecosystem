import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'authentication/profile_screen.dart';
import 'camera/camera_service.dart';
import 'camera/details_screen.dart';
import 'inventory/inventory_screen.dart';
import 'assistant/assistant_screen.dart';
import 'inventory/add_item_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All Recipes';

  static const List<_Recipe> _recipes = [
    _Recipe(
      image:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=800',
      title: 'Sustainable Harvest Buddha Bowl',
      description:
          'Transform leftover grains and wilting greens into a powerhouse nutritional meal with this signature dressing.',
      rating: '4.9(124)',
      tags: ['Zero Waste', 'High Fiber'],
      category: 'Zero Waste',
      authorName: 'Marcus C.',
      authorImage:
          'https://ui-avatars.com/api/?name=Marcus+C&background=random',
      time: '20 min',
      level: 'Beginner',
    ),
    _Recipe(
      image:
          'https://images.unsplash.com/photo-1473093226795-af9932fe5856?auto=format&fit=crop&q=80&w=800',
      title: '10-Min Pantry Pasta',
      description:
          'The ultimate lazy Sunday meal using only shelf-stable ingredients from your FoodNi inventory.',
      tags: ['Quick & Easy'],
      category: 'Quick & Easy',
      authorName: 'Maya R.',
      authorImage: 'https://ui-avatars.com/api/?name=Maya+R&background=random',
    ),
    _Recipe(
      image:
          'https://images.unsplash.com/photo-1606890737304-57a1ca8a5b62?auto=format&fit=crop&q=80&w=800',
      title: 'Dark Choco Lava Cake',
      description:
          'A sustainable twist using fair-trade cocoa and seasonal berry compote.',
      tags: ['Indulgent'],
      category: 'All Recipes',
      authorName: 'Alex K.',
      authorImage: 'https://ui-avatars.com/api/?name=Alex+K&background=random',
    ),
    _Recipe(
      image:
          'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&q=80&w=800',
      title: 'Pantry Mezze Board',
      description:
          'Elevate canned chickpeas and olives into an artisan appetizer spread.',
      tags: ['Party Hit'],
      category: 'Pantry Staples',
      authorName: 'Lela J.',
      authorImage: 'https://ui-avatars.com/api/?name=Lela+J&background=random',
    ),
  ];

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty || _selectedCategory != 'All Recipes';

  List<_Recipe> get _filteredRecipes {
    final query = _searchQuery.trim().toLowerCase();

    return _recipes.where((recipe) {
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final recipes = _filteredRecipes;

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

                    ..._buildRecipeFeed(recipes),
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

  List<Widget> _buildRecipeFeed(List<_Recipe> recipes) {
    if (recipes.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No recipes found',
              style: TextStyle(color: Color(0xFF666666), fontSize: 15),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (var i = 0; i < recipes.length; i++) {
      if (!_hasActiveFilters && i == 3) {
        widgets.add(_buildZeroWasteCard());
        widgets.add(const SizedBox(height: 24));
        widgets.add(_buildSocialStatsCard());
        widgets.add(const SizedBox(height: 24));
      }

      final recipe = recipes[i];
      widgets.add(
        _buildRecipeCard(
          image: recipe.image,
          title: recipe.title,
          description: recipe.description,
          rating: recipe.rating,
          tags: recipe.tags,
          authorName: recipe.authorName,
          authorImage: recipe.authorImage,
          time: recipe.time,
          level: recipe.level,
        ),
      );
      widgets.add(const SizedBox(height: 24));
    }

    return widgets;
  }

  Widget _buildAppBar(BuildContext context) {
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
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyProfileScreen()),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE8F3EF),
              backgroundImage: NetworkImage(
                FirebaseAuth.instance.currentUser?.photoURL ??
                    'https://ui-avatars.com/api/?name=User&background=random',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        hintText: 'Ingredients, dish types, or flavors...',
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
    required String title,
    required String description,
    String? rating,
    required List<String> tags,
    required String authorName,
    required String authorImage,
    String time = '15 min',
    String level = 'Beginner',
  }) {
    return Container(
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
                child: Image.network(
                  image,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                        const Icon(Icons.star, color: Colors.orange, size: 14),
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
                    const Icon(Icons.bolt, size: 16, color: Color(0xFF052A1E)),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2.4k',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E),
                ),
              ),
              Text(
                'Active Home Cooks',
                style: TextStyle(color: Color(0xFF052A1E), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
    required this.image,
    required this.title,
    required this.description,
    required this.tags,
    required this.category,
    required this.authorName,
    required this.authorImage,
    this.rating,
    this.time = '15 min',
    this.level = 'Beginner',
  });

  final String image;
  final String title;
  final String description;
  final List<String> tags;
  final String category;
  final String authorName;
  final String authorImage;
  final String? rating;
  final String time;
  final String level;
}
