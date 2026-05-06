import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';

import '../models/coach_model.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';

class EditCoachPanel extends StatefulWidget {
  /// The coach to edit
  final Coach coach;

  /// Called when edit is saved or panel is dismissed
  final VoidCallback onDone;

  const EditCoachPanel({
    super.key,
    required this.coach,
    required this.onDone,
  });

  @override
  State<EditCoachPanel> createState() => _EditCoachPanelState();
}

class _EditCoachPanelState extends State<EditCoachPanel>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  String? _selectedTeam;          // teamId
  Uint8List? _webImageBytes;      // new image picked
  DateTime? _selectedDateOfBirth;

  final Map<String, String> _teams = {};   // teamId -> teamName
  final List<String> _availableTeams = []; // teamIds without a coach

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _imageHovered = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing coach
    _nameController =
        TextEditingController(text: widget.coach.name);
    _selectedTeam = widget.coach.teamId;
    _selectedDateOfBirth = widget.coach.dateOfBirth;

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim =
        CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();

    _fetchTeams();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── FETCH TEAMS ──
  Future<void> _fetchTeams() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('teams').get();
      _teams.clear();
      _availableTeams.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final teamId = doc.id;
        final teamName = data['name'] as String? ?? teamId;
        _teams[teamId] = teamName;

        final coachId =
            data.containsKey('coachId') ? data['coachId'] as String? : null;
        // Available if no coach OR already assigned to THIS coach
        if (coachId == null || coachId == widget.coach.id) {
          _availableTeams.add(teamId);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(context,
            title: 'Error',
            message: 'Failed to fetch teams: $e',
            type: DialogType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PICK IMAGE ──
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _webImageBytes = bytes);
  }

  // ── UPLOAD IMAGE ──
  Future<String> _uploadImage() async {
    final ref = _storage
        .ref()
        .child('coaches/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putData(
        _webImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── PICK DOB ──
  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(1980),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
              primary: AppColors.primaryColor2,
              surface: const Color(0xFF1E2330)),
          dialogBackgroundColor: const Color(0xFF161A23),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  // ── SUBMIT ──
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateOfBirth == null) {
      CustomDialog.show(context,
          title: 'Missing Date',
          message: 'Please select date of birth.',
          type: DialogType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload new photo only if changed
      String? photoUrl = widget.coach.photoUrl;
      if (_webImageBytes != null) photoUrl = await _uploadImage();

      final teamName =
          _selectedTeam != null ? _teams[_selectedTeam] : null;

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'teamId': _selectedTeam,
        'teamName': teamName,
        'photoUrl': photoUrl,
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('coaches')
          .doc(widget.coach.id)
          .update(updates);

      // Update old team — remove coachId if team changed
      if (widget.coach.teamId != null &&
          widget.coach.teamId != _selectedTeam) {
        await FirebaseFirestore.instance
            .collection('teams')
            .doc(widget.coach.teamId)
            .update({'coachId': FieldValue.delete()});
      }

      // Assign coach to new team
      if (_selectedTeam != null) {
        await FirebaseFirestore.instance
            .collection('teams')
            .doc(_selectedTeam)
            .update({'coachId': widget.coach.id});
      }

      if (mounted) {
        CustomDialog.show(context,
            title: 'Updated',
            message: 'Coach updated successfully!',
            type: DialogType.success,
            onConfirm: widget.onDone);
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(context,
            title: 'Error',
            message: 'Failed to update coach: $e',
            type: DialogType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth < 520 ? screenWidth : 420.0;

    return Stack(
      children: [
        // Backdrop
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: widget.onDone,
            child:
                Container(color: Colors.black.withOpacity(0.45)),
          ),
        ),

        // Panel
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: panelWidth,
          child: SlideTransition(
            position: _slideAnim,
            child: Material(
              color: const Color(0xFF161A23),
              elevation: 16,
              shadowColor: Colors.black.withOpacity(0.5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CustomProgressIndicator())
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 20, 20, 32),
                              child: _buildForm(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Submitting overlay
        if (_isSubmitting)
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: panelWidth,
            child: Container(
              color: Colors.black.withOpacity(0.55),
              child: const Center(child: CustomProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 14,
        left: 20,
        right: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.manage_accounts_rounded,
                color: AppColors.primaryColor2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Coach',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(widget.coach.name,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Photo picker
          Center(child: _buildPhotoPicker()),
          const SizedBox(height: 22),

          // Name
          _buildField(
            controller: _nameController,
            label: 'Coach Name',
            hint: 'e.g. José Mourinho',
            icon: Icons.person_outline_rounded,
            validator: (v) =>
                v!.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),

          // Team dropdown
          _sectionLabel('Assign Team'),
          const SizedBox(height: 8),
          _buildTeamDropdown(),
          const SizedBox(height: 14),

          // Date of birth
          _sectionLabel('Date of Birth'),
          const SizedBox(height: 8),
          _buildDatePicker(),
          const SizedBox(height: 24),

          // Save
          _buildSaveButton(),
          const SizedBox(height: 10),

          // Cancel
          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07)),
              ),
              child: const Center(
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return MouseRegion(
      onEnter: (_) => setState(() => _imageHovered = true),
      onExit: (_) => setState(() => _imageHovered = false),
      child: GestureDetector(
        onTap: _pickImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _imageHovered
                  ? AppColors.primaryColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.09),
              width: 1.5,
            ),
            color: _imageHovered
                ? AppColors.primaryColor.withOpacity(0.08)
                : Colors.white.withOpacity(0.04),
          ),
          clipBehavior: Clip.antiAlias,
          child: _webImageBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_webImageBytes!, fit: BoxFit.cover),
                    AnimatedOpacity(
                      opacity: _imageHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                )
              : _buildNetworkOrEmpty(),
        ),
      ),
    );
  }

