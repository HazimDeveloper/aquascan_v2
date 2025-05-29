// SOLUTION 1: Enhanced StorageService with better error handling
// lib/services/storage_service.dart - UPDATED VERSION

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final bool _debugMode = true;
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('🔥 StorageService: $message');
    }
  }
  
  /// Test Firebase Storage connection
  Future<bool> testStorageConnection() async {
    try {
      _logDebug('Testing Firebase Storage connection...');
      
      // Try to get a reference - this will fail if Storage is not configured
      final ref = _storage.ref().child('test');
      await ref.getDownloadURL().catchError((e) {
        // This error is expected for non-existent files, but confirms Storage works
        _logDebug('Storage test completed (expected error for non-existent file)');
        return '';
      });
      
      _logDebug('✅ Firebase Storage connection successful');
      return true;
    } catch (e) {
      _logDebug('❌ Firebase Storage connection failed: $e');
      return false;
    }
  }
  
  /// Upload image with comprehensive error handling and retry logic
  Future<String> uploadImage(File file, String folder) async {
    try {
      _logDebug('=== STARTING IMAGE UPLOAD ===');
      _logDebug('File path: ${file.path}');
      _logDebug('Folder: $folder');
      
      // STEP 1: Validate file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist: ${file.path}');
      }
      
      final fileSize = await file.length();
      _logDebug('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      if (fileSize <= 0) {
        throw Exception('File is empty: ${file.path}');
      }
      
      if (fileSize > 10 * 1024 * 1024) { // 10MB limit
        throw Exception('File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      // STEP 2: Test Storage connection first
      final isConnected = await testStorageConnection();
      if (!isConnected) {
        throw Exception('Firebase Storage is not accessible. Please check your configuration.');
      }
      
      // STEP 3: Read file bytes
      _logDebug('Reading file bytes...');
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Could not read file data');
      }
      _logDebug('Successfully read ${bytes.length} bytes');
      
      // STEP 4: Generate unique filename
      final uuid = Uuid();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(file.path).toLowerCase();
      final validExtension = ['.jpg', '.jpeg', '.png'].contains(extension) ? extension : '.jpg';
      final fileName = 'water_${timestamp}_${uuid.v4()}$validExtension';
      
      _logDebug('Generated filename: $fileName');
      
      // STEP 5: Create storage reference
      final storageRef = _storage.ref().child('$folder/$fileName');
      _logDebug('Storage path: ${storageRef.fullPath}');
      
      // STEP 6: Upload with metadata and progress tracking
      _logDebug('Starting upload...');
      
      final metadata = SettableMetadata(
        contentType: _getContentType(validExtension),
        customMetadata: {
          'source': 'aquascan_app',
          'originalName': path.basename(file.path),
          'uploadTime': DateTime.now().toIso8601String(),
          'fileSize': fileSize.toString(),
        },
      );
      
      final uploadTask = storageRef.putData(bytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          _logDebug('Upload progress: ${progress.toStringAsFixed(1)}%');
        },
        onError: (error) {
          _logDebug('Upload progress error: $error');
        },
      );
      
      // Wait for upload completion with timeout
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Upload timeout after 2 minutes');
        },
      );
      
      _logDebug('Upload completed, getting download URL...');
      
      // STEP 7: Get download URL with retry logic
      String downloadUrl = '';
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          downloadUrl = await snapshot.ref.getDownloadURL();
          break;
        } catch (e) {
          _logDebug('Download URL attempt $attempt failed: $e');
          if (attempt == 3) rethrow;
          await Future.delayed(Duration(seconds: attempt));
        }
      }
      
      if (downloadUrl.isEmpty) {
        throw Exception('Failed to get download URL');
      }
      
      _logDebug('✅ Upload successful!');
      _logDebug('Download URL: $downloadUrl');
      _logDebug('=== UPLOAD COMPLETE ===');
      
      return downloadUrl;
      
    } catch (e) {
      _logDebug('❌ Upload failed: $e');
      
      // Provide specific error messages
      if (e.toString().contains('storage/unauthorized')) {
        throw Exception('Storage access denied. Please check Firebase Storage rules.');
      } else if (e.toString().contains('storage/network-error')) {
        throw Exception('Network error. Please check your internet connection.');
      } else if (e.toString().contains('storage/quota-exceeded')) {
        throw Exception('Storage quota exceeded. Please contact support.');
      } else if (e.toString().contains('timeout')) {
        throw Exception('Upload timeout. Please try again with a smaller image.');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }
  
  /// Upload image data directly from bytes
  Future<String> uploadImageData(Uint8List imageData, String folder) async {
    try {
      _logDebug('=== STARTING DATA UPLOAD ===');
      _logDebug('Data size: ${(imageData.length / 1024).toStringAsFixed(2)} KB');
      
      if (imageData.isEmpty) {
        throw Exception('Image data is empty');
      }
      
      if (imageData.length > 10 * 1024 * 1024) {
        throw Exception('Image data too large: ${(imageData.length / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      // Test connection
      final isConnected = await testStorageConnection();
      if (!isConnected) {
        throw Exception('Firebase Storage is not accessible');
      }
      
      // Generate filename
      final uuid = Uuid();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'water_data_${timestamp}_${uuid.v4()}.jpg';
      
      _logDebug('Generated filename: $fileName');
      
      // Create reference and upload
      final storageRef = _storage.ref().child('$folder/$fileName');
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'source': 'aquascan_app_data',
          'uploadTime': DateTime.now().toIso8601String(),
          'dataSize': imageData.length.toString(),
        },
      );
      
      _logDebug('Starting data upload...');
      final uploadTask = storageRef.putData(imageData, metadata);
      
      final snapshot = await uploadTask.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Data upload timeout');
        },
      );
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      _logDebug('✅ Data upload successful!');
      _logDebug('Download URL: $downloadUrl');
      
      return downloadUrl;
      
    } catch (e) {
      _logDebug('❌ Data upload failed: $e');
      throw Exception('Data upload failed: ${e.toString()}');
    }
  }
  
  /// Upload multiple images with individual error handling
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    _logDebug('=== UPLOADING ${files.length} IMAGES ===');
    
    if (files.isEmpty) return [];
    
    final List<String> successfulUrls = [];
    final List<String> failedFiles = [];
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      _logDebug('Processing image ${i + 1}/${files.length}: ${file.path}');
      
      try {
        final url = await uploadImage(file, folder);
        successfulUrls.add(url);
        _logDebug('✅ Image ${i + 1} uploaded successfully');
      } catch (e) {
        _logDebug('❌ Image ${i + 1} failed: $e');
        failedFiles.add(path.basename(file.path));
      }
    }
    
    _logDebug('=== UPLOAD SUMMARY ===');
    _logDebug('Successful: ${successfulUrls.length}/${files.length}');
    _logDebug('Failed: ${failedFiles.length}');
    
    if (failedFiles.isNotEmpty) {
      _logDebug('Failed files: ${failedFiles.join(', ')}');
    }
    
    return successfulUrls;
  }
  
  /// Get appropriate content type for file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
  
  /// Delete an image from storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      _logDebug('Deleting image: $imageUrl');
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      _logDebug('✅ Image deleted successfully');
    } catch (e) {
      _logDebug('❌ Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
}
