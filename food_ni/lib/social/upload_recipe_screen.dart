import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadRecipeScreen extends StatefulWidget {
  const UploadRecipeScreen({super.key});

  @override
  State<UploadRecipeScreen> createState() => _UploadRecipeScreenState();
}

class _UploadRecipeScreenState extends State<UploadRecipeScreen> {
  static const _categories = [
    'All Recipes',
    'Zero Waste',
    'Quick & Easy',
    'Pantry Staples',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _ingredientControllers = <TextEditingController>[
    TextEditingController(),
  ];
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageBase64;
  bool _isSaving = false;
  String _selectedCategory = 'All Recipes';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    _cookingTimeController.dispose();
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
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
                'Add meal photo',
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
                onTap: () => Navigator.pop(context, ImageSource.camera),
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
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final imageFile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (imageFile == null) return;

    final bytes = await imageFile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageBase64 = base64Encode(bytes);
    });
  }

  void _addIngredient() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    if (_ingredientControllers.length == 1) return;

    final controller = _ingredientControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  String _authorName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Anonymous';
  }

  Future<void> _saveRecipe() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final steps = _stepsController.text.trim();
    final ingredients = _ingredientControllers
        .map((controller) => controller.text.trim())
        .where((ingredient) => ingredient.isNotEmpty)
        .toList();

    if (title.isEmpty) {
      _showSnackBar('Please enter a recipe title.');
      return;
    }
    if (description.isEmpty) {
      _showSnackBar('Please enter a recipe description.');
      return;
    }
    if (ingredients.isEmpty) {
      _showSnackBar('Please add at least one ingredient.');
      return;
    }
    if (steps.isEmpty) {
      _showSnackBar('Please enter the cooking steps.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please log in before uploading a recipe.');
      return;
    }

    setState(() => _isSaving = true);

    final tags = <String>['Community'];
    if (_selectedCategory != 'All Recipes') {
      tags.add(_selectedCategory);
    }

    try {
      await FirebaseFirestore.instance.collection('recipes').add({
        'userId': user.uid,
        'authorName': _authorName(user),
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'steps': steps,
        'cookingTime': _cookingTimeController.text.trim(),
        'imageBase64': _imageBase64,
        'category': _selectedCategory,
        'tags': tags,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe submitted for review! It will appear once approved.'),
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to upload recipe. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8F4),
      appBar: AppBar(
        title: const Text('Upload Recipe'),
        backgroundColor: const Color(0xFFF9F8F4),
        foregroundColor: const Color(0xFF052A1E),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPhotoPicker(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _titleController,
                  label: 'Recipe Title',
                  hintText: 'e.g. Tomato Fried Rice',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText: 'Tell people what makes this recipe tasty.',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                _buildIngredientsSection(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _stepsController,
                  label: 'Cooking Steps',
                  hintText: '1. Prepare ingredients\n2. Cook\n3. Serve',
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _cookingTimeController,
                  label: 'Cooking Time',
                  hintText: 'e.g. 30 mins',
                ),
                const SizedBox(height: 16),
                _buildCategorySelector(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF052A1E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Upload Recipe',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF34A853),
                    size: 42,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Add meal photo',
                    style: TextStyle(
                      color: Color(0xFF052A1E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to choose camera or gallery',
                    style: TextStyle(color: Color(0xFF777777), fontSize: 12),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            color: Color(0xFF052A1E),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Replace',
                            style: TextStyle(
                              color: Color(0xFF052A1E),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF052A1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF052A1E),
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients',
          style: TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_ingredientControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildPlainField(
                    controller: _ingredientControllers[index],
                    hintText: 'Ingredient ${index + 1}',
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _ingredientControllers.length == 1
                      ? null
                      : () => _removeIngredient(index),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: const Color(0xFF052A1E),
                  disabledColor: Colors.grey.shade300,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addIngredient,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Ingredient'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF34A853),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF052A1E),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        _buildPlainField(
          controller: controller,
          hintText: hintText,
          maxLines: maxLines,
        ),
      ],
    );
  }

  Widget _buildPlainField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF34A853)),
        ),
      ),
    );
  }
}
