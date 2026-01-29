import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:kklivescoreadmin/constants/buttons.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:permission_handler/permission_handler.dart';

import '../reusables/constants.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';
import '../models/player_model.dart';

class CreatePlayerScreen extends StatefulWidget {
  final VoidCallback onDone;

  const CreatePlayerScreen({
    super.key,
    required this.onDone,
  });


  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _jerseyNoController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _townController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // pickers / storage
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // UI state
  bool _isLoading = false;
  double? _uploadProgress;

  // form state
  XFile? _pickedFile;
  File? _imageFile; // for mobile
  Uint8List? _webImage; // for web
  DateTime? _selectedDateOfBirth;
  String? _selectedPosition;
  String? _selectedTeamId;
  String? _selectedTeamName;

  // Data
  final List<String> _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'];
  final List<Map<String, String>> _teams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyNoController.dispose();
    _stateController.dispose();
    _townController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _setLoading(bool loading) async {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
    });
  }

  Future<void> _fetchTeams() async {
    await _setLoading(true);
    try {
      final snapshot = await FirebaseFirestore.instance.collection('teams').get();
      if (!mounted) return;
      _teams.clear();
      for (final doc in snapshot.docs) {
        final name = (doc.data()['name'] ?? '') as String;
        _teams.add({'id': doc.id, 'name': name});
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
    } finally {
      await _setLoading(false);
    }
  }

  Future<bool> _requestPermission() async {
    if (kIsWeb) return true; // web doesn't need permissions
    try {
      if (Platform.isAndroid) {
        final statuses = await [Permission.photos, Permission.storage, Permission.mediaLibrary].request();
        return statuses.values.any((s) => s.isGranted);
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final granted = await _requestPermission();
    if (!granted) {
      CustomDialog.show(
        context,
        title: 'Permission Denied',
        message: 'Please allow photo access in settings.',
        type: DialogType.error,
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      _pickedFile = picked;

      if (kIsWeb) {
        _webImage = await picked.readAsBytes();
      } else {
        _imageFile = await _compressImage(File(picked.path), maxBytes: 150 * 1024);
      }

      if (mounted) setState(() {});
    } catch (e) {
      CustomDialog.show(
        context,
        title: 'Image Error',
        message: 'Failed to pick/compress image: $e',
        type: DialogType.error,
      );
    }
  }

  Future<File> _compressImage(File file, {required int maxBytes}) async {
    try {
      int quality = 85;
      File? compressed;
      while (quality >= 30) {
        final targetPath =
            '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_q$quality.jpg';
        compressed = (await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          minWidth: 300,
          minHeight: 300,
        )) as File?;
        if (compressed == null) break;
        if (await compressed.length() <= maxBytes) return compressed;
        quality -= 15;
      }
    } catch (_) {}
    return file;
  }

  Future<String> _uploadImage() async {
    final ref = _storage.ref().child('players/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask uploadTask;

    if (kIsWeb && _webImage != null) {
      uploadTask = ref.putData(_webImage!);
    } else if (_imageFile != null) {
      uploadTask = ref.putFile(_imageFile!);
    } else {
      throw 'No image selected';
    }

    final completer = Completer<String>();
    _uploadProgress = 0.0;
    uploadTask.snapshotEvents.listen((taskSnapshot) {
      if (!mounted) return;
      final progress = taskSnapshot.totalBytes > 0
          ? taskSnapshot.bytesTransferred / taskSnapshot.totalBytes
          : null;
      setState(() {
        _uploadProgress = progress;
      });
    }, onError: (e) => completer.completeError(e));

    try {
      await uploadTask;
      final url = await ref.getDownloadURL();
      completer.complete(url);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    final result = await completer.future;
    if (mounted) setState(() => _uploadProgress = null);
    return result;
  }

  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1960),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _selectedDateOfBirth = picked;
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    });
  }

  String? _validateJersey(String? val) {
    if (val == null || val.trim().isEmpty) return 'Please enter a jersey number';
    final n = int.tryParse(val);
    if (n == null) return 'Please enter a valid number';
    if (n <= 0 || n > 99) return 'Jersey must be between 1 and 99';
    return null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      CustomDialog.show(context, title: 'Missing Image', message: 'Please select a photo.', type: DialogType.error);
      return;
    }
    if (_selectedDateOfBirth == null) {
      CustomDialog.show(context, title: 'Missing Date', message: 'Please select date of birth.', type: DialogType.error);
      return;
    }
    if (_selectedPosition == null) {
      CustomDialog.show(context, title: 'Missing Position', message: 'Please select a position.', type: DialogType.error);
      return;
    }

    await _setLoading(true);

    try {
      final photoUrl = await _uploadImage();
      final playersRef = FirebaseFirestore.instance.collection('players');
      final newDocRef = playersRef.doc();
      final player = Player(
        id: newDocRef.id,
        name: _nameController.text.trim(),
        position: _selectedPosition!,
        jerseyNo: int.parse(_jerseyNoController.text.trim()),
        team: _selectedTeamName,
        teamId: _selectedTeamId,
        playerPhoto: photoUrl,
        dateOfBirth: _selectedDateOfBirth!,
        state: _stateController.text.trim(),
        town: _townController.text.trim(),
      );

      await newDocRef.set(player.toMap());

      if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
        final teamDocRef = FirebaseFirestore.instance.collection('teams').doc(_selectedTeamId);
        await teamDocRef.update({'players': FieldValue.arrayUnion([newDocRef.id])});
      }

      if (!mounted) return;
      await _setLoading(false);

      CustomDialog.show(
        context,
        title: 'Success',
        message: 'Player created successfully.',
        type: DialogType.success,
          onConfirm: () {
    widget.onDone();
  },

      );
    } catch (e) {
      if (mounted) {
        await _setLoading(false);
        CustomDialog.show(context, title: 'Error', message: 'Failed to create player: $e', type: DialogType.error);
      }
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Player Photo', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: kGrey1,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kGrey2.withOpacity(0.4)),
            ),
            child: _pickedFile == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.camera_alt_outlined, size: 36, color: kGrey2),
                        SizedBox(height: 8),
                        Text('Tap to select photo'),
                      ],
                    ),
                  )
                : kIsWeb
                    ? Image.memory(_webImage!, fit: BoxFit.cover)
                    : Image.file(_imageFile!, fit: BoxFit.cover),
          ),
        ),
        if (_pickedFile == null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Required', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.push('/admin_panel')),
        title: const Text('Create a New Player', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        'CREATE A NEW PLAYER',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _jerseyNoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Jersey No.'),
                        validator: _validateJersey,
                      ),
                      const SizedBox(height: 12),
                      _buildImagePicker(),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPosition,
                        decoration: const InputDecoration(labelText: 'Position'),
                        items: _positions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (v) => setState(() => _selectedPosition = v),
                        validator: (v) => v == null ? 'Please select a position' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        decoration: const InputDecoration(labelText: 'Team (optional)'),
                        items: _teams
                            .map((t) => DropdownMenuItem(value: t['id'], child: Text(t['name'] ?? '')))
                            .toList(),
                        onChanged: (teamId) {
                          final teamName = _teams.firstWhere((t) => t['id'] == teamId)['name'];
                          setState(() {
                            _selectedTeamId = teamId;
                            _selectedTeamName = teamName;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickDateOfBirth,
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _dobController,
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            validator: (v) => _selectedDateOfBirth == null ? 'Please select date of birth' : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(labelText: 'State'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter state' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _townController,
                        decoration: const InputDecoration(labelText: 'Town'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter town' : null,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(text: 'REGISTER PLAYER', onPressed: _isLoading ? () {} : _submitForm),
                      const SizedBox(height: 12),
                      SecondaryButton(text: 'CANCEL', onPressed: () => context.go('/admin_panel')),
                      if (_uploadProgress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: LinearProgressIndicator(value: _uploadProgress),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CustomProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
