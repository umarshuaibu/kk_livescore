import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../models/coach_model.dart';
import '../services/coach_service.dart';

class EditCoachBottomSheet extends StatefulWidget {
  final Coach coach;

  const EditCoachBottomSheet({super.key, required this.coach});

  @override
  State<EditCoachBottomSheet> createState() => _EditCoachBottomSheetState();
}

class _EditCoachBottomSheetState extends State<EditCoachBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedTeam;
  File? _imageFile;
  String? _photoUrl;

  final List<String> _teams = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CoachService _coachService = CoachService();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.coach.name;
    _selectedTeam = widget.coach.team;
    _photoUrl = widget.coach.photoUrl;
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    final snapshot = await FirebaseFirestore.instance.collection('teams').get();
    setState(() {
      _teams.addAll(snapshot.docs.map((doc) => doc['name'] as String));
    });
  }

  Future<bool> _requestPermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      status = await Permission.photos.request();
    }
    return status.isGranted;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied for image access')),
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

  void _saveChanges() async {
    if (_formKey.currentState!.validate() && (_photoUrl != widget.coach.photoUrl || _imageFile != null)) {
      try {
        String newPhotoUrl = _photoUrl ?? '';
        if (_imageFile != null) {
          newPhotoUrl = await _uploadImage(_imageFile!);
        }
        final updatedCoach = Coach(
          id: widget.coach.id,
          name: _nameController.text,
          team: _selectedTeam,
          photoUrl: newPhotoUrl.isNotEmpty ? newPhotoUrl : null,
        );
        await _coachService.editCoach(widget.coach.id, updatedCoach);
        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating coach: $e')),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields or update the photo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Coach',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: AbsorbPointer(
                    child: TextFormField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Coach Photo',
                        suffixIcon: const Icon(Icons.camera_alt),
                        errorText: _imageFile == null && (widget.coach.photoUrl == null || widget.coach.photoUrl!.isEmpty) ? 'Please select a photo' : null,
                      ),
                    ),
                  ),
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.whiteColor,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

// Helper function to show the bottom sheet
void showEditCoachBottomSheet(BuildContext context, Coach coach) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditCoachBottomSheet(coach: coach),
  );
}