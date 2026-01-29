// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'constants.dart'; // Adjust import path
import '../models/player_model.dart';
import '../services/player_service.dart';
import 'custom_dialog.dart'; // Updated import

class EditPlayerBottomSheet extends StatefulWidget {
  final Player player;

  const EditPlayerBottomSheet({super.key, required this.player});

  @override
  State<EditPlayerBottomSheet> createState() => _EditPlayerBottomSheetState();
}

class _EditPlayerBottomSheetState extends State<EditPlayerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jerseyNoController = TextEditingController();
  final _stateController = TextEditingController();
  final _townController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // ✅ new controller
  String? _selectedPosition;
  String? _selectedTeam;
  File? _imageFile;
  String? _photoUrl;
  DateTime? _selectedDob; // ✅ New state for DOB

  final List<String> _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
  final List<String> _teams = [];

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PlayerService _playerService = PlayerService();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.player.name;
    _jerseyNoController.text = widget.player.jerseyNo.toString();
    _stateController.text = widget.player.state;
    _townController.text = widget.player.town;
    _selectedPosition = widget.player.position;
    _selectedTeam = widget.player.team; // Pre-fill for disabled display
    _photoUrl = widget.player.playerPhoto;
    _selectedDob = widget.player.dateOfBirth; // ✅ Pre-fill DOB
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teams').get();
      if (mounted) {
        setState(() {
          _teams.addAll(snapshot.docs.map((doc) => doc['name'] as String));
        });
      }
    } catch (e) {
      if (mounted) {
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
    try {
      final ref = _storage.ref().child('players/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> _pickDob() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDob = pickedDate;
        _dobController.text =
          "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}"; // ✅ update controller
      });
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate() && _selectedDob != null && _selectedPosition != null) {
      try {
        String newPhotoUrl = _photoUrl ?? '';
        if (_imageFile != null) {
          newPhotoUrl = await _uploadImage(_imageFile!);
        }
        final updatedPlayer = Player(
          id: widget.player.id,
          name: _nameController.text,
          position: _selectedPosition!,
          jerseyNo: int.parse(_jerseyNoController.text),
          team: widget.player.team, // Non-editable, preserved from original
          playerPhoto: newPhotoUrl,
          dateOfBirth: _selectedDob!, // ✅ Include DOB
          state: _stateController.text,
          town: _townController.text,
        );
        await _playerService.editPlayer(widget.player.id, updatedPlayer);
        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
          CustomDialog.show(
            context,
            title: 'Success',
            message: 'Player updated successfully!',
            type: DialogType.success,
          );
        }
      } catch (e) {
        if (mounted) {
          CustomDialog.show(
            context,
            title: 'Error',
            message: 'Failed to update player: $e',
            type: DialogType.error,
          );
        }
      }
    } else if (mounted) {
      CustomDialog.show(
        context,
        title: 'Validation Error',
        message: 'Please fill all required fields, including Date of Birth and Position',
        type: DialogType.error,
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
                  'Edit Player',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        errorText: _imageFile == null && (widget.player.playerPhoto.isEmpty)
                            ? 'Please select a photo'
                            : null,
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
                    if (mounted) {
                      setState(() {
                        _selectedPosition = value;
                      });
                    }
                  },
                  validator: (value) => value == null ? 'Please select a position' : null,
                ),
                TextFormField(
                  initialValue: _selectedTeam ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Team',
                  ),
                  enabled: false,
                  style: const TextStyle(color: Colors.grey),
                ),

                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(labelText: 'State'),
                  validator: (value) => value!.isEmpty ? 'Please enter a state' : null,
                ),
                TextFormField(
                  controller: _townController,
                  decoration: const InputDecoration(labelText: 'Town'),
                  validator: (value) => value!.isEmpty ? 'Please enter a town' : null,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dobController, // ✅ use controller instead of hint
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        hintText: _selectedDob == null
                            ? 'Select date of birth'
                            : '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}',
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      validator: (_) => _selectedDob == null ? 'Please select a date of birth' : null,
                    ),
                  ),
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
    _jerseyNoController.dispose();
    _stateController.dispose();
    _townController.dispose();
     _dobController.dispose(); // ✅ dispose DOB controller
    super.dispose();
  }
}

// Helper function to show the bottom sheet
void showEditPlayerBottomSheet(BuildContext context, Player player) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditPlayerBottomSheet(player: player),
  );
}