import 'dart:io';
import 'package:aquasense/models/complaint_model.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/services/storage_service.dart';
import 'package:aquasense/widgets/custom_input.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class ReportLeakScreen extends StatefulWidget {
  const ReportLeakScreen({super.key});

  @override
  State<ReportLeakScreen> createState() => _ReportLeakScreenState();
}

class _ReportLeakScreenState extends State<ReportLeakScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  final List<String> _allComplaintTypes = ['Leakage', 'Quality', 'No Water', 'Billing', 'Other'];
  final List<String> _limitedComplaintTypes = ['Leakage', 'Other'];
  List<String> _complaintTypes = [];

  String? _selectedComplaintType;
  XFile? _imageFile;
  Position? _currentPosition;
  bool _isLocationLoading = false;

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _setComplaintTypes();
  }

  Future<void> _setComplaintTypes() async {
    final user = FirebaseAuth.instance.currentUser;
    bool hasConnection = false;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        hasConnection = userDoc.data()?['hasActiveConnection'] ?? false;
      }
    }

    if (mounted) {
      setState(() {
        _complaintTypes = hasConnection ? _allComplaintTypes : _limitedComplaintTypes;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() => _isLocationLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        setState(() => _isLocationLoading = false);
        return;
      }

      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocationLoading = false);
      }
    }
  }

  // --- MODIFIED SUBMISSION LOGIC ---
  void _submitComplaint() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedComplaintType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a complaint type.')));
      return;
    }

    // Show success dialog immediately
    _showSuccessDialog();

    // Perform the actual submission in the background
    _performBackgroundSubmission();
  }

  Future<void> _performBackgroundSubmission() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _storageService.uploadComplaintImage(_imageFile!, user.uid);
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userWardId = userDoc.data()?['wardId'] ?? 'unknown';

      final complaint = Complaint(
        userId: user.uid,
        type: _selectedComplaintType!,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        wardId: userWardId,
        location: _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
        createdAt: Timestamp.now(),
      );

      await _firestoreService.submitComplaint(complaint);
      debugPrint("Background complaint submission successful.");
    } catch (e) {
      debugPrint("Background complaint submission failed: $e");
    }
  }

  void _showSuccessDialog() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C5364),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
              const SizedBox(height: 16),
              const Text("Complaint Submitted!",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Your complaint has been successfully submitted.",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
                Navigator.of(context).pop(); // Go back from report screen
              },
              child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ));
  }

  // The rest of your build method and other helpers remain the same
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildDropdown(),
              const SizedBox(height: 20),
              CustomInput(
                controller: _descriptionController,
                hintText: 'Describe the issue...',
                icon: Icons.description_outlined,
                glowAnimation: _glowController,
                validator: (value) => value!.trim().isEmpty ? 'Description cannot be empty.' : null,
              ),
              const SizedBox(height: 20),
              _buildImagePicker(),
              const SizedBox(height: 20),
              _buildLocationPicker(),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitComplaint,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Submit Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedComplaintType,
      items: _complaintTypes.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) => setState(() => _selectedComplaintType = newValue),
      decoration: InputDecoration(
        hintText: 'Type of Complaint',
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.category_outlined, color: Colors.white70),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
      validator: (value) => value == null ? 'Please select a complaint type.' : null,
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: _imageFile != null
              ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(File(_imageFile!.path), fit: BoxFit.contain))
              : const Center(child: Text('No image selected.', style: TextStyle(color: Colors.white70))),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.cyanAccent),
              label: const Text('Camera', style: TextStyle(color: Colors.cyanAccent)),
            ),
            TextButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, color: Colors.cyanAccent),
              label: const Text('Gallery', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: _currentPosition == null
              ? const Text(
            'No location attached.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          )
              : Text(
            'Location Attached:\nLat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}',
            style: const TextStyle(color: Colors.greenAccent),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLocationLoading)
          const CircularProgressIndicator()
        else
          TextButton.icon(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.my_location, color: Colors.cyanAccent),
            label: const Text('Attach Current Location', style: TextStyle(color: Colors.cyanAccent)),
          ),
      ],
    );
  }
}