Widget _buildNetworkOrEmpty() {
  final photoUrl = widget.coach.photoUrl;

  if (photoUrl != null && photoUrl.isNotEmpty) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emptyPhotoIcon(),
        ),
        AnimatedOpacity(
          opacity: _imageHovered ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: const Icon(Icons.edit_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  return _emptyPhotoIcon();
}

  Widget _emptyPhotoIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: _imageHovered
                ? AppColors.primaryColor
                : Colors.grey.shade600,
            size: 24),
        const SizedBox(height: 5),
        Text('Photo',
            style: TextStyle(
                color: _imageHovered
                    ? AppColors.primaryColor
                    : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTeamDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _availableTeams.contains(_selectedTeam)
              ? _selectedTeam
              : null,
          dropdownColor: const Color(0xFF1E2330),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 18),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.shield_outlined,
                color: Colors.grey.shade600, size: 17),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: Text('Select a team (optional)',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
          items: _teams.entries.map((e) {
            final enabled = _availableTeams.contains(e.key);
            return DropdownMenuItem(
              value: e.key,
              enabled: enabled,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.35,
                child: Row(
                  children: [
                    Icon(
                      enabled
                          ? Icons.check_circle_outline_rounded
                          : Icons.block_rounded,
                      size: 13,
                      color: enabled
                          ? const Color(0xFF81C784)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (!_availableTeams.contains(v)) {
              CustomDialog.show(context,
                  title: 'Restricted',
                  message: 'Only teams without a coach can be selected.',
                  type: DialogType.warning);
              return;
            }
            setState(() => _selectedTeam = v);
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDateOfBirth == null
                    ? 'Select date of birth'
                    : _formatDate(_selectedDateOfBirth!),
                style: TextStyle(
                  color: _selectedDateOfBirth == null
                      ? Colors.grey.shade600
                      : Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          disabledBackgroundColor:
              AppColors.primaryColor.withOpacity(0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 17),
                  SizedBox(width: 8),
                  Text('Save Changes',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade600, fontSize: 13),
            prefixIcon:
                Icon(icon, color: Colors.grey.shade600, size: 17),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(
                  color: AppColors.primaryColor.withOpacity(0.55)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(
                  color: Color(0xFFE57373)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(
                  color: Color(0xFFE57373)),
            ),
          ),
        ),
      ],
    );
  }
}