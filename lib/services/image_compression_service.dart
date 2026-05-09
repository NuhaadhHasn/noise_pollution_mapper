import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../utils/app_logger.dart';

/// Image Compression Service
/// 
/// Compresses images before upload to reduce:
/// - Upload time (2-3MB → 300-500KB)
/// - Firebase Storage usage
/// - Download time for other users
class ImageCompressionService {
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 80; // 80% quality (visually lossless)

  /// Compress an image from Uint8List
  /// 
  /// Returns compressed image as Uint8List
  Future<Uint8List> compressImage(Uint8List imageData) async {
    try {
      AppLogger.debug('Starting image compression (${imageData.length ~/ 1024}KB)');

      final result = await FlutterImageCompress.compressWithList(
        imageData,
        minWidth: _maxWidth,
        minHeight: _maxHeight,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      final originalSize = imageData.length ~/ 1024;
      final compressedSize = result.length ~/ 1024;
      final reduction = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);

      AppLogger.info(
        'Image compressed: ${originalSize}KB → ${compressedSize}KB ($reduction% reduction)',
      );

      return result;
    } catch (e) {
      AppLogger.error('Image compression failed', e);
      // Return original image if compression fails
      return imageData;
    }
  }

  /// Compress image from file path
  /// 
  /// Returns compressed file path
  Future<String?> compressImageFile(String filePath) async {
    try {
      AppLogger.debug('Starting file compression: $filePath');

      final file = await FlutterImageCompress.compressAndGetFile(
        filePath,
        getTargetPath(filePath),
        minWidth: _maxWidth,
        minHeight: _maxHeight,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      if (file != null) {
        final originalFile = File(filePath);
        final originalSize = await originalFile.length();
        final compressedSize = await file.length();
        final reduction = ((1 - (compressedSize / originalSize)) * 100).toStringAsFixed(1);

        AppLogger.info(
          'File compressed: ${(originalSize / 1024).toStringAsFixed(1)}KB → ${(compressedSize / 1024).toStringAsFixed(1)}KB ($reduction% reduction)',
        );

        return file.path;
      }

      return null;
    } catch (e) {
      AppLogger.error('File compression failed', e);
      return null;
    }
  }

  /// Generate target path for compressed file
  String getTargetPath(String originalPath) {
    final index = originalPath.lastIndexOf('.');
    if (index == -1) return '${originalPath}_compressed.jpg';
    
    return '${originalPath.substring(0, index)}_compressed.jpg';
  }

  /// Get estimated compression ratio
  /// 
  /// Returns estimated size after compression in bytes
  int estimateCompressedSize(int originalSize) {
    // Typical compression ratio is 10-20% of original size
    return (originalSize * 0.15).round();
  }
}
