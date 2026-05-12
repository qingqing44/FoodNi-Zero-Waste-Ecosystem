import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> scanFoodItem() async {
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
      
      final bytes = await image.readAsBytes();
      
      if (kIsWeb) {
        final uploadTask = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        downloadUrl = await uploadTask.ref.getDownloadURL();
      } else {
        final file = File(image.path);
        final uploadTask = await ref.putFile(file);
        downloadUrl = await uploadTask.ref.getDownloadURL();
      }

      // 2. Call Gemini API directly
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("Gemini API key is not configured");
      }

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(responseMimeType: 'application/json'),
      );

      final prompt = "Analyze this image. Identify the main food item shown. Also, carefully read any text to find an expiry date or best before date. Finally, provide a brief suggestion on how best to store this item to keep it fresh. Return the result strictly as a JSON object with three keys: 'foodName' (string, a clear short name of the food), 'expiryDate' (string, the date found, or null if none found), and 'storageSuggestion' (string, short advice on how to store it). Do not include markdown formatting or extra text.";

      final imagePart = DataPart('image/jpeg', bytes);
      final response = await model.generateContent([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      final resultText = response.text;
      if (resultText == null) {
        throw Exception("Empty response from Gemini API");
      }

      print("Gemini Response: $resultText");

      Map<String, dynamic> parsedResult;
      try {
        parsedResult = jsonDecode(resultText);
      } catch (e) {
        print("Failed to parse Gemini response as JSON: $e");
        final cleanText = resultText.replaceAll('```json', '').replaceAll('```', '').trim();
        parsedResult = jsonDecode(cleanText);
      }

      return {
        'foodName': parsedResult['foodName'] ?? 'Unknown Food',
        'expiryDate': parsedResult['expiryDate'] ?? 'Unknown Expiry',
        'storageSuggestion': parsedResult['storageSuggestion'] ?? 'Store in a cool, dry place.',
        'imageUrl': downloadUrl,
        'userId': user.uid,
      };

    } catch (e) {
      print("Error scanning food item: $e");
      rethrow;
    }
  }
}
