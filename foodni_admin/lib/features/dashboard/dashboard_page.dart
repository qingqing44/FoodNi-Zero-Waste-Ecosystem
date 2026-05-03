// lib/features/dashboard/dashboard_page.dart
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../settings/profile_page.dart'; 
import '../../core/services/dashboard_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0; 

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeStats();
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
          // SIDEBAR
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('FoodNi Workspace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
                ),
                _buildNavItem(Icons.dashboard, 'Dashboard', 0),
                _buildNavItem(Icons.people, 'Users', 1),
                _buildNavItem(Icons.fastfood, 'Food Items', 2),
                _buildNavItem(Icons.menu_book, 'Recipes', 3),
                const Spacer(),
                const Divider(),
                _buildNavItem(Icons.settings, 'Profile & Settings', 4), // Added Profile to Sidebar
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          Expanded(
            child: Column(
              children: [
                // TOPBAR
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedIndex = 4),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F3EF),
                          child: Icon(Icons.admin_panel_settings, color: Color(0xFF052A1E)),
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
                Expanded(
                  child: _buildBodyContent(),
                ),
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
        leading: Icon(icon, color: isActive ? const Color(0xFF052A1E) : Colors.grey),
        title: Text(
          title, 
          style: TextStyle(
            color: isActive ? const Color(0xFF052A1E) : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal
          )
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  final DashboardService _dashboardService = DashboardService();

  Widget _buildHomeStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
          const SizedBox(height: 24),
          Row(
            children: [
              // 1. LIVE DATA: Total Users wrapped in a FutureBuilder
              Expanded(
                child: FutureBuilder<int>(
                  future: _dashboardService.getTotalUsers(),
                  builder: (context, snapshot) {
                    // Show a loading indicator (...) while waiting for Firebase
                    String displayValue = '...'; 
                    
                    if (snapshot.connectionState == ConnectionState.done) {
                      if (snapshot.hasError) {
                        displayValue = 'Error';
                      } else {
                        // We got the real number!
                        displayValue = snapshot.data.toString();
                      }
                    }

                    return _buildStatCard('Total Users', displayValue, Icons.group, Colors.blue);
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(child: _buildStatCard('Food Items', 'xxx', Icons.inventory, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Total Recipes', 'xxx', Icons.receipt, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('AI Usage', 'xxx', Icons.auto_awesome, Colors.purple)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}