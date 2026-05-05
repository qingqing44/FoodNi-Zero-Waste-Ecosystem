import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
class CameraService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> scanFoodItem() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Compress slightly for faster upload
      );

      if (image == null) return null; // User cancelled

      final user = _auth.currentUser;
      if (user == null) throw Exception("User must be logged in to scan items");

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'users/${user.uid}/food_images/$timestamp.jpg';

      // 1. Upload to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      String downloadUrl;
      
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } else {
        final file = File(image.path);
        final uploadTask = await ref.putFile(file);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      // 2. Trigger Cloud Function by creating a document in Firestore
      final docRef = await _firestore.collection('image_processing_queue').add({
        'userId': user.uid,
        'imageUrl': downloadUrl,
        'storagePath': storagePath,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print("Error scanning food item: $e");
      rethrow;
    }
  }
}
