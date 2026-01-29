import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/coach_model.dart';
import '../reusables/constants.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';

class CreateCoachScreen extends StatefulWidget {
  const CreateCoachScreen({super.key});

  @override
  State<CreateCoachScreen> createState() => _CreateCoachScreenState();
}

class _CreateCoachScreenState extends State<CreateCoachScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedTeam;
  Uint8List? _webImageBytes;
  XFile? _pickedFile;
  String? _photoUrl;
  DateTime? _selectedDateOfBirth;

  final Map<String, String> _teams = {}; // teamId -> teamName
  final List<String> _availableTeams = [];

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  // ================= FETCH TEAMS =================
  Future<void> _fetchTeams() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('teams').get();

      _teams.clear();
      _availableTeams.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final teamId = doc.id;
        final teamName = data['name'] as String;

        _teams[teamId] = teamName;

        final coachId =
            data.containsKey('coachId') ? data['coachId'] as String? : null;

        if (coachId == null) {
          _availableTeams.add(teamId);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to fetch teams: $e',
          type: DialogType.error,
        );
      }
    }
  }

  // ================= PICK IMAGE (WEB SAFE) =================
  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (mounted) {
      setState(() {
        _pickedFile = picked;
        _webImageBytes = bytes;
      });
    }
  }

  // ================= UPLOAD IMAGE =================
  Future<String> _uploadImage() async {
    final ref = _storage
        .ref()
        .child('coaches/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putData(
      _webImageBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }

  // ================= PICK DOB =================
  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1980),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  // ================= SUBMIT =================
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_webImageBytes == null) {
      CustomDialog.show(
        context,
        title: 'Missing Image',
        message: 'Please select a coach photo.',
        type: DialogType.error,
      );
      return;
    }

    if (_selectedDateOfBirth == null) {
      CustomDialog.show(
        context,
        title: 'Missing Date',
        message: 'Please select date of birth.',
        type: DialogType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      _photoUrl = await _uploadImage();

      final teamName =
          _selectedTeam != null ? _teams[_selectedTeam] : null;

      final coach = Coach(
        id: '',
        name: _nameController.text.trim(),
        teamId: _selectedTeam,
        teamName: teamName,
        photoUrl: _photoUrl!,
        dateOfBirth: _selectedDateOfBirth!,
      );

      final coachRef = await FirebaseFirestore.instance
          .collection('coaches')
          .add(coach.toJson());

      await coachRef.update({'id': coachRef.id});

      if (_selectedTeam != null) {
        await FirebaseFirestore.instance
            .collection('teams')
            .doc(_selectedTeam)
            .update({'coachId': coachRef.id});
      }

      if (mounted) {
        setState(() => _isLoading = false);
        CustomDialog.show(
          context,
          title: 'Success',
          message: 'Coach created successfully!',
          type: DialogType.success,
          onConfirm: () => context.go('/admin_panel'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to create coach: $e',
          type: DialogType.error,
        );
      }
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Coach',
            style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          Center(
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            v!.isEmpty ? 'Required' : null,
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey),
                          ),
                          child: _webImageBytes == null
                              ? const Icon(Icons.camera_alt)
                              : ClipOval(
                                  child: Image.memory(
                                    _webImageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _selectedTeam,
                        hint: const Text('Select Team'),
                        items: _teams.entries.map((e) {
                          final enabled =
                              _availableTeams.contains(e.key);
                          return DropdownMenuItem(
                            value: e.key,
                            enabled: enabled,
                            child: Opacity(
                              opacity: enabled ? 1 : 0.4,
                              child: Text(e.value),
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (_availableTeams.contains(v)) {
                            setState(() => _selectedTeam = v);
                          } else {
                            CustomDialog.show(
                              context,
                              title: 'Restricted',
                              message:
                                  'Only teams without a coach can be selected.',
                              type: DialogType.warning,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _pickDateOfBirth,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              suffixIcon:
                                  Icon(Icons.calendar_today),
                            ),
                            controller: TextEditingController(
                              text: _selectedDateOfBirth == null
                                  ? ''
                                  : '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primaryColor,
                          foregroundColor:
                              AppColors.whiteColor,
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child:
                  const Center(child: CustomProgressIndicator()),
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
