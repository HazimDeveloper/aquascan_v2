// lib/screens/user/report_issue_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../utils/water_quality_utils.dart';
import '../../widgets/common/custom_loader.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({Key? key}) : super(key: key);

  @override
  _ReportIssueScreenState createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  List<XFile> _pickedImages = []; // Using XFile to store picked images
  
  // Map to store image bytes for backup/recovery
  Map<String, Uint8List> _imageBytesMaps = {};
  
  bool _isLoading = false;
  bool _isDetecting = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence; // Store confidence score from API
  String? _originalClass; // Original class from the backend for reference
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  // Debug flag to log details
  final bool _debugMode = true;
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _logDebug('ReportIssueScreen initialized');
    _getCurrentLocation();
  }
  
  // Helper method for debug logging
  void _logDebug(String message) {
    if (_debugMode) {
      print('📱 ReportScreen: $message');
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      _logDebug('Getting current location...');
      final position = await _locationService.getCurrentLocation();
      
      if (position != null) {
        _logDebug('Location obtained: ${position.latitude}, ${position.longitude}');
        final address = await _locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        _logDebug('Address resolved: $address');
        
        setState(() {
          _location = _locationService.positionToGeoPoint(position);
          _autoAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        _logDebug('Failed to get location - null position returned');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get location. Please check permissions.'),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logDebug('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
        ),
      );
    }
  }
  
  Future<void> _pickImage() async {
    try {
      _logDebug('Opening image picker...');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera, 
        imageQuality: 80,
        maxWidth: 1280, 
        maxHeight: 960,
      );
      
      if (pickedFile != null) {
        _logDebug('Image picked: ${pickedFile.path}');
        
        // Immediately read the bytes from the picked file
        final Uint8List? imageBytes = await pickedFile.readAsBytes();
        
        if (imageBytes == null || imageBytes.isEmpty) {
          _logDebug('ERROR: Could not read image bytes from picked file');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Could not read image data'),
            ),
          );
          return;
        }
        
        _logDebug('Successfully read ${imageBytes.length} bytes from picked image');
        
        // Save the bytes to a permanent file in app documents directory
        try {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String newFilePath = '${appDocDir.path}/water_image_$timestamp.jpg';
          
          _logDebug('Saving image bytes to permanent file: $newFilePath');
          final File newFile = File(newFilePath);
          await newFile.writeAsBytes(imageBytes);
          
          // Verify the file was saved
          final fileExists = await newFile.exists();
          final fileSize = fileExists ? await newFile.length() : 0;
          
          _logDebug('Permanent file created: $fileExists, Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
          
          if (fileExists && fileSize > 0) {
            // Create an XFile from the new path and add to picked images
            final XFile persistentXFile = XFile(newFile.path);
            
            setState(() {
              _pickedImages.add(persistentXFile);
            });
            
            // Store the original bytes for backup/recovery
            _imageBytesMaps[persistentXFile.path] = imageBytes;
            
            // Detect water quality
            _detectWaterQuality(newFile);
            
            _logDebug('Image successfully processed and stored');
          } else {
            _logDebug('ERROR: Failed to create permanent file');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Failed to save image'),
              ),
            );
          }
        } catch (e) {
          _logDebug('Error saving image to permanent file: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: $e'),
            ),
          );
        }
      } else {
        _logDebug('No image picked - user canceled');
      }
    } catch (e) {
      _logDebug('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
        ),
      );
    }
  }
  
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
      });
      
      // Add detailed logging
      _logDebug('Starting water quality detection for image: ${image.path}');
      _logDebug('File exists: ${image.existsSync()}');
      _logDebug('File size: ${await image.length()} bytes');
      
      // Call the API service and get both quality state and confidence
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      // Log the result
      _logDebug('Detected water quality: ${result.waterQuality} with confidence: ${result.confidence}%');
      _logDebug('Original class from backend: ${result.originalClass}');
      
      setState(() {
        _detectedQuality = result.waterQuality;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _isDetecting = false;
      });
    } catch (e) {
      _logDebug('Error in _detectWaterQuality: $e');
      setState(() {
        _isDetecting = false;
        // Set a default quality but no confidence on error
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error detecting water quality: $e'),
        ),
      );
    }
  }
  
  void _removeImage(int index) {
    _logDebug('Removing image at index $index');
    final xFile = _pickedImages[index];
    
    setState(() {
      _pickedImages.removeAt(index);
      
      // Also remove from bytes map
      _imageBytesMaps.remove(xFile.path);
      
      // Reset detection if all images are removed
      if (_pickedImages.isEmpty) {
        _logDebug('All images removed, resetting detection state');
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      }
    });
  }
  
  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      if (_location == null) {
        _logDebug('Submission failed: location is null');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location is required. Please try again.'),
          ),
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Get current user
        _logDebug('Getting current user data...');
        final user = await _authService.getUserData(_authService.currentUser!.uid);
        _logDebug('User data obtained: ${user.name} (${user.uid})');
        
        // Upload images - completely reworked approach
        List<String> imageUrls = [];
        if (_pickedImages.isNotEmpty) {
          _logDebug('Preparing to upload ${_pickedImages.length} images');
          
          for (int i = 0; i < _pickedImages.length; i++) {
            final xFile = _pickedImages[i];
            _logDebug('Processing image ${i+1}/${_pickedImages.length}: ${xFile.path}');
            
            // First try: Direct file upload
            try {
              final File file = File(xFile.path);
              final bool fileExists = await file.exists();
              final int fileSize = fileExists ? await file.length() : 0;
              
              _logDebug('Checking file: Exists=$fileExists, Size=${(fileSize / 1024).toStringAsFixed(2)} KB');
              
              if (fileExists && fileSize > 0) {
                _logDebug('Uploading file directly: ${file.path}');
                final url = await _storageService.uploadImage(file, 'reports');
                _logDebug('Successful direct file upload. URL: $url');
                imageUrls.add(url);
                continue; // Skip to next image if successful
              } else {
                _logDebug('File does not exist or is empty, trying backup data...');
              }
            } catch (e) {
              _logDebug('Error in direct file upload: $e');
            }
            
            // Second try: Use stored bytes data
            try {
              final bytes = _imageBytesMaps[xFile.path];
              if (bytes != null && bytes.isNotEmpty) {
                _logDebug('Found backup image data (${bytes.length} bytes), uploading...');
                final url = await _storageService.uploadImageData(bytes, 'reports');
                _logDebug('Successful data upload from backup. URL: $url');
                imageUrls.add(url);
                continue; // Skip to next image if successful
              } else {
                _logDebug('No backup data found for: ${xFile.path}');
              }
            } catch (e) {
              _logDebug('Error in backup data upload: $e');
            }
            
            // Third try: Read the XFile again
            try {
              _logDebug('Attempting to read XFile directly: ${xFile.path}');
              final bytes = await xFile.readAsBytes();
              if (bytes.isNotEmpty) {
                _logDebug('Successfully read ${bytes.length} bytes from XFile, uploading...');
                final url = await _storageService.uploadImageData(bytes, 'reports');
                _logDebug('Successful XFile data upload. URL: $url');
                imageUrls.add(url);
              } else {
                _logDebug('Failed to read any bytes from XFile');
              }
            } catch (e) {
              _logDebug('Error reading or uploading XFile data: $e');
            }
          }
          
          _logDebug('Image upload summary: ${imageUrls.length}/${_pickedImages.length} successful');
          
          if (imageUrls.isEmpty && _pickedImages.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Warning: Unable to upload images. Report will be created without images.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          _logDebug('No images to upload');
        }
        
        // Create report
        final now = DateTime.now();
        _logDebug('Creating report with title: ${_titleController.text}');
        _logDebug('Water quality: $_detectedQuality');
        _logDebug('Image URLs count: ${imageUrls.length}');
        
        final report = ReportModel(
          id: '',  // Will be set by Firestore
          userId: user.uid,
          userName: user.name,
          title: _titleController.text,
          description: _descriptionController.text,
          location: _location!,
          address: _addressController.text,
          imageUrls: imageUrls,
          waterQuality: _detectedQuality,
          isResolved: false,
          createdAt: now,
          updatedAt: now,
        );
        
        _logDebug('Saving report to Firestore...');
        final reportId = await _databaseService.createReport(report);
        _logDebug('Report created successfully with ID: $reportId');
        
        // Verify report was saved with images
        try {
          final savedReport = await _databaseService.getReport(reportId);
          _logDebug('Verified saved report: ${savedReport.title}');
          _logDebug('Saved report has ${savedReport.imageUrls.length} image URLs');
          if (savedReport.imageUrls.isNotEmpty) {
            _logDebug('First image URL: ${savedReport.imageUrls.first}');
          }
        } catch (verifyError) {
          _logDebug('Error verifying saved report: $verifyError');
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear image bytes map
        _imageBytesMaps.clear();
        
        // Go back to previous screen
        Navigator.pop(context);
      } catch (e) {
        _logDebug('Error submitting report: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      _logDebug('Form validation failed');
    }
  }
  
  // Clean up temporary files created during image capture
  void _cleanupTempFiles() {
    _logDebug('Cleaning up temporary files...');
    for (var xFile in _pickedImages) {
      try {
        final file = File(xFile.path);
        if (file.existsSync()) {
          _logDebug('Deleting temp file: ${xFile.path}');
          file.deleteSync();
        }
      } catch (e) {
        _logDebug('Error deleting temp file: ${xFile.path} - $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Water Issue'),
      ),
      body: _isLoading 
        ? Center(
            child: WaterFillLoader(
              message: 'Processing your report...',
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Photos (Optional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adding photos helps us analyze the water quality more accurately',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Image grid
                          if (_pickedImages.isNotEmpty)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _pickedImages.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(File(_pickedImages[index].path)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Add photo button
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          
                          // Water quality detection result
                          if (_isDetecting)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else if (_detectedQuality != WaterQualityState.unknown)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            WaterQualityUtils.getWaterQualityIcon(_detectedQuality),
                                            color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Water Quality Analysis',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Quality State:',
                                                  style: TextStyle(
                                                    color: Theme.of(context).textTheme.bodySmall?.color,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: WaterQualityUtils.getWaterQualityColor(_detectedQuality).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  child: Text(
                                                    WaterQualityUtils.getWaterQualityText(_detectedQuality),
                                                    style: TextStyle(
                                                      color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (_originalClass != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Class: $_originalClass',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Only show confidence if it's available
                                          if (_confidence != null)
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Confidence:',
                                                    style: TextStyle(
                                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: LinearProgressIndicator(
                                                          value: _confidence! / 100,
                                                          minHeight: 10,
                                                          backgroundColor: Colors.grey.shade200,
                                                          valueColor: AlwaysStoppedAnimation<Color>(
                                                            WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Align(
                                                        alignment: Alignment.centerRight,
                                                        child: Text(
                                                          '${_confidence!.toStringAsFixed(1)}%',
                                                          style: TextStyle(
                                                            color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        WaterQualityUtils.getWaterQualityDescription(_detectedQuality),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Report details section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Issue Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Title field
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Brief title for the issue',
                              prefixIcon: Icon(Icons.title),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Description field
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'Describe the water issue in detail',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Address field
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              hintText: 'Location of the issue',
                              prefixIcon: const Icon(Icons.location_on),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getCurrentLocation,
                                tooltip: 'Use current location',
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an address';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _logDebug('ReportIssueScreen disposed');
    super.dispose();
  }
}