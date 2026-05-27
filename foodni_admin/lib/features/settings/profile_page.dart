// lib/features/settings/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
          const SizedBox(height: 24),
          
          // Profile Details
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFE8F3EF),
                  child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF052A1E)),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.email ?? 'Loading Email...', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF052A1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('System Administrator', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(height: 8),
                    Text('UID: ${user?.uid ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Quick Settings Actions
          const Text('Account Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
          const SizedBox(height: 16),

          _buildSettingsTile(Icons.lock_outline, 'Change Password', 'Send a secure reset link to your email', () {
            if (user?.email != null) {
              _showPasswordResetDialog(context, user!.email!);
            }
          }),
          _buildSettingsTile(Icons.notifications_outlined, 'Notifications', 'Manage admin alerts', () {
            // Future Sprint: Notifications logic
          }),
          const SizedBox(height: 32),
          
          // Logout Button
          ElevatedButton.icon(
            onPressed: () => AuthService().logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out of Admin Panel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              minimumSize: const Size(200, 50),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFF9F8F4), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFF052A1E)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showPasswordResetDialog(BuildContext context, String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Reset Password', style: TextStyle(color: Color(0xFF052A1E), fontWeight: FontWeight.bold)),
              content: Text('Send a password reset link to $email? You will be signed out after changing it.'),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF052A1E),
                    minimumSize: const Size(100, 40),
                  ),
                  onPressed: isSending ? null : () async {
                    setState(() => isSending = true);
                    
                    final error = await AuthService().sendPasswordResetEmail(email);
                    
                    if (context.mounted) {
                      Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error ?? 'Password reset email sent! Check your inbox.'),
                          backgroundColor: error == null ? Colors.green : Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send Link'),
                ),
              ],
            );
          }
        );
      },
    );
  }

}