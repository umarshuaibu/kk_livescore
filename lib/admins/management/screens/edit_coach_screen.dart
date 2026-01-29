import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/coach_model.dart';
import '../reusables/constants.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';

class EditCoachScreen extends StatefulWidget {
  final String coachId;

  const EditCoachScreen({
    super.key,
    required this.coachId,
  });

  @override
  State<EditCoachScreen> createState() => _EditCoachScreenState();
}

class _EditCoachScreenState extends State<EditCoachScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Coach? _coach;

  String? _selectedTeam;
  Uint8List? _webImageBytes;
  String? _photoUrl;
  DateTime? _selectedDateOfBirth;

  final Map<String, String> _teams = {}; // teamId -> name
  final List<String> _availableTeams = [];

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    _loadCoachAndTeams();
  }

  // ================= LOAD COACH + TEAMS =================
  Future<void> _loadCoachAndTeams() async {
    try {
      final coachDoc = await FirebaseFirestore.instance
          .collection('coaches')
          .doc(widget.coachId)
          .get();

      if (!coachDoc.exists) {
        throw Exception('Coach not found');
      }

      _coach = Coach.fromMap(coachDoc.data()!);
      _nameController.text = _coach!.name;
      _selectedTeam = _coach!.teamId;
      _photoUrl = _coach!.photoUrl;
      _selectedDateOfBirth = _coach!.dateOfBirth;

      final teamsSnap =
          await FirebaseFirestore.instance.collection('teams').get();

      _teams.clear();
      _availableTeams.clear();

      for (final doc in teamsSnap.docs) {
        final data = doc.data();
        final teamId = doc.id;
        final teamName = data['name'] as String;
        final coachId = data['coachId'] as String?;

        _teams[teamId] = teamName;

        // Allow current team OR teams without coach
        if (coachId == null || coachId == widget.coachId) {
          _availableTeams.add(teamId);
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to load coach: $e',
          type: DialogType.error,
        );
      }
    }
  }

  // ================= PICK IMAGE =================
  Future<void> _pickImage() async {
    final picked =
        await _picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (mounted) {
      setState(() => _webImageBytes = bytes);
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
      initialDate: _selectedDateOfBirth ?? DateTime(1980),
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
      // Upload image only if changed
      if (_webImageBytes != null) {
        _photoUrl = await _uploadImage();
      }

      final newTeamName =
          _selectedTeam != null ? _teams[_selectedTeam] : null;

      // Update coach
      await FirebaseFirestore.instance
          .collection('coaches')
          .doc(widget.coachId)
          .update({
        'name': _nameController.text.trim(),
        'teamId': _selectedTeam,
        'teamName': newTeamName,
        'photoUrl': _photoUrl,
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String(),
      });

      // Handle team reassignment
      if (_coach!.teamId != _selectedTeam) {
        if (_coach!.teamId != null) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(_coach!.teamId)
              .update({'coachId': null});
        }

        if (_selectedTeam != null) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(_selectedTeam)
              .update({'coachId': widget.coachId});
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
        CustomDialog.show(
          context,
          title: 'Success',
          message: 'Coach updated successfully!',
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
          message: 'Failed to update coach: $e',
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
        title:
            const Text('Edit Coach', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: Stack(
        children: [
          if (!_isLoading)
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
                              border:
                                  Border.all(color: Colors.grey),
                            ),
                            child: ClipOval(
                              child: _webImageBytes != null
                                  ? Image.memory(
                                      _webImageBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      _photoUrl!,
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
                                text:
                                    '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}',
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
                          child: const Text('Update'),
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
