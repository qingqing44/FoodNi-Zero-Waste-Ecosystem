import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _isEditing = false;
  
  // Real state
  String? _currentAvatarUrl;
  
  // Temporary state for editing
  String? _tempAvatarUrl;
  File? _tempImageFile;
  
  final ImagePicker _picker = ImagePicker();

    bool _dietaryRestrictions = true;
  bool _notifications = true;
  bool _ecoMode = false;

  final List<String> _fixedIcons = [
    'https://cdn-icons-png.flaticon.com/512/4140/4140048.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140047.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140051.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140061.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140043.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140045.png',
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? '';
    _currentAvatarUrl = user?.photoURL;
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _nameController.text = user?.displayName ?? '';
      _tempAvatarUrl = _currentAvatarUrl;
      _tempImageFile = null;
    });
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _tempImageFile = File(pickedFile.path);
        _tempAvatarUrl = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String? finalPhotoUrl = _tempAvatarUrl;

      // Upload Image to Firebase Storage if new one was picked
      if (_tempImageFile != null && !kIsWeb) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos')
            .child('${user!.uid}.jpg');
        
        await storageRef.putFile(_tempImageFile!);
        finalPhotoUrl = await storageRef.getDownloadURL();
      }

      // Update Firebase Auth Profile
      if (_nameController.text.trim() != user?.displayName) {
        await user?.updateDisplayName(_nameController.text.trim());
      }
      
      if (finalPhotoUrl != _currentAvatarUrl) {
        await user?.updatePhotoURL(finalPhotoUrl);
        _currentAvatarUrl = finalPhotoUrl;
      }

      await user?.reload();
      if (mounted) {
        setState(() {
          _isEditing = false;
          _tempImageFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _isEditing ? _buildEditMode() : _buildViewMode(),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
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
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE8F3EF),
            backgroundImage: _getProfileImage(),
            child: _getProfileImage() == null
                ? const Icon(Icons.person, size: 20, color: Color(0xFF052A1E))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      children: [
        // Profile Header
        Center(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFE8F3EF),
                      backgroundImage: _getProfileImage(),
                      child: _getProfileImage() == null
                          ? const Icon(Icons.person, size: 60, color: Color(0xFF052A1E))
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF34A853),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'Alex Rivers',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF052A1E),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3EF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'KitchenHero',
                  style: TextStyle(
                    color: Color(0xFF34A853),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sustainable cooking enthusiast since 2023',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _startEditing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF052A1E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Share Journey', style: TextStyle(color: Color(0xFF052A1E))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Stats Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard(Icons.inventory_2, '428', 'Total Items Saved', const Color(0xFFE8F3EF), const Color(0xFF052A1E)),
              const SizedBox(width: 12),
              _buildStatCard(Icons.cloud_done, '12.4 kg', 'CO2 Reduced', const Color(0xFF052A1E), Colors.white),
              const SizedBox(width: 12),
              _buildStatCard(Icons.delete_sweep, '85%', 'Waste Prevented', const Color(0xFFF9F3EB), const Color(0xFF8B4513)),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Your Household
        _buildSectionHeader('Your Household'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _buildUserAvatarStack(),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF34A853)),
                    label: const Text('Invite', style: TextStyle(color: Color(0xFF34A853), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F8F4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Household Sharing: Currently sharing Inventory & Shopping Lists with "Rivers Residence".',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666), height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // My Preferences
        _buildSectionHeader('My Preferences'),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              _buildPreferenceTile(Icons.restaurant, 'Dietary Restrictions', _dietaryRestrictions, (v) => setState(() => _dietaryRestrictions = v)),
              const Divider(height: 1),
              _buildPreferenceTile(Icons.notifications, 'Notifications', _notifications, (v) => setState(() => _notifications = v)),
              const Divider(height: 1),
              _buildPreferenceTile(Icons.eco, 'Eco Mode Tips', _ecoMode, (v) => setState(() => _ecoMode = v)),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Menu Items
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            children: [
              _buildMenuItem(Icons.manage_accounts, 'Account Settings', 'Privacy, Security, and Personal details'),
              const Divider(height: 1),
              _buildMenuItem(Icons.assessment, 'Sustainability Report', 'Detailed breakdown of your kitchen\'s impact'),
              const Divider(height: 1),
              _buildMenuItem(Icons.help, 'Help & Support', 'FAQs, Tutorials, and Contact us'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Sign Out
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) Navigator.of(context).pop();
          },
          child: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFFE8F3EF),
                  backgroundImage: _getProfileImage(),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFF052A1E), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: _inputDecoration('Alex Rivers'),
        ),
        const SizedBox(height: 32),
        const Text('Choose a Profile Icon', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF052A1E))),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _fixedIcons.length,
          itemBuilder: (context, index) {
            final url = _fixedIcons[index];
            final isSelected = _currentAvatarUrl == url;
            return GestureDetector(
              onTap: () => setState(() { _tempAvatarUrl = url; _tempImageFile = null; }),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: (isSelected || _tempAvatarUrl == url) ? const Color(0xFF052A1E) : Colors.transparent, width: 3),
                ),
                child: CircleAvatar(backgroundImage: NetworkImage(url), backgroundColor: Colors.white),
              ),
            );
          },
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF052A1E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ImageProvider? _getProfileImage() {
    if (_isEditing) {
      if (_tempImageFile != null) return FileImage(_tempImageFile!);
      if (_tempAvatarUrl != null) return NetworkImage(_tempAvatarUrl!);
    } else {
      if (_currentAvatarUrl != null) return NetworkImage(_currentAvatarUrl!);
    }
    return null;
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color bgColor, Color textColor) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF052A1E)),
      ),
    );
  }

  Widget _buildUserAvatarStack() {
    return Row(
      children: [
        for (int i = 0; i < 3; i++)
          Align(
            widthFactor: 0.7,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 12,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=${i + 10}'),
              ),
            ),
          ),
        Align(
          widthFactor: 0.7,
          child: CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE8F3EF),
            child: const Text('+2', style: TextStyle(fontSize: 10, color: Color(0xFF34A853), fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 16),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF34A853),
            activeTrackColor: const Color(0xFFE8F3EF),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.grey.shade700, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
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
          _buildNavItem(Icons.group_outlined, 'SOCIAL', false, onTap: () {
            Navigator.of(context).pop(); // Go back to Home/Social
          }),
          _buildNavItem(Icons.person, 'PROFILE', true),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE8F3EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF052A1E), width: 1.5),
      ),
    );
  }
}
