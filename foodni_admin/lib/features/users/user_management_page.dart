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
          const Text('User Management', 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
              ),
              child: StreamBuilder<List<UserModel>>(
                stream: dashboardService.getUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('Error loading users'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data ?? [];

                  return SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFE8F3EF)),
                      columns: const [
                        DataColumn(label: Text('UID', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: users.map((user) => DataRow(cells: [
                        DataCell(Text('${user.uid.substring(0, 8)}...')),
                        DataCell(Text(user.email)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.role == 'admin' ? const Color(0xFF052A1E) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(user.role, 
                              style: TextStyle(color: user.role == 'admin' ? Colors.white : Colors.black, fontSize: 12)),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF052A1E)),
                                onPressed: () {
                                  _showEditDialog(context, user); 
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  _confirmDelete(context, user);
                                },
                              ),
                            ],
                          ),
                        ),


                      ])).toList(),
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
    void _confirmDelete(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('Are you sure you want to delete ${user.email}? This user will lose all admin-granted access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          title: Text('Edit User: ${user.email}'),
          content: DropdownButton<String>(
            value: selectedRole,
            items: ['user', 'admin'].map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (val) => setState(() => selectedRole = val!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                // Update the role in Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'role': selectedRole});
                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}