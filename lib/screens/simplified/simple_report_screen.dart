// lib/screens/simplified/simple_report_screen.dart - COMPLETE REDESIGNED VERSION
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../config/theme.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/location_service.dart';
import '../../services/api_service.dart';
import '../../utils/water_quality_utils.dart';
import '../../widgets/common/custom_loader.dart';

class SimpleReportScreen extends StatefulWidget {
  final bool isAdmin;
  
  const SimpleReportScreen({
    Key? key,
    this.isAdmin = false,
  }) : super(key: key);

  @override
  _SimpleReportScreenState createState() => _SimpleReportScreenState();
}

class _SimpleReportScreenState extends State<SimpleReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _reporterNameController = TextEditingController();
  
  // Image handling
  List<File> _imageFiles = [];
  Map<String, Uint8List> _imageBytes = {};
  final int _maxImages = 10; // More for admin
  
  bool _isLoading = false;
  bool _isDetecting = false;
  bool _isUploadingImages = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence;
  String? _originalClass;
  
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  final bool _debugMode = true;
  
  @override
  void initState() {
    super.initState();
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    // Set default reporter name based on role
    _reporterNameController.text = widget.isAdmin ? 'Admin User' : 'Test User';
    
    _logDebug('SimpleReportScreen initialized (isAdmin: ${widget.isAdmin})');
    _getCurrentLocation();
  }
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('📱 SimpleReport: $message');
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
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _logDebug('Error getting location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    if (_imageFiles.length >= _maxImages) {
      _showMessage('Maximum $_maxImages images allowed', isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    title: 'Camera',
                    subtitle: 'Take new photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildImageSourceOption(
                    icon: Icons.photo_library,
                    title: 'Gallery',
                    subtitle: 'Choose existing',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: widget.isAdmin ? Colors.orange : AppTheme.primaryColor),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      _logDebug('Opening image picker from ${source.name}...');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source, 
        imageQuality: widget.isAdmin ? 90 : 85, // Higher quality for admin
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (pickedFile != null) {
        final Uint8List imageBytes = await pickedFile.readAsBytes();
        
        if (imageBytes.isEmpty) {
          _showMessage('Error: Could not read image data', isError: true);
          return;
        }
        
        try {
          final Directory appDocDir = await getApplicationDocumentsDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String fileName = '${widget.isAdmin ? 'admin' : 'user'}_report_$timestamp.jpg';
          final String permanentPath = path.join(appDocDir.path, fileName);
          
          final File permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(imageBytes);
          
          if (await permanentFile.exists()) {
            setState(() {
              _imageFiles.add(permanentFile);
              _imageBytes[permanentFile.path] = imageBytes;
            });
            
            // Reset previous analysis results when new image added
            if (_imageFiles.length == 1) {
              setState(() {
                _detectedQuality = WaterQualityState.unknown;
                _confidence = null;
                _originalClass = null;
              });
            }
          }
        } catch (e) {
          _showMessage('Error processing image: $e', isError: true);
        }
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }
  
  // REAL BACKEND WATER QUALITY DETECTION
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      });
      
      _logDebug('🔬 Starting REAL water quality detection...');
      _logDebug('📁 Image file: ${image.path}');
      
      // Validate image file
      if (!await image.exists()) {
        throw Exception('Image file does not exist');
      }
      
      final fileSize = await image.length();
      _logDebug('📏 Image size: ${fileSize} bytes');
      
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }
      
      // Test backend connection
      _logDebug('🔗 Testing backend connection...');
      final isConnected = await _apiService.testBackendConnection();
      if (!isConnected) {
        throw Exception('Backend server is not running.\n\nPlease start Python server:\n1. cd backend_version_2\n2. python main.py\n3. Ensure server runs on port 8000');
      }
      
      _logDebug('✅ Backend connected, sending image for analysis...');
      
      // Call real API analysis
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      _logDebug('✅ Real API Analysis completed');
      _logDebug('🎯 Quality: ${result.waterQuality}');
      _logDebug('📊 Confidence: ${result.confidence}%');
      _logDebug('🏷️ Original class: ${result.originalClass}');
      
      // Validate results
      if (result.waterQuality == WaterQualityState.unknown && result.confidence == 0.0) {
        throw Exception('Backend returned invalid analysis results');
      }
      
      setState(() {
        _detectedQuality = result.waterQuality;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _isDetecting = false;
      });
      
      // Show success message with real results
      _showMessage(
        'Analysis Complete: ${WaterQualityUtils.getWaterQualityText(result.waterQuality)} (${result.confidence.toStringAsFixed(1)}% confidence)',
        isError: false,
      );
      
    } catch (e) {
      _logDebug('❌ Real analysis failed: $e');
      
      setState(() {
        _isDetecting = false;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      });
      
      // Show specific error messages
      String errorMessage = 'Water quality analysis failed: ';
      
      if (e.toString().contains('Backend server')) {
        errorMessage += 'Backend server not running. Please start main.py';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage += 'Network connection error. Check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage += 'Analysis timeout. Try with a smaller image or check server.';
      } else {
        errorMessage += e.toString();
      }
      
      _showMessage(errorMessage, isError: true);
    }
  }
  
  void _removeImage(int index) {
    if (index >= 0 && index < _imageFiles.length) {
      final file = _imageFiles[index];
      
      setState(() {
        _imageFiles.removeAt(index);
        _imageBytes.remove(file.path);
        
        if (_imageFiles.isEmpty) {
          _detectedQuality = WaterQualityState.unknown;
          _confidence = null;
          _originalClass = null;
        }
      });
      
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        _logDebug('Error deleting file: $e');
      }
    }
  }
  
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_location == null) {
      _showMessage('Location is required. Please try again.', isError: true);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      _logDebug('Starting report submission...');
      
      // Upload images
      List<String> imageUrls = [];
      
      if (_imageFiles.isNotEmpty) {
        setState(() {
          _isUploadingImages = true;
        });
        
        imageUrls = await _storageService.uploadImages(
          _imageFiles, 
          widget.isAdmin ? 'admin_reports' : 'reports',
        );
        
        setState(() {
          _isUploadingImages = false;
        });
      }
      
      // Create the report
      final now = DateTime.now();
      final report = ReportModel(
        id: '',
        userId: widget.isAdmin ? 'admin-test' : 'user-test',
        userName: _reporterNameController.text.trim(),
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
      
      final reportId = await _databaseService.createReport(report);
      
      _logDebug('✅ Report created successfully with ID: $reportId');
      
      if (mounted) {
        _showMessage(
          'Report submitted successfully with ${imageUrls.length} image${imageUrls.length == 1 ? '' : 's'}!',
          isError: false,
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      _logDebug('❌ Error submitting report: $e');
      _showMessage('Error submitting report: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImages = false;
        });
      }
    }
  }
  
  void _showMessage(String message, {required bool isError}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle, 
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: Duration(seconds: isError ? 4 : 3),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isAdmin ? Colors.orange : AppTheme.primaryColor;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Create Admin Report' : 'Report Water Issue'),
        backgroundColor: themeColor,
        elevation: 0,
        actions: [
          if (_imageFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_imageFiles.length}/$_maxImages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                  // Role indicator
                  if (widget.isAdmin) _buildAdminIndicator(),
                  
                  // Image section
                  _buildImageSection(themeColor),
                  
                  const SizedBox(height: 16),
                  
                  // Details section
                  _buildDetailsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  _buildSubmitButton(themeColor),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildAdminIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.shade50,
                Colors.orange.shade100.withOpacity(0.3),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Report Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Creating report with admin privileges and enhanced AI analysis features',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // REDESIGNED: Modern image section with better layout
  Widget _buildImageSection(Color themeColor) {
    return Column(
      children: [
        // Header Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  themeColor.withOpacity(0.1),
                  themeColor.withOpacity(0.05),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isAdmin ? 'Evidence Collection' : 'Water Photos',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_imageFiles.length}/$_maxImages photos uploaded',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_imageFiles.length < _maxImages)
                        Container(
                          decoration: BoxDecoration(
                            color: themeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: _pickImage,
                            icon: Icon(Icons.add, color: Colors.white),
                            tooltip: 'Add Photo',
                          ),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Backend Requirements Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.psychology, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI-Powered Analysis',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Real-time water quality assessment via Python backend',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Photos Grid Card
        if (_imageFiles.isNotEmpty)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uploaded Photos',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      return _buildModernImageTile(index, themeColor);
                    },
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Camera Button Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.add_a_photo,
                  size: 48,
                  color: _imageFiles.length < _maxImages 
                      ? themeColor 
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  _imageFiles.isEmpty 
                      ? 'Take Your First Photo' 
                      : _imageFiles.length < _maxImages 
                          ? 'Add Another Photo' 
                          : 'Maximum Photos Reached',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _imageFiles.length < _maxImages 
                        ? Colors.black87 
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _imageFiles.isEmpty
                      ? 'Capture clear images for accurate AI analysis'
                      : 'Multiple angles help improve analysis accuracy',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _imageFiles.length < _maxImages ? _pickImage : null,
                    icon: Icon(
                      _imageFiles.isEmpty ? Icons.camera_alt : Icons.add_a_photo,
                    ),
                    label: Text(
                      _imageFiles.isEmpty 
                          ? 'Take Photo' 
                          : _imageFiles.length < _maxImages 
                              ? 'Add More Photos' 
                              : 'Limit Reached',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _imageFiles.length < _maxImages 
                          ? themeColor 
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Analysis State Cards
        if (_isDetecting)
          _buildModernAnalyzingCard(themeColor)
        else if (_detectedQuality != WaterQualityState.unknown || _confidence != null)
          _buildModernResultCard(themeColor)
        else if (_imageFiles.isNotEmpty)
          _buildModernAnalysisPrompt(themeColor),
      ],
    );
  }
  
  // REDESIGNED: Modern image tile
  Widget _buildModernImageTile(int index, Color themeColor) {
    final isMainPhoto = index == 0;
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isMainPhoto 
                ? Border.all(color: themeColor, width: 3)
                : Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: _imageFiles[index].existsSync()
                  ? Image.file(
                      _imageFiles[index],
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Icon(Icons.image, color: Colors.grey.shade400),
                    ),
            ),
          ),
        ),
        
        // Main photo badge
        if (isMainPhoto)
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'MAIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // Remove button
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
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  // REDESIGNED: Modern analyzing state
  Widget _buildModernAnalyzingCard(Color themeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.blue.shade100.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Animated loading circle
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blue.shade300],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'AI Analysis in Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Your water sample is being analyzed by our advanced AI system',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Backend Connected: main.py',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // REDESIGNED: Modern analysis prompt
  Widget _buildModernAnalysisPrompt(Color themeColor) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor.withOpacity(0.1),
              themeColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology,
                  size: 40,
                  color: themeColor,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Ready for Analysis',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: themeColor,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Your photos are ready to be analyzed by our AI system. Get instant water quality assessment with confidence scores.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _detectWaterQuality(_imageFiles.first),
                  icon: Icon(Icons.analytics, size: 24),
                  label: Text(
                    'Start AI Analysis',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // REDESIGNED: Modern result card with better layout
  Widget _buildModernResultCard(Color themeColor) {
    final qualityColor = WaterQualityUtils.getWaterQualityColor(_detectedQuality);
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              qualityColor.withOpacity(0.03),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.green.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Analysis Complete',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Backend: main.py',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _detectWaterQuality(_imageFiles.first),
                    icon: Icon(Icons.refresh, color: themeColor),
                    tooltip: 'Reanalyze',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Main result display
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: qualityColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Water quality result
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: qualityColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: qualityColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            WaterQualityUtils.getWaterQualityIcon(_detectedQuality),
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                WaterQualityUtils.getWaterQualityText(_detectedQuality),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: qualityColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_originalClass != null && _originalClass!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: qualityColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Class: $_originalClass',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: qualityColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Confidence section
                    if (_confidence != null) ...[
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Confidence Level',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _getConfidenceColor(_confidence!),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getConfidenceColor(_confidence!).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_confidence!.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _confidence! / 100,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getConfidenceColor(_confidence!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  WaterQualityUtils.getWaterQualityDescription(_detectedQuality),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              
              // Admin mode indicator
              if (widget.isAdmin) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.orange.shade100.withOpacity(0.3)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Admin Mode: Enhanced analysis with detailed metrics and classification data',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: widget.isAdmin ? Colors.orange : AppTheme.primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Report Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Reporter name
            TextFormField(
              controller: _reporterNameController,
              decoration: InputDecoration(
                labelText: 'Reporter Name *',
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter reporter name';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Title field
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Issue Title *',
                hintText: 'Brief title describing the issue',
                prefixIcon: Icon(Icons.title),
                filled: true,
                fillColor: Colors.grey.shade50,
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
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Detailed description of the water issue',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: widget.isAdmin ? 4 : 3,
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
                labelText: 'Location Address *',
                hintText: 'Where is this issue located?',
                prefixIcon: const Icon(Icons.location_on),
                filled: true,
                fillColor: Colors.grey.shade50,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton(Color themeColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              themeColor,
              themeColor.withOpacity(0.8),
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: (_isLoading || _isUploadingImages) ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _isLoading || _isUploadingImages
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isUploadingImages 
                        ? 'Uploading ${_imageFiles.length} photos...'
                        : widget.isAdmin
                          ? 'Creating admin report...'
                          : 'Submitting report...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isAdmin ? Icons.admin_panel_settings : Icons.send,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isAdmin ? 'Create Admin Report' : 'Submit Report',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  
  // Helper method for confidence colors
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 90) return Colors.green.shade600;
    if (confidence >= 80) return Colors.lightGreen.shade600;
    if (confidence >= 70) return Colors.orange.shade600;
    if (confidence >= 60) return Colors.deepOrange.shade600;
    return Colors.red.shade600;
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _reporterNameController.dispose();
    
    // Clean up temporary files
    for (final file in _imageFiles) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e) {
        _logDebug('Error cleaning up file: ${file.path} - $e');
      }
    }
    
    super.dispose();
  }
}