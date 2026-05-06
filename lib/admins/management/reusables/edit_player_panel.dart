import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/player_model.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';

class EditPlayerPanel extends StatefulWidget {
  /// The player to edit
  final Player player;

  /// Called when edit is saved or panel is dismissed
  final VoidCallback onDone;

  const EditPlayerPanel({
    super.key,
    required this.player,
    required this.onDone,
  });

  @override
  State<EditPlayerPanel> createState() => _EditPlayerPanelState();
}

class _EditPlayerPanelState extends State<EditPlayerPanel>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _jerseyNoController;
  late TextEditingController _stateController;
  late TextEditingController _townController;
  late TextEditingController _dobController;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  double? _uploadProgress;
  bool _imageHovered = false;

  XFile? _pickedFile;
  File? _imageFile;
  Uint8List? _webImage;
  DateTime? _selectedDateOfBirth;
  String? _selectedPosition;
  String? _selectedTeamId;
  String? _selectedTeamName;

  final List<String> _positions = [
    'Goalkeeper',
    'Defender',
    'Midfielder',
    'Forward'
  ];
  final List<Map<String, String>> _teams = [];

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing player
    _nameController =
        TextEditingController(text: widget.player.name);
    _jerseyNoController =
        TextEditingController(text: widget.player.jerseyNo.toString());
    _stateController =
        TextEditingController(text: widget.player.state);
    _townController =
        TextEditingController(text: widget.player.town);
    _selectedDateOfBirth = widget.player.dateOfBirth;
    _selectedPosition = widget.player.position;
    _selectedTeamId = widget.player.teamId;
    _selectedTeamName = widget.player.team;
    _dobController = TextEditingController(
      text: _selectedDateOfBirth == null
          ? ''
          : '${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
              '${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
              '${_selectedDateOfBirth!.year}',
    );

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
    _jerseyNoController.dispose();
    _stateController.dispose();
    _townController.dispose();
    _dobController.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── FETCH TEAMS ──
  Future<void> _fetchTeams() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('teams').get();
      _teams.clear();
      for (final doc in snapshot.docs) {
        final name = (doc.data()['name'] ?? '') as String;
        _teams.add({'id': doc.id, 'name': name});
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

  // ── PERMISSIONS ──
  Future<bool> _requestPermission() async {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid) {
        final statuses = await [
          Permission.photos,
          Permission.storage,
          Permission.mediaLibrary
        ].request();
        return statuses.values.any((s) => s.isGranted);
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
    } catch (_) {}
    return false;
  }

  // ── PICK IMAGE ──
  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final granted = await _requestPermission();
    if (!granted) {
      CustomDialog.show(context,
          title: 'Permission Denied',
          message: 'Please allow photo access in settings.',
          type: DialogType.error);
      return;
    }
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      _pickedFile = picked;
      if (kIsWeb) {
        _webImage = await picked.readAsBytes();
      } else {
        _imageFile = await _compressImage(
            File(picked.path), maxBytes: 150 * 1024);
      }
      if (mounted) setState(() {});
    } catch (e) {
      CustomDialog.show(context,
          title: 'Image Error',
          message: 'Failed to pick/compress image: $e',
          type: DialogType.error);
    }
  }

  Future<File> _compressImage(File file,
      {required int maxBytes}) async {
    try {
      int quality = 85;
      File? compressed;
      while (quality >= 30) {
        final targetPath =
            '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_q$quality.jpg';
        compressed =
            (await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: quality,
          minWidth: 300,
          minHeight: 300,
        )) as File?;
        if (compressed == null) break;
        if (await compressed.length() <= maxBytes)
          return compressed;
        quality -= 15;
      }
    } catch (_) {}
    return file;
  }

  // ── UPLOAD IMAGE ──
  Future<String> _uploadImage() async {
    final ref = _storage.ref().child(
        'players/${DateTime.now().millisecondsSinceEpoch}.jpg');
    UploadTask uploadTask;
    if (kIsWeb && _webImage != null) {
      uploadTask = ref.putData(_webImage!);
    } else if (_imageFile != null) {
      uploadTask = ref.putFile(_imageFile!);
    } else {
      throw 'No image selected';
    }

    _uploadProgress = 0.0;
    uploadTask.snapshotEvents.listen((e) {
      if (!mounted) return;
      setState(() => _uploadProgress = e.totalBytes > 0
          ? e.bytesTransferred / e.totalBytes
          : null);
    });

    await uploadTask;
    final url = await ref.getDownloadURL();
    if (mounted) setState(() => _uploadProgress = null);
    return url;
  }

  // ── PICK DOB ──
  Future<void> _pickDateOfBirth() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1960),
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
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = picked;
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    });
  }

  // ── VALIDATE JERSEY ──
  String? _validateJersey(String? val) {
    if (val == null || val.trim().isEmpty)
      return 'Please enter a jersey number';
    final n = int.tryParse(val);
    if (n == null) return 'Please enter a valid number';
    if (n <= 0 || n > 99) return 'Jersey must be between 1 and 99';
    return null;
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
    if (_selectedPosition == null) {
      CustomDialog.show(context,
          title: 'Missing Position',
          message: 'Please select a position.',
          type: DialogType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload new photo only if changed
      String photoUrl = widget.player.playerPhoto;
      if (_pickedFile != null) photoUrl = await _uploadImage();

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'position': _selectedPosition!,
        'jerseyNo': int.parse(_jerseyNoController.text.trim()),
        'team': _selectedTeamName,
        'teamId': _selectedTeamId,
        'playerPhoto': photoUrl,
        'dateOfBirth': _selectedDateOfBirth!.toIso8601String(),
        'state': _stateController.text.trim(),
        'town': _townController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('players')
          .doc(widget.player.id)
          .update(updates);

      // Update team arrays if team changed
      if (widget.player.teamId != _selectedTeamId) {
        // Remove from old team
        if (widget.player.teamId != null) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(widget.player.teamId)
              .update({
            'players':
                FieldValue.arrayRemove([widget.player.id])
          });
        }
        // Add to new team
        if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('teams')
              .doc(_selectedTeamId)
              .update({
            'players': FieldValue.arrayUnion([widget.player.id])
          });
        }
      }

      if (mounted) {
        CustomDialog.show(context,
            title: 'Updated',
            message: 'Player updated successfully!',
            type: DialogType.success,
            onConfirm: widget.onDone);
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(context,
            title: 'Error',
            message: 'Failed to update player: $e',
            type: DialogType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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
                    if (_uploadProgress != null)
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor:
                            Colors.white.withOpacity(0.04),
                        color: AppColors.primaryColor,
                        minHeight: 3,
                      ),
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CustomProgressIndicator())
                          : SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(
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
            child: Icon(Icons.edit_rounded,
                color: AppColors.primaryColor2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Player',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(widget.player.name,
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
          Center(child: _buildPhotoPicker()),
          const SizedBox(height: 22),

          _buildField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'e.g. Umar Musa',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please enter name'
                : null,
          ),
          const SizedBox(height: 14),

          // Jersey + Position row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: _buildField(
                  controller: _jerseyNoController,
                  label: 'Jersey',
                  hint: '1–99',
                  icon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                  validator: _validateJersey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Position'),
                    const SizedBox(height: 8),
                    _buildDropdown<String>(
                      value: _selectedPosition,
                      hint: 'Select position',
                      icon: Icons.sports_soccer_rounded,
                      items: _positions
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p)))
                          .toList(),
                      validator: (v) => v == null
                          ? 'Please select a position'
                          : null,
                      onChanged: (v) =>
                          setState(() => _selectedPosition = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _sectionLabel('Team (optional)'),
          const SizedBox(height: 8),
          _buildDropdown<String>(
            value: _teams.any((t) => t['id'] == _selectedTeamId)
                ? _selectedTeamId
                : null,
            hint: 'Assign to a team',
            icon: Icons.shield_outlined,
            items: _teams
                .map((t) => DropdownMenuItem(
                    value: t['id'], child: Text(t['name'] ?? '')))
                .toList(),
            onChanged: (teamId) {
              final teamName = _teams
                  .firstWhere((t) => t['id'] == teamId,
                      orElse: () => {'name': ''})['name'];
              setState(() {
                _selectedTeamId = teamId;
                _selectedTeamName = teamName;
              });
            },
          ),
          const SizedBox(height: 14),

          _sectionLabel('Date of Birth'),
          const SizedBox(height: 8),
          _buildDateField(),
          const SizedBox(height: 14),

          // State + Town
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  controller: _stateController,
                  label: 'State',
                  hint: 'e.g. Kano',
                  icon: Icons.flag_outlined,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildField(
                  controller: _townController,
                  label: 'Town',
                  hint: 'e.g. Panshekara',
                  icon: Icons.location_city_outlined,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildSaveButton(),
          const SizedBox(height: 10),

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
          child: _pickedFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? Image.memory(_webImage!, fit: BoxFit.cover)
                        : Image.file(_imageFile!, fit: BoxFit.cover),
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
              : widget.player.playerPhoto.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.player.playerPhoto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _emptyPhotoPlaceholder()),
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
                  : _emptyPhotoPlaceholder(),
        ),
      ),
    );
  }

  Widget _emptyPhotoPlaceholder() {
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

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDateOfBirth,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dobController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          validator: (v) => _selectedDateOfBirth == null
              ? 'Please select date of birth'
              : null,
          decoration: InputDecoration(
            hintText: 'Select date of birth',
            hintStyle:
                TextStyle(color: Colors.grey.shade600, fontSize: 13),
            prefixIcon: Icon(Icons.calendar_today_rounded,
                color: Colors.grey.shade600, size: 17),
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade500, size: 18),
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
              borderSide:
                  const BorderSide(color: Color(0xFFE57373)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide:
                  const BorderSide(color: Color(0xFFE57373)),
            ),
          ),
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
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
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
              borderSide:
                  const BorderSide(color: Color(0xFFE57373)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide:
                  const BorderSide(color: Color(0xFFE57373)),
            ),
            errorStyle:
                const TextStyle(fontSize: 10, height: 1.2),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          dropdownColor: const Color(0xFF1E2330),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 18),
          isExpanded: true,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, color: Colors.grey.shade600, size: 17),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            errorStyle:
                const TextStyle(fontSize: 10, height: 1.2),
          ),
          hint: Text(hint,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}