import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '/reusables/constants.dart'; // Adjust import path
import '../../models/player_model.dart';
import '../../services/player_service.dart';

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
  String? _selectedPosition;
  String? _selectedTeam;
  File? _imageFile;
  String? _photoUrl;

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
    _selectedPosition = widget.player.position;
    _selectedTeam = widget.player.team;
    _photoUrl = widget.player.playerPhoto;
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
    final ref = _storage.ref().child('players/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate() && (widget.player.playerPhoto != _photoUrl || _imageFile != null)) {
      try {
        String newPhotoUrl = _photoUrl!;
        if (_imageFile != null) {
          newPhotoUrl = await _uploadImage(_imageFile!);
        }
        final updatedPlayer = Player(
          id: widget.player.id,
          name: _nameController.text,
          position: _selectedPosition!,
          jerseyNo: int.parse(_jerseyNoController.text),
          team: _selectedTeam,
          playerPhoto: newPhotoUrl,
        );
        await _playerService.editPlayer(widget.player.id, updatedPlayer);
        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating player: $e')),
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
                        errorText: _imageFile == null && widget.player.playerPhoto.isEmpty ? 'Please select a photo' : null,
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