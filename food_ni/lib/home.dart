import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'authentication/profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                    _buildFilterRow(),
                    const SizedBox(height: 16),
                    _buildCategoryChips(),
                    const SizedBox(height: 24),
                    
                    // Recipe Feed
                    _buildRecipeCard(
                      image: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&q=80&w=800',
                      title: 'Sustainable Harvest Buddha Bowl',
                      description: 'Transform leftover grains and wilting greens into a powerhouse nutritional meal with this signature dressing.',
                      rating: '4.9(124)',
                      tags: ['Zero Waste', 'High Fiber'],
                      authorName: 'Marcus C.',
                      authorImage: 'https://i.pravatar.cc/150?u=marcus',
                      time: '20 min',
                      level: 'Beginner',
                    ),
                    const SizedBox(height: 24),
                    _buildRecipeCard(
                      image: 'https://images.unsplash.com/photo-1473093226795-af9932fe5856?auto=format&fit=crop&q=80&w=800',
                      title: '10-Min Pantry Pasta',
                      description: 'The ultimate lazy Sunday meal using only shelf-stable ingredients from your FoodNi inventory.',
                      tags: ['Quick & Easy'],
                      authorName: 'Maya R.',
                      authorImage: 'https://i.pravatar.cc/150?u=maya',
                    ),
                    const SizedBox(height: 24),
                    _buildRecipeCard(
                      image: 'https://images.unsplash.com/photo-1541920443742-6fe179cd5092?auto=format&fit=crop&q=80&w=800',
                      title: 'Dark Choco Lava Cake',
                      description: 'A sustainable twist using fair-trade cocoa and seasonal berry compote.',
                      tags: ['Indulgent'],
                      authorName: 'Alex K.',
                      authorImage: 'https://i.pravatar.cc/150?u=alex',
                    ),
                    const SizedBox(height: 24),

                    // Zero Waste Stock Card
                    _buildZeroWasteCard(),
                    const SizedBox(height: 24),

                    // Active Cooks Card
                    _buildSocialStatsCard(),
                    const SizedBox(height: 24),

                    _buildRecipeCard(
                      image: 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?auto=format&fit=crop&q=80&w=800',
                      title: 'Pantry Mezze Board',
                      description: 'Elevate canned chickpeas and olives into an artisan appetizer spread.',
                      tags: ['Party Hit'],
                      authorName: 'Lela J.',
                      authorImage: 'https://i.pravatar.cc/150?u=lela',
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyProfileScreen())),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE8F3EF),
              backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser?.photoURL ?? 'https://i.pravatar.cc/150?u=me'),
            ),
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
      child: const TextField(
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: 'Ingredients, dish types, or flavors...',
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E6C9).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tune, color: Color(0xFF052A1E), size: 18),
                SizedBox(width: 8),
                Text('Filters', style: TextStyle(color: Color(0xFF052A1E), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF052A1E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip('All Recipes', true),
          _buildChip('Zero Waste', false),
          _buildChip('Quick & Easy', false),
          _buildChip('Pantry Staples', false),
        ],
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
        border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE0E0E0)),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(image, height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              if (rating != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 14),
                        const SizedBox(width: 4),
                        Text(rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
                  children: tags.map((tag) => Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFE8F3EF), borderRadius: BorderRadius.circular(8)),
                    child: Text(tag, style: const TextStyle(color: Color(0xFF34A853), fontSize: 10, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
                          const SizedBox(height: 8),
                          Text(description, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        CircleAvatar(radius: 18, backgroundImage: NetworkImage(authorImage)),
                        const SizedBox(height: 4),
                        Text(authorName, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Color(0xFF052A1E)),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF052A1E))),
                    const SizedBox(width: 16),
                    const Icon(Icons.bolt, size: 16, color: Color(0xFF052A1E)),
                    const SizedBox(width: 4),
                    Text(level, style: const TextStyle(fontSize: 12, color: Color(0xFF052A1E))),
                    const Spacer(),
                    const Icon(Icons.bookmark_outline, size: 20, color: Color(0xFF052A1E)),
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
              Text('Community Tip', style: TextStyle(color: const Color(0xFF34A853).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Zero-Waste Stocks', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Save your vegetable scraps in the freezer for the ultimate homemade broth.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC8E6C9).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.group, color: Color(0xFF052A1E)),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('2.4k', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
              Text('Active Home Cooks', style: TextStyle(color: Color(0xFF052A1E), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.inventory_2_outlined, 'INVENTORY', false),
          _buildNavItem(Icons.auto_awesome_outlined, 'ASSISTANT', false),
          _buildScanButton(),
          _buildNavItem(Icons.group_outlined, 'SOCIAL', true),
          _buildNavItem(Icons.person_outline, 'PROFILE', false, onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MyProfileScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: Color(0xFF052A1E), shape: BoxShape.circle),
      child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF34A853) : Colors.grey.shade400, size: 24),
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