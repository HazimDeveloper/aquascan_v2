// lib/screens/user/report_issue_screen.dart - FIXED VERSION
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
  
  // Store both File paths and their bytes for reliability
  List<File> _imageFiles = [];
  Map<String, Uint8List> _imageBytes = {};
  
  bool _isLoading = false;
  bool _isDetecting = false;
  bool _isUploadingImages = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence;
  String? _originalClass;
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  // Debug flag
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get location. Please check permissions.'),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logDebug('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
          ),
        );
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
      _logDebug('Opening image picker...');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera, 
        imageQuality: 85, // Slightly higher quality
        maxWidth: 1920, // Higher resolution
        maxHeight: 1080,
      );
      
      if (pickedFile != null) {
        _logDebug('Image picked: ${pickedFile.path}');
        
        // STEP 1: Read the image bytes immediately
        final Uint8List imageBytes = await pickedFile.readAsBytes();
        
        if (imageBytes.isEmpty) {
          _logDebug('ERROR: Could not read image bytes');
          _showErrorMessage('Error: Could not read image data');
          return;
        }
        
        _logDebug('Successfully read ${imageBytes.length} bytes from picked image');
        
        // STEP 2: Create a permanent file in app documents directory
        try {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String fileName = 'water_image_$timestamp.jpg';
          final String permanentPath = path.join(appDocDir.path, fileName);
          
          _logDebug('Creating permanent file: $permanentPath');
          final File permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(imageBytes);
          
          // STEP 3: Verify the file was created successfully
          final bool fileExists = await permanentFile.exists();
          final int fileSize = fileExists ? await permanentFile.length() : 0;
          
          _logDebug('Permanent file created: exists=$fileExists, size=${(fileSize / 1024).toStringAsFixed(2)} KB');
          
          if (fileExists && fileSize > 0) {
            // STEP 4: Add to our lists
            setState(() {
              _imageFiles.add(permanentFile);
              _imageBytes[permanentFile.path] = imageBytes;
            });
            
            _logDebug('Image added to lists. Total images: ${_imageFiles.length}');
            
            // STEP 5: Detect water quality
            await _detectWaterQuality(permanentFile);
            
            _logDebug('Image processing completed successfully');
          } else {
            _logDebug('ERROR: Failed to create permanent file');
            _showErrorMessage('Error: Failed to save image');
          }
        } catch (e) {
          _logDebug('Error creating permanent file: $e');
          _showErrorMessage('Error processing image: $e');
        }
      } else {
        _logDebug('No image picked - user canceled');
      }
    } catch (e) {
      _logDebug('Error picking image: $e');
      _showErrorMessage('Error picking image: $e');
    }
  }
  
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
      });
      
      _logDebug('Starting water quality detection for: ${image.path}');
      _logDebug('File exists: ${await image.exists()}');
      _logDebug('File size: ${await image.length()} bytes');
      
      // Call the API service
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      _logDebug('Water quality detected: ${result.waterQuality}');
      _logDebug('Confidence: ${result.confidence}%');
      _logDebug('Original class: ${result.originalClass}');
      
      setState(() {
        _detectedQuality = result.waterQuality;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _isDetecting = false;
      });
    } catch (e) {
      _logDebug('Error detecting water quality: $e');
      setState(() {
        _isDetecting = false;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      });
      _showErrorMessage('Error detecting water quality: $e');
    }
  }
  
  void _removeImage(int index) {
    if (index >= 0 && index < _imageFiles.length) {
      final file = _imageFiles[index];
      _logDebug('Removing image at index $index: ${file.path}');
      
      setState(() {
        _imageFiles.removeAt(index);
        _imageBytes.remove(file.path);
        
        // Reset detection if all images removed
        if (_imageFiles.isEmpty) {
          _detectedQuality = WaterQualityState.unknown;
          _confidence = null;
          _originalClass = null;
        }
      });
      
      // Clean up the file
      try {
        if (file.existsSync()) {
          file.deleteSync();
          _logDebug('Deleted file: ${file.path}');
        }
      } catch (e) {
        _logDebug('Error deleting file: $e');
      }
    }
  }
  
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      _logDebug('Form validation failed');
      return;
    }
    
    if (_location == null) {
      _logDebug('Submission failed: location is null');
      _showErrorMessage('Location is required. Please try again.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _logDebug('Starting report submission...');
      
      // Get current user
      final user = await _authService.getUserData(_authService.currentUser!.uid);
      _logDebug('User data obtained: ${user.name} (${user.uid})');
      
      // Upload images with improved error handling
      List<String> imageUrls = [];
      
      if (_imageFiles.isNotEmpty) {
        _logDebug('Uploading ${_imageFiles.length} images...');
        setState(() {
          _isUploadingImages = true;
        });
        
        for (int i = 0; i < _imageFiles.length; i++) {
          final file = _imageFiles[i];
          _logDebug('Uploading image ${i + 1}/${_imageFiles.length}: ${file.path}');
          
          try {
            // Method 1: Try direct file upload
            if (await file.exists() && await file.length() > 0) {
              _logDebug('Attempting direct file upload...');
              final url = await _storageService.uploadImage(file, 'reports');
              imageUrls.add(url);
              _logDebug('✅ Direct upload successful: $url');
              continue;
            }
          } catch (e) {
            _logDebug('❌ Direct upload failed: $e');
          }
          
          try {
            // Method 2: Use stored bytes
            final bytes = _imageBytes[file.path];
            if (bytes != null && bytes.isNotEmpty) {
              _logDebug('Attempting upload from stored bytes...');
              final url = await _storageService.uploadImageData(bytes, 'reports');
              imageUrls.add(url);
              _logDebug('✅ Bytes upload successful: $url');
              continue;
            }
          } catch (e) {
            _logDebug('❌ Bytes upload failed: $e');
          }
          
          _logDebug('❌ All upload methods failed for image ${i + 1}');
        }
        
        setState(() {
          _isUploadingImages = false;
        });
        
        _logDebug('Image upload completed: ${imageUrls.length}/${_imageFiles.length} successful');
        
        if (imageUrls.isEmpty && _imageFiles.isNotEmpty) {
          _showErrorMessage('Warning: Unable to upload images. Report will be created without images.');
        }
      }
      
      // Create the report
      final now = DateTime.now();
      final report = ReportModel(
        id: '', // Will be set by Firestore
        userId: user.uid,
        userName: user.name,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _location!,
        address: _addressController.text.trim(),
        imageUrls: imageUrls,
        waterQuality: _detectedQuality,
        isResolved: false,
        createdAt: now,
        updatedAt: now,
      );
      
      _logDebug('Creating report with ${imageUrls.length} images');
      _logDebug('Water quality: $_detectedQuality');
      
      // Save to database
      final reportId = await _databaseService.createReport(report);
      _logDebug('✅ Report created successfully with ID: $reportId');
      
      // Verify the saved report
      try {
        final savedReport = await _databaseService.getReport(reportId);
        _logDebug('✅ Verified saved report has ${savedReport.imageUrls.length} image URLs');
        for (int i = 0; i < savedReport.imageUrls.length; i++) {
          _logDebug('  Image ${i + 1}: ${savedReport.imageUrls[i]}');
        }
      } catch (e) {
        _logDebug('Warning: Could not verify saved report: $e');
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    imageUrls.isNotEmpty 
                      ? 'Report submitted successfully with ${imageUrls.length} image${imageUrls.length == 1 ? '' : 's'}!'
                      : 'Report submitted successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navigate back
        Navigator.pop(context);
      }
    } catch (e) {
      _logDebug('❌ Error submitting report: $e');
      _showErrorMessage('Error submitting report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImages = false;
        });
      }
    }
  }
  
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Water Issue'),
        actions: [
          if (_imageFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_imageFiles.length} photo${_imageFiles.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && !_isUploadingImages
        ? Center(
            child: WaterFillLoader(
              message: 'Getting your location...',
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section
                  _buildImageSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Report details section
                  _buildDetailsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_alt, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Add Photos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_imageFiles.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_imageFiles.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ],
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
            if (_imageFiles.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _imageFiles[index].existsSync()
                              ? Image.file(
                                  _imageFiles[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
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
            
            // Camera button
            Center(
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _imageFiles.isEmpty ? 'Take Photo' : 'Add Another Photo',
                ),
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
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Analyzing water quality...'),
                    ],
                  ),
                ),
              )
            else if (_detectedQuality != WaterQualityState.unknown)
              _buildWaterQualityResult(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWaterQualityResult() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Card(
        elevation: 3,
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AI Water Quality Analysis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WaterQualityUtils.getWaterQualityColor(_detectedQuality).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: WaterQualityUtils.getWaterQualityColor(_detectedQuality).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      WaterQualityUtils.getWaterQualityIcon(_detectedQuality),
                      color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            WaterQualityUtils.getWaterQualityText(_detectedQuality),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                            ),
                          ),
                          if (_confidence != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Confidence: ${_confidence!.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_confidence != null)
                      SizedBox(
                        width: 50,
                        child: LinearProgressIndicator(
                          value: _confidence! / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            WaterQualityUtils.getWaterQualityColor(_detectedQuality),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                WaterQualityUtils.getWaterQualityDescription(_detectedQuality),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailsSection() {
    return Card(
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
                labelText: 'Title *',
                hintText: 'Brief title for the issue',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
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
                labelText: 'Description *',
                hintText: 'Describe the water issue in detail',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
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
                labelText: 'Address *',
                hintText: 'Location of the issue',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isLoading || _isUploadingImages) ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: _isLoading || _isUploadingImages
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isUploadingImages 
                      ? 'Uploading images (${_imageFiles.length})...'
                      : 'Submitting report...',
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Submit Report',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    
    // Clean up temporary files
    for (final file in _imageFiles) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
          _logDebug('Cleaned up temp file: ${file.path}');
        }
      } catch (e) {
        _logDebug('Error cleaning up file: ${file.path} - $e');
      }
    }
    
    _logDebug('ReportIssueScreen disposed');
    super.dispose();
  }
}