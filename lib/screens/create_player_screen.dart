import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../reusables/constants.dart'; // Adjust import path
import '../../models/player_model.dart';
import '../../services/player_service.dart';

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

  void _submitForm() async {
    if (_formKey.currentState!.validate() && _imageFile != null) {
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
        );
        await _playerService.addPlayer(player);
        if (mounted) {
          context.go('/admin');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else if (_imageFile == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create a New Player', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Padding(
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
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.whiteColor,
                    ),
                    child: const Text('ACTION BUTTON'),
                  ),
                ],
              ),
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