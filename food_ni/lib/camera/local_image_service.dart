import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Manages saving food images and thumbnails to the app's local documents directory.
///
/// Directory layout:
/// ```
///   <appDocDir>/food_images/food_<timestamp>.jpg         ← full image
///   <appDocDir>/food_images/thumb_<timestamp>.jpg        ← compressed thumbnail (150×150)
/// ```
class LocalImageService {
  /// Returns a web-safe data URL that can be rendered directly by Image.network
  /// and stored without relying on a device file system.
  String dataUrlFromBytes(Uint8List bytes, {String mimeType = 'image/jpeg'}) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  /// Returns (imagePath, thumbnailPath).
  /// Throws an exception if the save operation fails.
  Future<({String imagePath, String thumbnailPath})> saveImage(
    File sourceFile,
  ) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final foodImagesDir = Directory(p.join(docsDir.path, 'food_images'));

      // Create the directory if it doesn't already exist.
      if (!foodImagesDir.existsSync()) {
        await foodImagesDir.create(recursive: true);
      }

      // Generate a unique, timestamp-based filename.
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final imageName = 'food_$timestamp.jpg';
      final thumbName = 'thumb_$timestamp.jpg';

      final imagePath = p.join(foodImagesDir.path, imageName);
      final thumbPath = p.join(foodImagesDir.path, thumbName);

      // 1. Copy the full-quality image to permanent local storage.
      await sourceFile.copy(imagePath);

      // 2. Create a compressed thumbnail (quality 60, max 400px wide)
      //    for fast rendering in list views.
      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        thumbPath,
        quality: 60,
        minWidth: 400,
        minHeight: 400,
      );

      // If compression fails for any reason, fall back to the full image.
      final finalThumbPath = result?.path ?? imagePath;

      return (imagePath: imagePath, thumbnailPath: finalThumbPath);
    } catch (e) {
      throw Exception('Failed to save image locally: $e');
    }
  }

  /// Web has no writable local file path like mobile, so we keep the selected
  /// image in a data URL that the UI and Firestore can both reuse.
  Future<({String imagePath, String thumbnailPath})> saveWebImage(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    if (!kIsWeb) {
      throw Exception('saveWebImage should only be used on web.');
    }

    final dataUrl = dataUrlFromBytes(bytes, mimeType: mimeType);
    return (imagePath: dataUrl, thumbnailPath: dataUrl);
  }
}
