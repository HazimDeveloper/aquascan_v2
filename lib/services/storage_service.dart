// Updated StorageService.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final bool _debugMode = true; // Enable debug logging
  
  // Helper method for debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      print('🔥 StorageService: $message');
    }
  }
  
  // Upload an image to Firebase Storage with improved error handling
  Future<String> uploadImage(File file, String folder) async {
    try {
      _logDebug('Starting upload for file: ${file.path}');
      
      // Verify file exists and is readable
      if (!file.existsSync()) {
        _logDebug('Error: File does not exist: ${file.path}');
        throw Exception('File does not exist: ${file.path}');
      }
      
      final fileSize = await file.length();
      _logDebug('File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      if (fileSize <= 0) {
        _logDebug('Error: File is empty: ${file.path}');
        throw Exception('File is empty: ${file.path}');
      }
      
      // Generate a unique filename with timestamp to prevent conflicts
      final uuid = Uuid();
      final extension = path.extension(file.path).isNotEmpty 
          ? path.extension(file.path) 
          : '.jpg'; // Default to .jpg if no extension
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${uuid.v4()}$extension';
      _logDebug('Generated filename: $fileName in folder: $folder');
      
      // Create reference with more specific path
      final storageRef = _storage.ref().child('$folder/$fileName');
      _logDebug('Storage reference created: ${storageRef.fullPath}');
      
      // Read file data to ensure it's accessible
      _logDebug('Verifying file data is accessible...');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _logDebug('Error: Could not read file data: ${file.path}');
        throw Exception('Could not read file data: ${file.path}');
      }
      _logDebug('Successfully read ${bytes.length} bytes from file');
      
      // Upload using putData instead of putFile for more reliability
      try {
        _logDebug('Starting file upload to Firebase...');
        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'source': 'water_watch_app',
              'originalPath': file.path,
              'uploadTime': DateTime.now().toIso8601String(),
            },
          ),
        );
        
        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          _logDebug('Upload progress: ${progress.toStringAsFixed(1)}%');
        }, onError: (e) {
          _logDebug('Upload snapshot error: $e');
        });
        
        final snapshot = await uploadTask.whenComplete(() {
          _logDebug('Upload completed successfully');
        });
        
        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        _logDebug('Download URL obtained: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        _logDebug('Error during Firebase upload: $e');
        throw Exception('Failed to upload to Firebase: $e');
      }
    } catch (e) {
      _logDebug('Error in uploadImage: $e');
      throw Exception('Failed to upload image: $e');
    }
  }
  
  // Upload multiple images with improved reliability
  Future<List<String>> uploadImages(List<File> files, String folder) async {
    _logDebug('Starting upload of ${files.length} images to folder: $folder');
    
    if (files.isEmpty) {
      _logDebug('No files to upload, returning empty list');
      return [];
    }
    
    try {
      final List<String> urls = [];
      final List<String> failedUploads = [];
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        try {
          bool fileValid = false;
          
          try {
            fileValid = file.existsSync() && await file.length() > 0;
          } catch (fileCheckError) {
            _logDebug('Error checking file ${i+1}: $fileCheckError');
          }
          
          if (fileValid) {
            _logDebug('Processing file ${i+1}/${files.length}: ${file.path}');
            final fileSize = await file.length();
            _logDebug('File ${i+1} size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
            
            // Try to upload and get URL
            try {
              final url = await uploadImage(file, folder);
              _logDebug('File ${i+1} uploaded successfully, URL: $url');
              urls.add(url);
            } catch (uploadError) {
              _logDebug('Error uploading file ${i+1}: $uploadError');
              failedUploads.add(file.path);
              
              // Try one more time with direct data upload
              try {
                _logDebug('Attempting alternate upload method for file ${i+1}...');
                final bytes = await file.readAsBytes();
                if (bytes.isNotEmpty) {
                  final uuid = Uuid();
                  final fileName = '${DateTime.now().millisecondsSinceEpoch}_${uuid.v4()}.jpg';
                  final storageRef = _storage.ref().child('$folder/$fileName');
                  
                  final uploadTask = storageRef.putData(
                    bytes,
                    SettableMetadata(contentType: 'image/jpeg'),
                  );
                  
                  final snapshot = await uploadTask.whenComplete(() {
                    _logDebug('Alternate upload completed for file ${i+1}');
                  });
                  
                  final url = await snapshot.ref.getDownloadURL();
                  _logDebug('Alternate upload successful, URL: $url');
                  urls.add(url);
                }
              } catch (alternateUploadError) {
                _logDebug('Alternate upload also failed: $alternateUploadError');
              }
            }
          } else {
            _logDebug('Skipping invalid file ${i+1}: ${file.path}');
            failedUploads.add(file.path);
          }
        } catch (e) {
          _logDebug('Error handling file ${i+1} (${file.path}): $e');
          failedUploads.add(file.path);
        }
      }
      
      if (failedUploads.isNotEmpty) {
        _logDebug('WARNING: Failed to upload ${failedUploads.length} files');
      }
      
      _logDebug('Finished uploading ${urls.length}/${files.length} files');
      return urls;
    } catch (e) {
      _logDebug('Error in uploadImages: $e');
      throw Exception('Failed to upload images: $e');
    }
  }
  
  // Delete an image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      _logDebug('Attempting to delete image: $imageUrl');
      
      // Extract file path from URL
      final ref = _storage.refFromURL(imageUrl);
      _logDebug('Resolved storage reference: ${ref.fullPath}');
      
      await ref.delete();
      _logDebug('Image deleted successfully');
    } catch (e) {
      _logDebug('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }
  
  // Get Firebase Storage reference from URL
  Reference? getStorageRefFromUrl(String url) {
    try {
      return _storage.refFromURL(url);
    } catch (e) {
      _logDebug('Error getting reference from URL: $e');
      return null;
    }
  }

 Future<String> uploadImageData(Uint8List imageData, String folder) async {
  try {
    _logDebug('Starting upload of image data (${imageData.length} bytes)');
    
    if (imageData.isEmpty) {
      _logDebug('Error: Image data is empty');
      throw Exception('Image data is empty');
    }
    
    // Generate a unique filename with timestamp
    final uuid = Uuid();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_${uuid.v4()}.jpg';
    _logDebug('Generated filename: $fileName in folder: $folder');
    
    // Create reference
    final storageRef = _storage.ref().child('$folder/$fileName');
    _logDebug('Storage reference created: ${storageRef.fullPath}');
    
    // Upload the data directly
    try {
      _logDebug('Starting data upload to Firebase...');
      final uploadTask = storageRef.putData(
        imageData,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'source': 'water_watch_app',
            'uploadType': 'direct_data',
            'uploadTime': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        _logDebug('Upload progress: ${progress.toStringAsFixed(1)}%');
      }, onError: (e) {
        _logDebug('Upload snapshot error: $e');
      });
      
      final snapshot = await uploadTask.whenComplete(() {
        _logDebug('Data upload completed successfully');
      });
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _logDebug('Download URL obtained: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      _logDebug('Error during Firebase data upload: $e');
      throw Exception('Failed to upload data to Firebase: $e');
    }
  } catch (e) {
    _logDebug('Error in uploadImageData: $e');
    throw Exception('Failed to upload image data: $e');
  }
}
  
  // Check if a file exists in Firebase Storage
  Future<bool> fileExists(String filePath) async {
    try {
      _logDebug('Checking if file exists: $filePath');
      final ref = _storage.ref().child(filePath);
      await ref.getDownloadURL();
      _logDebug('File exists: $filePath');
      return true;
    } catch (e) {
      _logDebug('File does not exist or error: $filePath, $e');
      return false;
    }
  }
}