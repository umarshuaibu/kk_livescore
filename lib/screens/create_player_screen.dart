// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../reusables/constants.dart'; // Adjust import path
import '../models/player_model.dart';
import '../services/player_service.dart';
import '../reusables/custom_dialog.dart'; // Updated import for CustomDialog
import '../reusables/custom_progress_indicator.dart'; // Added import for CustomProgressIndicator

class CreatePlayerScreen extends StatefulWidget {
  const CreatePlayerScreen({super.key});

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerService = PlayerService();
  final _nameController = TextEditingController();
  final _jerseyNoController = TextEditingController();
  String? _selectedPosition;
  String? _selectedTeam;
  String? _photoUrl; // Used to store the uploaded image URL
  File? _imageFile;
  DateTime? _selectedDateOfBirth; // ✅ New DOB state
  bool _isLoading = true; // Added to track loading state

  final List<String> _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
  final List<String> _teams = [];

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teams').get();
      if (mounted) {
        setState(() {
          _teams.addAll(snapshot.docs.map((doc) => doc['name'] as String));
          _isLoading = false; // Set loading to false after fetch
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false; // Ensure loading stops on error
        });
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to fetch teams: $e',
          type: DialogType.error,
        );
      }
    }
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.mediaLibrary.isGranted) {
        return true;
      }
      if (await Permission.storage.request().isGranted) return true;
      if (await Permission.photos.request().isGranted) return true;
      if (await Permission.mediaLibrary.request().isGranted) return true;
      return false;
    } else if (Platform.isIOS) {
      return await Permission.photos.request().isGranted;
    }
    return false;
  }

  Future<void> _pickImage() async {
    if (await _requestPermission()) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final compressedFile = await _compressImage(File(pickedFile.path));
        if (mounted) {
          setState(() {
            _imageFile = compressedFile;
          });
        }
      }
    } else if (mounted) {
      CustomDialog.show(
        context,
        title: 'Permission Denied',
        message: 'Permission denied for image access. Please allow access in settings.',
        type: DialogType.error,
      );
    }
  }

  Future<File> _compressImage(File file) async {
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 85,
      minHeight: 300,
      minWidth: 300,
    );
    if (compressed != null) {
      final sizeInBytes = await compressed.length();
      if (sizeInBytes > 150 * 1024) {
        throw Exception('Image size exceeds 150KB after compression');
      }
      return File(compressed.path);
    }
    return file;
  }

  Future<String> _uploadImage(File image) async {
    final ref = _storage.ref().child('players/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDateOfBirth = pickedDate;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _imageFile != null && _selectedDateOfBirth != null) {
      setState(() {
        _isLoading = true; // Show loading during submission
      });
      try {
        _photoUrl = await _uploadImage(_imageFile!); // Store the photo URL
        final newPlayerId = FirebaseFirestore.instance.collection('players').doc().id;
        final player = Player(
          id: newPlayerId,
          name: _nameController.text,
          position: _selectedPosition!,
          jerseyNo: int.parse(_jerseyNoController.text),
          team: _selectedTeam,
          playerPhoto: _photoUrl!, // Use the stored photo URL
          dateOfBirth: _selectedDateOfBirth!, // ✅ include DOB
        );
        await _playerService.addPlayer(player);
        if (mounted) {
          setState(() {
            _isLoading = false; // Hide loading after success
          });
          CustomDialog.show(
            context,
            title: 'Success',
            message: 'Player created successfully!',
            type: DialogType.success,
            onConfirm: () => context.go('/admin_panel'),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false; // Hide loading on error
          });
          CustomDialog.show(
            context,
            title: 'Error',
            message: 'Failed to create player: $e',
            type: DialogType.error,
          );
        }
      }
    } else if (_imageFile == null && mounted) {
      CustomDialog.show(
        context,
        title: 'Missing Image',
        message: 'Please select an image',
        type: DialogType.error,
      );
    } else if (_selectedDateOfBirth == null && mounted) {
      CustomDialog.show(
        context,
        title: 'Missing Date',
        message: 'Please select date of birth',
        type: DialogType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/admin_panel'),
        ),
        title: const Text('Create a New Player', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          // Main content (always visible)
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CREATE A NEW PLAYER',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                      ),
                      TextFormField(
                        controller: _jerseyNoController,
                        decoration: const InputDecoration(labelText: 'Jersey No.'),
                        keyboardType: TextInputType.number,
                        validator: (value) => value!.isEmpty ? 'Please enter a jersey number' : null,
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: AbsorbPointer(
                          child: TextFormField(
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Player Photo',
                              suffixIcon: const Icon(Icons.camera_alt),
                              errorText: _imageFile == null ? 'Please select a photo' : null,
                            ),
                          ),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedPosition,
                        hint: const Text('Select Position'),
                        items: _positions.map((position) {
                          return DropdownMenuItem<String>(
                            value: position,
                            child: Text(position),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPosition = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a position' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedTeam,
                        hint: const Text('Select Team'),
                        items: _teams.map((team) {
                          return DropdownMenuItem<String>(
                            value: team,
                            child: Text(team),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeam = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickDateOfBirth,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              suffixIcon: const Icon(Icons.calendar_today),
                              hintText: _selectedDateOfBirth == null
                                  ? 'Select Date of Birth'
                                  : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                              errorText: _selectedDateOfBirth == null ? 'Please select date of birth' : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: AppColors.whiteColor,
                        ),
                        child: const Text('REGISTER PLAYER'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Loading overlay with CustomProgressIndicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
              child: Center(child: CustomProgressIndicator()),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyNoController.dispose();
    super.dispose();
  }
}