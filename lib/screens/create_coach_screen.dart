import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/coach_model.dart';
//import '../services/coach_service.dart';
import '/reusables/custom_dialog.dart'; // Added import for CustomDialog
import '../reusables/custom_progress_indicator.dart'; // Added import for CustomProgressIndicator

class CreateCoachScreen extends StatefulWidget {
  const CreateCoachScreen({super.key});

  @override
  State<CreateCoachScreen> createState() => _CreateCoachScreenState();
}

class _CreateCoachScreenState extends State<CreateCoachScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  //final _coachService = CoachService();
  String? _selectedTeam;
  File? _imageFile;
  String? _photoUrl;
  DateTime? _selectedDateOfBirth; // ✅ Added DOB

  final Map<String, String> _teams = {}; // Maps teamId to teamName
  final List<String> _availableTeams = []; // Tracks teamIds with null coachId
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = true; // Added to track loading state

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

/*  Future<void> _fetchTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teams').get();
      if (mounted) {
        setState(() {
          // Clear existing data
          _teams.clear();
          _availableTeams.clear();
          // Populate teams and available teams
          for (var doc in snapshot.docs) {
            final teamId = doc.id; // Use team document ID
            final teamName = doc['name'] as String;
            _teams[teamId] = teamName; // Map teamId to name

           /* */ final coachId = doc['coachId'] as String?; // Check coachId in team
            if (coachId == null) { // Team with no coach
              _availableTeams.add(teamId);
            }
          }
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
*/

Future<void> _fetchTeams() async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection('teams').get();
    if (mounted) {
      setState(() {
        _teams.clear();
        _availableTeams.clear();

        for (var doc in snapshot.docs) {
          final teamId = doc.id;
          // ignore: unnecessary_cast
          final data = doc.data() as Map<String, dynamic>;
          final teamName = data['name'] as String;
          _teams[teamId] = teamName;

          // ✅ Check safely if coachId exists
          final coachId = data.containsKey('coachId') ? data['coachId'] as String? : null;
          if (coachId == null) {
            _availableTeams.add(teamId);
          }
        }

        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _isLoading = false;
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


  // ✅ Permission handling
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.mediaLibrary.isGranted) {
        return true;
      }

      if (await Permission.storage.request().isGranted) return true;

      // For Android 13+
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
    final ref = _storage.ref().child('coaches/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  // ✅ Pick Date of Birth
  Future<void> _pickDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1980, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _imageFile != null && _selectedDateOfBirth != null) {
      setState(() {
        _isLoading = true; // Show loading during submission
      });
      try {
        _photoUrl = await _uploadImage(_imageFile!);
        final String? teamName = _selectedTeam != null ? _teams[_selectedTeam] : null;
        final coach = Coach(
          id: '', // Will be auto-generated by Firestore
          name: _nameController.text,
          teamId: _selectedTeam, // Use teamId (document ID)
          teamName: teamName, // Store team name
          photoUrl: _photoUrl,
          dateOfBirth: _selectedDateOfBirth!, // ✅ include DOB
        );
        // Add coach and get the generated ID
       final coachRef = await FirebaseFirestore.instance.collection('coaches').add(coach.toJson());
        final coachId = coachRef.id;

        // Update coach document with its generated ID
          await coachRef.update({'id': coachId});

        // If a team is selected, update the team's coachId
        if (_selectedTeam != null) {
          await FirebaseFirestore.instance.collection('teams').doc(_selectedTeam).update({
            'coachId': coachId,
          });
        }

        if (mounted) {
          setState(() {
            _isLoading = false; // Hide loading after success
          });
          CustomDialog.show(
            context,
            title: 'Success',
            message: 'Coach created successfully!',
            type: DialogType.success,
            onConfirm: () => context.go('/admin_panel'), // Navigate after confirmation
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
            message: 'Failed to create coach: $e',
            type: DialogType.error,
          );
        }
      }
    } else if (_imageFile == null && mounted) {
      CustomDialog.show(
        context,
        title: 'Missing Image',
        message: 'Please select an image for the coach.',
        type: DialogType.error,
      );
    } else if (_selectedDateOfBirth == null && mounted) {
      CustomDialog.show(
        context,
        title: 'Missing Date',
        message: 'Please select the date of birth.',
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
          onPressed: () => context.pop('/coach_list'),
        ),
        title: const Text('Add New Coach', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          // Main content (always visible)
          Center(
            child: Card(
              elevation: 4.0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              margin: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CREATE A NEW COACH',
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
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickImage,
                        child: AbsorbPointer(
                          child: TextFormField(
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Coach Photo',
                              suffixIcon: const Icon(Icons.camera_alt),
                              errorText: _imageFile == null ? 'Please select a photo' : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedTeam,
                        hint: const Text('Select Team'),
                        items: _teams.entries.map((entry) {
                          final teamId = entry.key;
                          final teamName = entry.value;
                          return DropdownMenuItem<String>(
                            value: teamId,
                            enabled: _availableTeams.contains(teamId), // Only teams with null coachId are clickable
                            child: Opacity(
                              opacity: _availableTeams.contains(teamId) ? 1.0 : 0.5, // Full opacity for clickable, low opacity for non-clickable
                              child: Text(teamName),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (mounted && value != null && _availableTeams.contains(value)) {
                            setState(() {
                              _selectedTeam = value;
                            });
                          } else if (mounted) {
                            // Show dialog if user tries to select a team with a coach
                            CustomDialog.show(
                              context,
                              title: 'Restricted Selection',
                              message: 'Only teams with no coach can be selected.',
                              type: DialogType.warning,
                            );
                          }
                        },
                        validator: (value) => null, // teamId is nullable, no validation required
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickDateOfBirth,
                        child: AbsorbPointer(
                          child: TextFormField(
                            enabled: false,
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              hintText: 'Select Date of Birth',
                              suffixIcon: const Icon(Icons.calendar_today),
                              errorText: _selectedDateOfBirth == null ? 'Please select a date' : null,
                            ),
                            controller: TextEditingController(
                              text: _selectedDateOfBirth == null
                                  ? ''
                                  : "${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}",
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
                        child: const Text('Submit'),
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
              // ignore: deprecated_member_use
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
    super.dispose();
  }
}