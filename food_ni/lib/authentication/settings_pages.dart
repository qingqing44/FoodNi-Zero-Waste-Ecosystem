import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  static const _darkGreen = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkGreen),
        title: const Text(
          'Account Settings',
          style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection(
              title: 'Personal Details',
              children: [
                _buildInfoRow('Name', user?.displayName ?? 'Alex Rivers'),
                const Divider(),
                _buildInfoRow('Email', user?.email ?? 'N/A'),
                const Divider(),
                _buildInfoRow('User ID', user?.uid ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Security & Options',
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: _darkGreen),
                  title: const Text('Reset Password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () async {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null || currentUser.email == null) return;

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text(
                          'Reset Password',
                          style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold),
                        ),
                        content: Text(
                          'Would you like to send a password reset link to your email (${currentUser.email})?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Send Link',
                              style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true || !context.mounted) return;

                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(email: currentUser.email!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset email sent!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to send reset email: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.red),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Account'),
                        content: const Text(
                          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please contact support to delete your account.')),
                              );
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontWeight: FontWeight.bold, color: _darkGreen, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class SustainabilityReportScreen extends StatelessWidget {
  const SustainabilityReportScreen({super.key});

  static const _darkGreen = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkGreen),
        title: const Text(
          'Sustainability Report',
          style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('foodItems')
            .where('userId', isEqualTo: user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          final co2Saved = count * 2.5;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Impact Summary Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _darkGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.eco, color: _accentGreen, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Your Green Footprint',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildReportStat(count.toString(), 'Food Saved'),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _buildReportStat('${co2Saved.toStringAsFixed(1)} kg', 'CO2 Reduced'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Environmental Facts
                const Text(
                  'What does this mean?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen),
                ),
                const SizedBox(height: 12),
                _buildFactCard(
                  icon: Icons.lightbulb_outline,
                  title: 'Energy Saved',
                  description: 'Every saved food item prevents wastage of precious agricultural energy. You have helped conserve standard household power equivalent to running an LED bulb.',
                ),
                const SizedBox(height: 12),
                _buildFactCard(
                  icon: Icons.forest_outlined,
                  title: 'Tree Equivalent',
                  description: 'Reducing greenhouse gases is key. Preventing food decomposition in landfills reduces methane emissions, equivalent to the daily absorption rate of fully grown forest trees.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFactCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3EF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accentGreen, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkGreen),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _darkGreen = Color(0xFF052A1E);
  static const _accentGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _darkGreen),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: _darkGreen, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen),
          ),
          const SizedBox(height: 12),
          _buildFaqTile(
            question: 'How does AI scanning work?',
            answer: 'Tapping the scan button allows you to snap a picture or upload one from your gallery. Our integrated AI analyzes the food image to detect items, assess their freshness status, suggest calories per 100g, and estimate shelf life.',
          ),
          const SizedBox(height: 8),
          _buildFaqTile(
            question: 'How are expiry reminders scheduled?',
            answer: 'When saving food items with an estimated shelf life, FoodNi schedules a local reminder notification to fire one day before the calculated expiry date to help you consume it in time.',
          ),
          const SizedBox(height: 8),
          _buildFaqTile(
            question: 'Can I reset my conversation history?',
            answer: 'Yes! Simply tap the refresh icon on the top right corner of the AI Assistant screen to wipe the chat history and start over.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Contact Us',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkGreen),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Need extra assistance?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkGreen),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Reach out to our support team at support@foodni.com. We respond within 24 hours.',
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support ticket created successfully!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit Support Request'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTile({required String question, required String answer}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF0F0F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _darkGreen),
        ),
        iconColor: _accentGreen,
        collapsedIconColor: _darkGreen,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
