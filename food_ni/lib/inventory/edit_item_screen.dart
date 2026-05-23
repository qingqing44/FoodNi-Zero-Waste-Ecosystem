import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../camera/local_image_service.dart';

class EditItemScreen extends StatefulWidget {
  final QueryDocumentSnapshot item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _storageController = TextEditingController();
  final _picker = ImagePicker();
  final _localImageService = LocalImageService();

  final List<String> _categories = [
    'Produce',
    'Main Course',
    'Prepared Meal',
    'Meat & Seafood',
    'Dessert/Pastry',
    'Frozen',
    'Packaged Beverages',
    'Fruit',
    'Uncategorized',
  ];
  final List<String> _units = [
    'Unit',
    'kg',
    'g',
    'lbs',
    'L',
    'ml',
    'oz',
    'Pack',
  ];

  String? _selectedCategory;
  String _selectedUnit = 'Unit';
  DateTime? _selectedDate;
  XFile? _selectedImage;
  String? _localImagePath;
  String? _thumbnailPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.item.data() as Map<String, dynamic>;
    _nameController.text = data['foodName'] as String? ?? '';
    _selectedCategory = data['category'] as String? ?? 'Uncategorized';
    _storageController.text = data['storageSuggestion'] as String? ?? '';
    _localImagePath = data['localImagePath'] as String?;
    _thumbnailPath = data['thumbnailPath'] as String?;
    _selectedDate = _parseExpiryDate(data['expiryDate'] as String?);
    _populateQuantity(data['quantity'] as String?);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _storageController.dispose();
    super.dispose();
  }

  DateTime? _parseExpiryDate(String? value) {
    if (value == null || value.isEmpty || value == 'N/A') return null;
    try {
      return DateFormat('MMM dd, yyyy').parse(value);
    } catch (_) {
      return null;
    }
  }

  void _populateQuantity(String? value) {
    final quantity = (value == null || value.trim().isEmpty)
        ? '1 pcs'
        : value.trim();
    final parts = quantity.split(RegExp(r'\s+'));
    if (parts.length <= 1) {
      _quantityController.text = quantity;
      return;
    }

    final rawUnit = parts.last;
    _quantityController.text = parts.sublist(0, parts.length - 1).join(' ');
    _selectedUnit = rawUnit.toLowerCase() == 'pcs' ? 'Unit' : rawUnit;
    if (!_units.contains(_selectedUnit)) {
      _units.add(_selectedUnit);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF052A1E),
              onPrimary: Colors.white,
              onSurface: Color(0xFF052A1E),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF34A853),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  int _daysRemaining(DateTime expiryDate) {
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanExpiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    return cleanExpiry.difference(cleanToday).inDays;
  }

  String _freshnessStatusFor(int daysRemaining) {
    if (daysRemaining <= 0) return 'Spoiled';
    if (daysRemaining <= 3) return 'Good';
    return 'Fresh';
  }

  int _freshnessScoreFor(int daysRemaining) {
    if (daysRemaining <= 0) return 0;
    if (daysRemaining <= 3) return 75;
    return 100;
  }

  Future<void> _deleteOldImageIfSafe(String? oldPath, String? newPath) async {
    if (oldPath == null || oldPath.isEmpty || oldPath == newPath) return;

    try {
      final file = File(oldPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Editing succeeded; stale local file cleanup is best effort only.
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final oldLocalImagePath = _localImagePath;
    final oldThumbnailPath = _thumbnailPath;

    try {
      String? nextLocalImagePath = _localImagePath;
      String? nextThumbnailPath = _thumbnailPath;

      if (_selectedImage != null) {
        final savedImage = await _localImageService.saveImage(
          File(_selectedImage!.path),
        );
        nextLocalImagePath = savedImage.imagePath;
        nextThumbnailPath = savedImage.thumbnailPath;
      }

      final formattedDate = DateFormat('MMM dd, yyyy').format(_selectedDate!);
      final daysRemaining = _daysRemaining(_selectedDate!);
      final selectedUnit = _selectedUnit == 'Unit' ? 'pcs' : _selectedUnit;
      final quantityDisplay =
          '${_quantityController.text.trim()} $selectedUnit';

      await widget.item.reference.update({
        'foodName': _nameController.text.trim(),
        'category': _selectedCategory ?? 'Uncategorized',
        'quantity': quantityDisplay,
        'expiryDate': formattedDate,
        'storageSuggestion': _storageController.text.trim().isNotEmpty
            ? _storageController.text.trim()
            : 'No storage suggestion provided.',
        'estimatedDaysRemaining': daysRemaining,
        'freshnessStatus': _freshnessStatusFor(daysRemaining),
        'freshnessScore': _freshnessScoreFor(daysRemaining),
        'localImagePath': nextLocalImagePath,
        'thumbnailPath': nextThumbnailPath,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (_selectedImage != null) {
        await _deleteOldImageIfSafe(oldLocalImagePath, nextLocalImagePath);
        await _deleteOldImageIfSafe(oldThumbnailPath, nextThumbnailPath);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating item: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      _categories.add(_selectedCategory!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF052A1E)),
        title: const Text(
          'Edit Item',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isSaving
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF052A1E)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF0F0F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildPhotoPreview(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Food Name',
                      icon: Icons.fastfood,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a food name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildDropdownField(
                      label: 'Category',
                      icon: Icons.category,
                      value: _selectedCategory,
                      hint: 'Select Category',
                      items: _categories,
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      validator: (value) =>
                          value == null ? 'Please select a category' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _quantityController,
                            label: 'Quantity',
                            icon: Icons.scale,
                            hint: '1',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 2,
                          child: _buildDropdownField(
                            label: 'Unit',
                            icon: Icons.unfold_more,
                            value: _selectedUnit,
                            hint: 'Unit',
                            items: _units,
                            onChanged: (val) =>
                                setState(() => _selectedUnit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: TextEditingController(
                            text: _selectedDate == null
                                ? ''
                                : DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_selectedDate!),
                          ),
                          label: 'Expiry Date',
                          icon: Icons.calendar_today,
                          hint: 'Select Date',
                          validator: (value) {
                            if (_selectedDate == null) {
                              return 'Please select an expiry date';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _storageController,
                      label: 'Storage Suggestion (Optional)',
                      icon: Icons.kitchen,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _saveItem,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF052A1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhotoPreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
      );
    }

    final existingPath = _thumbnailPath ?? _localImagePath;
    if (existingPath != null && File(existingPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(File(existingPath), fit: BoxFit.cover),
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 32, color: Color(0xFF34A853)),
        SizedBox(height: 8),
        Text(
          'Edit Photo',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        prefixIcon: Icon(icon, color: const Color(0xFF34A853)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF052A1E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(
        hint,
        style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
      ),
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF666666)),
        prefixIcon: Icon(icon, color: const Color(0xFF34A853)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF0F0F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF052A1E), width: 2),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
    );
  }
}
