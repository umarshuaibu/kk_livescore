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

class CreateCoachPanel extends StatefulWidget {
  final VoidCallback onDone;

  const CreateCoachPanel({
    super.key,
    required this.onDone,
  });

  @override
  State<CreateCoachPanel> createState() => _CreateCoachPanelState();
}

class _CreateCoachPanelState extends State<CreateCoachPanel>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late AnimationController _slideCtrl;
late Animation<Offset> _slideAnim;
late Animation<double> _fadeAnim;

  String? _selectedTeam;
  Uint8List? _webImageBytes;
  XFile? _pickedFile;
  String? _photoUrl;
  DateTime? _selectedDateOfBirth;

  final Map<String, String> _teams = {};
  final List<String> _availableTeams = [];

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _imageHovered = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fetchTeams();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

        _slideCtrl = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 320),
);

_slideAnim = Tween<Offset>(
  begin: const Offset(1.0, 0.0),
  end: Offset.zero,
).animate(CurvedAnimation(
  parent: _slideCtrl,
  curve: Curves.easeOutCubic,
));

_fadeAnim = CurvedAnimation(
  parent: _slideCtrl,
  curve: Curves.easeOut,
);

_slideCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _slideCtrl.dispose();
    super.dispose();
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
        _fadeController.forward();
        _slideController.forward();
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

  // ================= PICK IMAGE =================
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
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
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryColor2,
              surface: const Color(0xFF1E2330),
            ),
            dialogBackgroundColor: const Color(0xFF161A23),
          ),
          child: child!,
        );
      },
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

    setState(() => _isSubmitting = true);

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
        setState(() => _isSubmitting = false);
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
        setState(() => _isSubmitting = false);
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to create coach: $e',
          type: DialogType.error,
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ================= BUILD =================
@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final panelWidth = screenWidth < 520 ? screenWidth : 420.0;

  return Stack(
    children: [
      // ===== BACKDROP =====
      FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: widget.onDone,
          child: Container(
            color: Colors.black.withOpacity(0.45),
          ),
        ),
      ),

      // ===== PANEL =====
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
            child: Column(
              children: [
                _buildHeader(context),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CustomProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          child: _buildForm(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ===== SUBMIT LOADING =====
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

  // ================= HEADER =================
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          _buildIconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.go('/admin_panel'),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add New Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fill in the details below to register a coach',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ================= FORM =================
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- PHOTO PICKER ----
          Center(child: _buildPhotoPicker()),

          const SizedBox(height: 28),

          // ---- NAME FIELD ----
          _buildSectionLabel('Coach Name'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _nameController,
            hint: 'e.g. Isah Bahago',
            icon: Icons.person_outline_rounded,
            validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
          ),

          const SizedBox(height: 20),

          // ---- TEAM DROPDOWN ----
          _buildSectionLabel('Assign Team'),
          const SizedBox(height: 8),
          _buildTeamDropdown(),

          const SizedBox(height: 20),

          // ---- DATE OF BIRTH ----
          _buildSectionLabel('Date of Birth'),
          const SizedBox(height: 8),
          _buildDatePicker(),

          const SizedBox(height: 32),

          // ---- SUBMIT ----
          _buildSubmitButton(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ================= PHOTO PICKER =================
  Widget _buildPhotoPicker() {
    return MouseRegion(
      onEnter: (_) => setState(() => _imageHovered = true),
      onExit: (_) => setState(() => _imageHovered = false),
      child: GestureDetector(
        onTap: _pickImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _imageHovered
                  ? AppColors.primaryColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.1),
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
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _imageHovered
                          ? AppColors.primaryColor
                          : Colors.grey.shade600,
                      size: 28,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        color: _imageHovered
                            ? AppColors.primaryColor
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ================= SECTION LABEL =================
  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ================= TEXT FIELD =================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon:
            Icon(icon, color: Colors.grey.shade600, size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.primaryColor.withOpacity(0.6)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE57373)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE57373)),
        ),
      ),
    );
  }

  // ================= TEAM DROPDOWN =================
  Widget _buildTeamDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedTeam,
          dropdownColor: const Color(0xFF1E2330),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.shield_outlined,
                color: Colors.grey.shade600, size: 18),
            border: InputBorder.none,
            hintStyle:
                TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          hint: Text(
            'Select a team (optional)',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
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
                      size: 14,
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
            if (_availableTeams.contains(v)) {
              setState(() => _selectedTeam = v);
            } else {
              CustomDialog.show(
                context,
                title: 'Restricted',
                message: 'Only teams without a coach can be selected.',
                type: DialogType.warning,
              );
            }
          },
        ),
      ),
    );
  }

  // ================= DATE PICKER =================
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: AbsorbPointer(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SUBMIT BUTTON =================
  Widget _buildSubmitButton() {
    return _isSubmitting
        ? const SizedBox.shrink()
        : SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Create Coach',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}