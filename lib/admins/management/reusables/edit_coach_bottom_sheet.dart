// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'constants.dart';
import '../models/coach_model.dart';
import 'custom_dialog.dart';
import 'custom_progress_indicator.dart';

class EditCoachBottomSheet extends StatefulWidget {
  final Coach coach;

  const EditCoachBottomSheet({super.key, required this.coach});

  @override
  State<EditCoachBottomSheet> createState() => _EditCoachBottomSheetState();
}

class _EditCoachBottomSheetState extends State<EditCoachBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();

  String? _selectedTeam;
  File? _imageFile;
  //String? _photoUrl;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = true;

  final Map<String, String> _teams = {};          // teamId -> teamName
  final Set<String> _assignableTeams = {};        // teamIds we allow selecting
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();

    // Coach model has non-nullable name/id; avoid unnecessary null ops
    _nameController.text = widget.coach.name;
    _selectedTeam = widget.coach.teamId;               // can be null
    //_photoUrl = widget.coach.photoUrl;
    _selectedDateOfBirth = widget.coach.dateOfBirth;   // can be null

    _dobController.text = _selectedDateOfBirth == null
        ? ''
        : "${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}";

    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('teams').get();

      if (!mounted) return;

      _teams.clear();
      _assignableTeams.clear();

      for (final doc in snap.docs) {
        final teamId = doc.id;
        final data = doc.data();
        final teamName = (data['name'] ?? '') as String;

        _teams[teamId] = teamName;

        // A team is assignable if it has no coach, OR it's currently assigned to THIS coach
        final coachId = data['coachId'] as String?;
        if (coachId == null || coachId == widget.coach.id) {
          _assignableTeams.add(teamId);
        }
      }

      // If the selected team no longer exists, clear it
      if (_selectedTeam != null && !_teams.containsKey(_selectedTeam)) {
        _selectedTeam = null;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to fetch teams: $e',
        type: DialogType.error,
      );
    }
  }

  // Platform-aware permission handling (aligned with your create screen)
  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      // Try legacy storage first
      if (await Permission.storage.isGranted) return true;
      if (await Permission.storage.request().isGranted) return true;

      // Android 13+ granular media permissions may be mapped differently;
      // try photos / mediaLibrary as fallbacks via permission_handler.
      if (await Permission.photos.isGranted) return true;
      if (await Permission.photos.request().isGranted) return true;

      if (await Permission.mediaLibrary.isGranted) return true;
      if (await Permission.mediaLibrary.request().isGranted) return true;

      return false;
    } else if (Platform.isIOS) {
      return await Permission.photos.request().isGranted;
    }
    return false;
  }

  Future<void> _pickImage() async {
    if (!await _requestPermission()) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Permission Denied',
        message:
            'Permission denied for image access. Please allow access in settings.',
        type: DialogType.error,
      );
      return;
    }

    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      final compressed = await _compressImage(File(picked.path));
      if (!mounted) return;
      setState(() => _imageFile = compressed);
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Image Error',
        message: 'Failed to process image: $e',
        type: DialogType.error,
      );
    }
  }

  Future<File> _compressImage(File file) async {
    final out = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 85,
      minHeight: 300,
      minWidth: 300,
    );
    if (out != null) {
      final size = await out.length();
      if (size > 150 * 1024) {
        throw Exception('Image size exceeds 150KB after compression');
      }
      return File(out.path);
    }
    return file;
  }

  Future<String> _uploadImage(File image) async {
    final ref = _storage
        .ref()
        .child('coaches/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(1980, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _saveChanges() async {
    // Validate form & DOB
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateOfBirth == null) {
      CustomDialog.show(
        context,
        title: 'Validation Error',
        message: 'Please select a date of birth.',
        type: DialogType.error,
      );
      return;
    }

    final coachId = widget.coach.id; // non-nullable
    if (coachId.isEmpty) {
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Invalid coach ID.',
        type: DialogType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new image only if user picked one
      String? newPhotoUrl;
      if (_imageFile != null) {
        newPhotoUrl = await _uploadImage(_imageFile!);
      }

      final String? teamName =
          _selectedTeam != null ? _teams[_selectedTeam] : null;

      // Build update map explicitly so we don't overwrite fields unintentionally
      final Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'teamId': _selectedTeam,                  // can be null to unassign
        'teamName': teamName,                     // can be null
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String(),
      };
      if (newPhotoUrl != null) {
        updateData['photoUrl'] = newPhotoUrl;     // only update if changed
      }

      // Update coach doc
      final coachDoc =
          FirebaseFirestore.instance.collection('coaches').doc(coachId);
      await coachDoc.update(updateData);

      // If team changed, keep team->coachId in sync
      if (widget.coach.teamId != _selectedTeam) {
        // Clear old team.coachId if existed
        if (widget.coach.teamId != null && widget.coach.teamId!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(widget.coach.teamId)
              .update({'coachId': FieldValue.delete()});
        }
        // Set new team.coachId if assigned
        if (_selectedTeam != null && _selectedTeam!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(_selectedTeam)
              .update({'coachId': coachId});
        }
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      CustomDialog.show(
        context,
        title: 'Success',
        message: 'Coach updated successfully.',
        type: DialogType.success,
        onConfirm: () => context.go('/admin_panel'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Error updating coach: $e',
        type: DialogType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
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
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please enter a name'
                              : null,
                    ),
                    const SizedBox(height: 16),

                    // Photo (optional on edit)
                    GestureDetector(
                      onTap: _pickImage,
                      child: AbsorbPointer(
                        child: TextFormField(
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Coach Photo (optional)',
                            suffixIcon: Icon(Icons.camera_alt),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Team (optional)
                    DropdownButtonFormField<String>(
                      value: _selectedTeam,
                      isExpanded: true,
                      hint: const Text('Select Team (Optional)'),
                      items: _teams.entries.map((entry) {
                        final teamId = entry.key;
                        final teamName = entry.value;

                        final isCurrentTeam = teamId == widget.coach.teamId;
                        final isEnabled =
                            _assignableTeams.contains(teamId) || isCurrentTeam;

                        return DropdownMenuItem<String>(
                          value: teamId,
                          enabled: isEnabled,
                          child: Opacity(
                            opacity: isEnabled ? 1.0 : 0.5,
                            child: Text(teamName),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        // Allow null (unassign) and any assignable team
                        if (!mounted) return;
                        if (value == null) {
                          setState(() => _selectedTeam = null);
                          return;
                        }
                        if (_assignableTeams.contains(value) ||
                            value == widget.coach.teamId) {
                          setState(() => _selectedTeam = value);
                        } else {
                          CustomDialog.show(
                            context,
                            title: 'Restricted Selection',
                            message:
                                'Only available teams can be selected.',
                            type: DialogType.warning,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // DOB (required)
                    GestureDetector(
                      onTap: _pickDateOfBirth,
                      child: AbsorbPointer(
                        child: TextFormField(
                          enabled: false,
                          controller: _dobController,
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            hintText: 'Select Date of Birth',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          validator: (value) =>
                              _selectedDateOfBirth == null
                                  ? 'Please select a date of birth'
                                  : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
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
        ),

        // Overlay loader
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(child: CustomProgressIndicator()),
          ),
      ],
    );
  }
}

// Helper to show the bottom sheet (kept the same signature)
void showEditCoachBottomSheet(BuildContext context, Coach coach) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => EditCoachBottomSheet(coach: coach),
  );
}
