// lib/screens/admin/admin_report_screen.dart - NEW FILE
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
import '../../widgets/common/custom_bottom.dart';

class AdminReportScreen extends StatefulWidget {
  const AdminReportScreen({Key? key}) : super(key: key);

  @override
  _AdminReportScreenState createState() => _AdminReportScreenState();
}

class _AdminReportScreenState extends State<AdminReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _reporterNameController = TextEditingController();
  
  // Image handling
  List<File> _imageFiles = [];
  Map<String, Uint8List> _imageBytes = {};
  final int _maxImages = 10; // Admin can upload more images
  
  bool _isLoading = false;
  bool _isDetecting = false;
  bool _isUploadingImages = false;
  WaterQualityState _detectedQuality = WaterQualityState.unknown;
  double? _confidence;
  String? _originalClass;
  String _selectedPriority = 'Medium'; // Admin can set priority
  String _selectedCategory = 'Water Quality'; // Admin can categorize
  bool _markAsUrgent = false;
  
  late AuthService _authService;
  late DatabaseService _databaseService;
  late StorageService _storageService;
  late LocationService _locationService;
  late ApiService _apiService;
  
  GeoPoint? _location;
  String? _autoAddress;
  
  final bool _debugMode = true;
  
  // Admin specific options
  final List<String> _priorityOptions = ['Low', 'Medium', 'High', 'Critical'];
  final List<String> _categoryOptions = [
    'Water Quality',
    'Water Supply',
    'Infrastructure',
    'Contamination',
    'Emergency',
    'Maintenance',
    'Other'
  ];
  
  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _databaseService = Provider.of<DatabaseService>(context, listen: false);
    _storageService = Provider.of<StorageService>(context, listen: false);
    _locationService = Provider.of<LocationService>(context, listen: false);
    _apiService = Provider.of<ApiService>(context, listen: false);
    
    _logDebug('AdminReportScreen initialized');
    _getCurrentLocation();
    _loadAdminData();
  }
  
  void _logDebug(String message) {
    if (_debugMode) {
      print('👨‍💼 AdminReport: $message');
    }
  }
  
  Future<void> _loadAdminData() async {
    try {
      final user = await _authService.getUserData(_authService.currentUser!.uid);
      setState(() {
        _reporterNameController.text = '${user.name} (Admin)';
      });
    } catch (e) {
      _logDebug('Error loading admin data: $e');
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
              'Add Evidence Photo',
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
            Icon(icon, size: 32, color: AppTheme.primaryColor),
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
        imageQuality: 90, // Higher quality for admin
        maxWidth: 2048,
        maxHeight: 2048,
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
          final String fileName = 'admin_report_$timestamp.jpg';
          final String permanentPath = path.join(appDocDir.path, fileName);
          
          final File permanentFile = File(permanentPath);
          await permanentFile.writeAsBytes(imageBytes);
          
          if (await permanentFile.exists()) {
            setState(() {
              _imageFiles.add(permanentFile);
              _imageBytes[permanentFile.path] = imageBytes;
            });
            
            // Detect water quality for first image
            if (_imageFiles.length == 1) {
              await _detectWaterQuality(permanentFile);
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
  
  Future<void> _detectWaterQuality(File image) async {
    try {
      setState(() {
        _isDetecting = true;
      });
      
      final result = await _apiService.analyzeWaterQualityWithConfidence(image);
      
      setState(() {
        _detectedQuality = result.waterQuality;
        _confidence = result.confidence;
        _originalClass = result.originalClass;
        _isDetecting = false;
      });
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _detectedQuality = WaterQualityState.unknown;
        _confidence = null;
        _originalClass = null;
      });
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
  
  Future<void> _submitAdminReport() async {
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
      _logDebug('Starting admin report submission...');
      
      final user = await _authService.getUserData(_authService.currentUser!.uid);
      
      // Upload images
      List<String> imageUrls = [];
      
      if (_imageFiles.isNotEmpty) {
        setState(() {
          _isUploadingImages = true;
        });
        
        imageUrls = await _storageService.uploadImages(_imageFiles, 'admin_reports');
        
        setState(() {
          _isUploadingImages = false;
        });
      }
      
      // Create enhanced report with admin metadata
      final now = DateTime.now();
      final report = ReportModel(
        id: '',
        userId: user.uid,
        userName: _reporterNameController.text.trim(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _location!,
        address: _addressController.text.trim(),
        imageUrls: imageUrls,
        waterQuality: _detectedQuality,
        isResolved: false, // Admin reports start as unresolved too
        createdAt: now,
        updatedAt: now,
      );
      
      // Create report with enhanced metadata
      final reportData = report.toJson();
      
      // Add admin-specific metadata
      reportData['reportType'] = 'admin_created';
      reportData['priority'] = _selectedPriority;
      reportData['category'] = _selectedCategory;
      reportData['isUrgent'] = _markAsUrgent;
      reportData['createdByAdmin'] = true;
      reportData['adminId'] = user.uid;
      reportData['adminName'] = user.name;
      
      final reportId = await _databaseService.createReport(ReportModel.fromJson(reportData));
      
      _logDebug('✅ Admin report created successfully with ID: $reportId');
      
      if (mounted) {
        _showMessage(
          'Admin report created successfully with ${imageUrls.length} image${imageUrls.length == 1 ? '' : 's'}!',
          isError: false,
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      _logDebug('❌ Error submitting admin report: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Admin Report'),
        backgroundColor: Colors.orange,
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
              message: 'Preparing admin report...',
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin privileges info
                  _buildAdminInfoCard(),
                  
                  const SizedBox(height: 16),
                  
                  // Enhanced image section for admin
                  _buildAdminImageSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Admin report details
                  _buildAdminDetailsSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Admin-specific options
                  _buildAdminOptionsSection(),
                  
                  const SizedBox(height: 24),
                  
                  // Submit button
                  _buildAdminSubmitButton(),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildAdminInfoCard() {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
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
                    'Admin Report Creation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are creating a report with admin privileges. This report will have enhanced metadata and priority settings.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdminImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Evidence Photos',
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
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_imageFiles.length}/$_maxImages',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
                Spacer(),
                if (_imageFiles.length < _maxImages)
                  TextButton.icon(
                    icon: Icon(Icons.add_a_photo, size: 16),
                    label: Text('Add Photo'),
                    onPressed: _pickImage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'High-quality evidence photos for detailed analysis (max $_maxImages photos)',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            // Enhanced image grid for admin
            if (_imageFiles.isNotEmpty)
              Container(
                constraints: BoxConstraints(
                  maxHeight: _imageFiles.length > 4 ? 240 : 120,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _imageFiles.length,
                  itemBuilder: (context, index) {
                    return _buildAdminImageTile(index);
                  },
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Enhanced camera button
            Center(
              child: ElevatedButton.icon(
                onPressed: _imageFiles.length < _maxImages ? _pickImage : null,
                icon: const Icon(Icons.photo_camera),
                label: Text(
                  _imageFiles.isEmpty 
                    ? 'Add Evidence Photo' 
                    : _imageFiles.length < _maxImages 
                      ? 'Add More Photos' 
                      : 'Maximum photos reached',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: _imageFiles.length < _maxImages 
                    ? Colors.orange 
                    : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            // Water quality detection with admin features
            if (_isDetecting)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)),
                      SizedBox(height: 8),
                      Text('Running AI analysis...'),
                    ],
                  ),
                ),
              )
            else if (_detectedQuality != WaterQualityState.unknown)
              _buildAdminWaterQualityResult(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdminImageTile(int index) {
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
              border: index == 0 ? Border.all(color: Colors.orange, width: 2) : null,
            ),
            child: _imageFiles[index].existsSync()
                ? Image.file(
                    _imageFiles[index],
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image),
                  ),
          ),
        ),
        
        // Primary photo indicator
        if (index == 0)
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'PRIMARY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        
        // Remove button
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAdminWaterQualityResult() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Card(
        elevation: 3,
        color: Colors.orange.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.shade200),
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
                      color: Colors.orange,
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
                    'AI Water Quality Analysis (Admin)',
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
                                  'AI Confidence: ${_confidence!.toStringAsFixed(1)}%',
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
                            width: 60,
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
                    if (_originalClass != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Raw Classification: $_originalClass',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
  
  Widget _buildAdminDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Reporter name (prefilled with admin info)
            TextFormField(
              controller: _reporterNameController,
              decoration: const InputDecoration(
                labelText: 'Reporter Name *',
                hintText: 'Name of person reporting',
                prefixIcon: Icon(Icons.person),
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
              decoration: const InputDecoration(
                labelText: 'Issue Title *',
                hintText: 'Brief title for the water issue',
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
                labelText: 'Detailed Description *',
                hintText: 'Detailed description of the water quality issue',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a detailed description';
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
                hintText: 'Exact location of the issue',
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Use current location',
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the location address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdminOptionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Options',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Priority selection
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Priority Level',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.priority_high),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _priorityOptions.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPriority = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _categoryOptions.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Urgent checkbox
            CheckboxListTile(
              value: _markAsUrgent,
              onChanged: (value) {
                setState(() {
                  _markAsUrgent = value ?? false;
                });
              },
              title: const Text('Mark as Urgent'),
              subtitle: const Text('This issue requires immediate attention'),
              activeColor: Colors.red,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdminSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: _isLoading || _isUploadingImages 
          ? (_isUploadingImages 
              ? 'Uploading ${_imageFiles.length} photos...' 
              : 'Creating admin report...')
          : 'Create Admin Report',
        onPressed: (_isLoading || _isUploadingImages) ? null : _submitAdminReport,
        type: CustomButtonType.warning, // Orange color for admin
        size: CustomButtonSize.large,
        icon: _isLoading || _isUploadingImages ? null : Icons.admin_panel_settings,
        isLoading: _isLoading || _isUploadingImages,
        isFullWidth: true,
      ),
    );
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