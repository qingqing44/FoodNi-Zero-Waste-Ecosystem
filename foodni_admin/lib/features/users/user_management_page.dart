import 'package:flutter/material.dart';
import '../../core/services/dashboard_service.dart';
import '../../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementView extends StatelessWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final DashboardService dashboardService = DashboardService();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E),
                ),
              ),
              const Spacer(),
              StreamBuilder<List<UserModel>>(
                stream: dashboardService.getUsersStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3EF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count users',
                      style: const TextStyle(
                        color: Color(0xFF052A1E),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: dashboardService.getUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading users'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];

                  if (users.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No users found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 64,
                          horizontalMargin: 24,
                          columnSpacing: 24,
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFE8F3EF),
                          ),
                          dividerThickness: 1,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'User',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Role',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Last Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Member Since',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E),
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Actions',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF052A1E),
                                ),
                              ),
                            ),
                          ],
                          rows: users.map((user) => _buildUserRow(context, user)).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildUserRow(BuildContext context, UserModel user) {
    final initials = _getInitials(user.displayName, user.email);
    final hasPhoto = user.photoURL.isNotEmpty;

    return DataRow(
      cells: [
        // User cell: avatar + name + email
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF052A1E),
                backgroundImage: hasPhoto ? NetworkImage(user.photoURL) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.displayName.isNotEmpty ? user.displayName : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF052A1E),
                    ),
                  ),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Role badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: user.role == 'admin'
                  ? const Color(0xFF052A1E)
                  : const Color(0xFFE8F3EF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                color: user.role == 'admin' ? Colors.white : const Color(0xFF052A1E),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Last Login
        DataCell(
          Text(
            _formatDate(user.lastLogin),
            style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
          ),
        ),
        // Member Since (createdAt)
        DataCell(
          Text(
            _formatDate(user.createdAt),
            style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Edit role',
                child: IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF052A1E)),
                  onPressed: () => _showEditDialog(context, user),
                  splashRadius: 20,
                ),
              ),
              Tooltip(
                message: 'Delete user',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, user),
                  splashRadius: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInitials(String displayName, String email) {
    if (displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName.trim()[0].toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _confirmDelete(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete User?'),
        content: Text(
          'Are you sure you want to delete ${user.displayName.isNotEmpty ? user.displayName : user.email}? '
          'This will remove their Firestore record.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await DashboardService().deleteUser(user.uid);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User deleted successfully')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserModel user) {
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF052A1E),
                backgroundImage: user.photoURL.isNotEmpty
                    ? NetworkImage(user.photoURL)
                    : null,
                child: user.photoURL.isEmpty
                    ? Text(
                        _getInitials(user.displayName, user.email),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : user.email,
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (user.displayName.isNotEmpty)
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Role',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: ['user', 'admin'].map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
                  onChanged: (val) => setState(() => selectedRole = val!),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF052A1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'role': selectedRole});
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
