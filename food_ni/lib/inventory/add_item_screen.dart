import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../camera/local_image_service.dart';
import '../notifications/expiry_notification_service.dart';
import 'food_status_utils.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  String _selectedUnit = 'Unit';
  DateTime? _purchaseDate;
  DateTime? _selectedDate;
  DateTime? _suggestedDate;
  bool _isExpiryDateOverridden = false;
  bool _isLoading = false;
  XFile? _selectedImage;

  final List<String> _categories = [
    'Produce',
    'Main Course',
    'Prepared Meal',
    'Meat & Seafood',
    'Dessert/Pastry',
    'Frozen',
    'Packaged Beverages',
    'Fruit',
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

  @override
  void initState() {
    super.initState();
    _purchaseDate = FoodStatusUtils.malaysiaTodayDateOnly();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
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

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final today = FoodStatusUtils.malaysiaTodayDateOnly();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? today,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
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
        _purchaseDate = picked;
        _syncSuggestedExpiry();
      });
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a category first to calculate the expiry date'),
        ),
      );
      return;
    }

    final today = FoodStatusUtils.malaysiaTodayDateOnly();
    final DateTime initialDate = _selectedDate ?? _suggestedDate ?? today;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year - 1, today.month, today.day),
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
        _isExpiryDateOverridden = !FoodStatusUtils.isSameDate(
          picked,
          _suggestedDate,
        );
      });
    }
  }

  void _syncSuggestedExpiry({bool resetOverride = false}) {
    final suggestedDate = FoodStatusUtils.suggestedExpiryDate(
      category: _selectedCategory,
      purchaseDate: _purchaseDate,
    );

    _suggestedDate = suggestedDate;

    if (suggestedDate == null) {
      if (resetOverride || !_isExpiryDateOverridden) {
        _selectedDate = null;
        _isExpiryDateOverridden = false;
      }
      return;
    }

    if (resetOverride || !_isExpiryDateOverridden || _selectedDate == null) {
      _selectedDate = suggestedDate;
      _isExpiryDateOverridden = false;
    }
  }

  void _applySuggestedExpiry() {
    if (_suggestedDate == null) return;

    setState(() {
      _selectedDate = _suggestedDate;
      _isExpiryDateOverridden = false;
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_purchaseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a purchase date')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category to calculate the expiry date'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      String? thumbnailPath;
      String? localImagePath;

      if (_selectedImage != null) {
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          thumbnailPath = await LocalImageService().createWebThumbnailDataUrl(
            bytes,
          );
        } else {
          final savedImage = await LocalImageService().saveImage(File(_selectedImage!.path));
          localImagePath = savedImage.imagePath;
          thumbnailPath = savedImage.thumbnailPath;
        }
      }

      final formattedDate = FoodStatusUtils.formatExpiryDate(_selectedDate!);
      final purchaseDate = FoodStatusUtils.formatExpiryDate(_purchaseDate!);
      final suggestedExpiryDate = _suggestedDate == null
          ? null
          : FoodStatusUtils.formatExpiryDate(_suggestedDate!);
      final daysRemaining = FoodStatusUtils.daysRemaining(_selectedDate!);
      final freshnessStatus = FoodStatusUtils.statusForDays(daysRemaining);
      final quantityDisplay =
          '${_quantityController.text.trim()} ${_selectedUnit == 'Unit' ? 'pcs' : _selectedUnit}';

      final docRef = FirebaseFirestore.instance.collection('foodItems').doc();
      await docRef.set({
        'userId': user.uid,
        'foodName': _nameController.text.trim(),
        'purchaseDate': purchaseDate,
        'expiryDate': formattedDate,
        'suggestedExpiryDate': suggestedExpiryDate,
        'isExpiryDateOverridden': _isExpiryDateOverridden,
        'category': _selectedCategory ?? 'Uncategorized',
        'quantity': quantityDisplay,
        'storageSuggestion': 'See Storage Guide for details.',
        'thumbnailPath': thumbnailPath,
        'localImagePath': localImagePath,
        'freshnessStatus': freshnessStatus,
        'freshnessScore': FoodStatusUtils.freshnessScoreForStatus(
          freshnessStatus,
        ),
        'estimatedDaysRemaining': daysRemaining,
        'scanDate': FieldValue.serverTimestamp(),
        'source': 'manual',
      });

      if (daysRemaining >= 0) {
        await ExpiryNotificationService.instance.scheduleExpiryReminder(
          itemId: docRef.id,
          foodName: _nameController.text.trim(),
          expiryDate: _selectedDate!,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF052A1E)),
        title: const Text(
          'Add Manual Item',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
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
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImage!.path,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(_selectedImage!.path),
                                          fit: BoxFit.cover,
                                        ),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 32,
                                      color: Color(0xFF34A853),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add Photo',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
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
                      onChanged: (val) => setState(() {
                        _selectedCategory = val;
                        _syncSuggestedExpiry();
                      }),
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
                      onTap: () => _selectPurchaseDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: TextEditingController(
                            text: _purchaseDate == null
                                ? ''
                                : FoodStatusUtils.formatExpiryDate(
                                    _purchaseDate!,
                                  ),
                          ),
                          label: 'Purchase Date',
                          icon: Icons.shopping_bag_outlined,
                          hint: 'Select Date',
                          validator: (value) {
                            if (_purchaseDate == null) {
                              return 'Please select a purchase date';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _selectExpiryDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: TextEditingController(
                            text: _selectedDate == null
                                ? ''
                                : FoodStatusUtils.formatExpiryDate(
                                    _selectedDate!,
                                  ),
                          ),
                          label: 'Expiry Date',
                          icon: Icons.calendar_today,
                          hint: 'Calculated automatically',
                          validator: (value) {
                            if (_selectedDate == null) {
                              return 'Select a category to calculate expiry';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildExpiryMessage(),
                    const SizedBox(height: 32),
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
                        'Save Item',
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

  Widget _buildExpiryMessage() {
    final textTheme = Theme.of(context).textTheme;
    final suggestedDateText = _suggestedDate == null
        ? null
        : FoodStatusUtils.formatExpiryDate(_suggestedDate!);

    if (_selectedCategory == null) {
      return Text(
        'Select a category to auto-calculate the expiry date.',
        style: textTheme.bodySmall?.copyWith(color: const Color(0xFF666666)),
      );
    }

    if (_isExpiryDateOverridden && suggestedDateText != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Suggested expiry is $suggestedDateText. You changed it manually.',
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666666),
              ),
            ),
          ),
          TextButton(
            onPressed: _applySuggestedExpiry,
            child: const Text('Use Suggested'),
          ),
        ],
      );
    }

    if (suggestedDateText != null) {
      return Text(
        'Expiry is auto-calculated from the selected category and purchase date. You can change it if needed.',
        style: textTheme.bodySmall?.copyWith(color: const Color(0xFF666666)),
      );
    }

    return const SizedBox.shrink();
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
