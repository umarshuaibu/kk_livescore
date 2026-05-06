import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/coach_model.dart';
import '../services/player_service.dart';
import '../services/coach_service.dart';
import '../services/team_service.dart';
import '../reusables/custom_dialog.dart';
import '../reusables/custom_progress_indicator.dart';

class EditTeamPanel extends StatefulWidget {
  /// The team to edit
  final Team team;

  /// Called when edit is saved or panel is dismissed
  final VoidCallback onDone;

  const EditTeamPanel({
    super.key,
    required this.team,
    required this.onDone,
  });

  @override
  State<EditTeamPanel> createState() => _EditTeamPanelState();
}

class _EditTeamPanelState extends State<EditTeamPanel>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService();
  final CoachService _coachService = CoachService();

  late TextEditingController _nameController;
  late TextEditingController _abbrController;
  late TextEditingController _tmNameController;
  late TextEditingController _tmPhoneController;

  String? _selectedCoachId;
  List<String> _selectedPlayerIds = [];

  final List<Player> _availablePlayers = [];
  final List<Coach> _availableCoaches = [];
  final Set<String> _unassignedCoachIds = {};

  Uint8List? _imageBytes;         // newly picked image
  bool _logoHovered = false;
  bool _isPicking = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _fetchError = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing team
    _nameController =
        TextEditingController(text: widget.team.name);
    _abbrController =
        TextEditingController(text: widget.team.abbr ?? '');
    _tmNameController =
        TextEditingController(text: widget.team.tmName ?? '');
    _tmPhoneController =
        TextEditingController(text: widget.team.tmPhone ?? '');
    _selectedCoachId = widget.team.coachId;
    _selectedPlayerIds =
        List<String>.from(widget.team.players ?? []);

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

    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _tmNameController.dispose();
    _tmPhoneController.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── LOAD DATA ──
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _fetchError = false;
    });

    try {
      final players = await _playerService.fetchPlayers();
      final coaches = await _coachService.fetchCoaches();

      // Free players OR already in this team
      final teamPlayerIds =
          Set<String>.from(widget.team.players ?? []);
      final freePlayers = players.where((p) =>
          p.team == null ||
          p.team!.trim().isEmpty ||
          (p.teamId != null && p.teamId == widget.team.id)).toList();

      // Free coaches OR already coaching this team
      final freeCoachIds = coaches
          .where((c) =>
              c.teamId == null ||
              c.teamId!.trim().isEmpty ||
              c.teamId == widget.team.id)
          .map((c) => c.id)
          .toSet();

      setState(() {
        _availablePlayers
          ..clear()
          ..addAll(freePlayers);
        _availableCoaches
          ..clear()
          ..addAll(coaches);
        _unassignedCoachIds
          ..clear()
          ..addAll(freeCoachIds);
      });
    } catch (e) {
      debugPrint('[EditTeamPanel] load error: $e');
      setState(() => _fetchError = true);

      await CustomDialog.show(
        context,
        title: 'Load Error',
        message:
            'Unable to load players or coaches. Please check your connection.',
        type: DialogType.error,
        confirmText: 'Retry',
        onConfirm: _loadInitialData,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── PICK IMAGE ──
  Future<void> _pickImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final compressed = await _compressImage(bytes);

      if (compressed == null) {
        await CustomDialog.show(context,
            title: 'Image Error',
            message: 'Unable to process the selected image.',
            type: DialogType.error);
        return;
      }
      if (compressed.lengthInBytes > 200 * 1024) {
        await CustomDialog.show(context,
            title: 'Image Too Large',
            message: 'Please choose a smaller image.',
            type: DialogType.warning);
        return;
      }
      setState(() => _imageBytes = compressed);
    } catch (e) {
      debugPrint('[EditTeamPanel] pickImage error: $e');
      await CustomDialog.show(context,
          title: 'Pick Error',
          message: 'Failed to pick image.',
          type: DialogType.error);
    } finally {
      _isPicking = false;
    }
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 85,
        minHeight: 400,
        minWidth: 400,
      );
      return compressed.isNotEmpty ? compressed : null;
    } catch (e) {
      debugPrint('[EditTeamPanel] compress error: $e');
      return null;
    }
  }

  Future<String?> _uploadImage() async {
    try {
      if (_imageBytes == null) return null;
      final fileName =
          'teams/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putData(
          _imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[EditTeamPanel] upload error: $e');
      await CustomDialog.show(context,
          title: 'Upload Error',
          message: 'Failed to upload image.',
          type: DialogType.error);
      return null;
    }
  }

  // ── VALIDATE PHONE ──
  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final normalized =
        v.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^[\d\+\-]{6,20}$').hasMatch(normalized)) return null;
    return 'Please enter a valid phone number';
  }

  // ── SUBMIT ──
  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      // Upload new logo only if changed
      String? logoUrl = widget.team.logoUrl;
      if (_imageBytes != null) {
        final uploaded = await _uploadImage();
        if (uploaded != null) logoUrl = uploaded;
      }

      final updates = <String, dynamic>{
        'name': _nameController.text.trim(),
        'abbr': _abbrController.text.trim(),
        'coachId': _selectedCoachId,
        'logoUrl': logoUrl,
        'players': _selectedPlayerIds,
        'tmName': _tmNameController.text.trim().isNotEmpty
            ? _tmNameController.text.trim()
            : null,
        'tmPhone': _tmPhoneController.text.trim().isNotEmpty
            ? _tmPhoneController.text.trim()
            : null,
      };

      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.team.id)
          .update(updates);

      // Sync player teamId/team fields for newly added/removed players
      final oldIds =
          Set<String>.from(widget.team.players ?? []);
      final newIds = Set<String>.from(_selectedPlayerIds);

      // Players removed from team
      for (final pid in oldIds.difference(newIds)) {
        await _playerService.updatePlayerTeam(pid, '');
      }
      // Players added to team
      for (final pid in newIds.difference(oldIds)) {
        await _playerService.updatePlayerTeam(pid, widget.team.id);
      }

      // Sync coach assignment
      final oldCoachId = widget.team.coachId;
      if (oldCoachId != _selectedCoachId) {
        if (oldCoachId != null) {
          await _coachService.updateCoachTeam(oldCoachId, '');
        }
        if (_selectedCoachId != null &&
            _selectedCoachId!.isNotEmpty) {
          await _coachService.updateCoachTeam(
              _selectedCoachId!, widget.team.id);
        }
      }

      if (mounted) {
        CustomDialog.show(context,
            title: 'Updated',
            message: 'Team updated successfully!',
            type: DialogType.success,
            onConfirm: widget.onDone);
      }
    } catch (e) {
      debugPrint('[EditTeamPanel] submit error: $e');
      if (mounted) {
        CustomDialog.show(context,
            title: 'Error',
            message:
                'An error occurred while updating the team. Please try again.',
            type: DialogType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _dismiss() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth < 520 ? screenWidth : 460.0;

    return Stack(
      children: [
        // Backdrop
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _dismiss,
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
                          : _fetchError
                              ? _buildFetchError()
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
            child: Icon(Icons.shield_rounded,
                color: AppColors.primaryColor2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Team',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(widget.team.name,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _dismiss,
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

  Widget _buildFetchError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE57373).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFE57373), size: 26),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load data',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            SizedBox(
              height: 44,
              width: 140,
              child: ElevatedButton(
                onPressed: _loadInitialData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo picker
          Center(child: _buildLogoPicker()),
          const SizedBox(height: 22),

          // Name + Abbr
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildField(
                  controller: _nameController,
                  label: 'Team Name',
                  hint: 'e.g. Lagos Lions FC',
                  icon: Icons.shield_outlined,
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Please enter a team name'
                          : null,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: _buildField(
                  controller: _abbrController,
                  label: 'Abbr.',
                  hint: 'LLF',
                  icon: Icons.short_text_rounded,
                  validator: (v) =>
                      v == null || v.trim().isEmpty
                          ? 'Required'
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Coach
          _sectionLabel('Coach (optional)'),
          const SizedBox(height: 8),
          _buildCoachDropdown(),
          const SizedBox(height: 14),

          // Players
          _sectionLabel('Players (optional)'),
          const SizedBox(height: 8),
          _buildPlayersSelector(),
          const SizedBox(height: 14),

          // Manager name
          _buildField(
            controller: _tmNameController,
            label: 'Manager Name (optional)',
            hint: 'e.g. Emeka Obi',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),

          // Manager phone
          _buildField(
            controller: _tmPhoneController,
            label: 'Manager Phone (optional)',
            hint: '+234 800 000 0000',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _validatePhone,
          ),
          const SizedBox(height: 24),

          _buildSaveButton(),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: _dismiss,
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

  Widget _buildLogoPicker() {
    return MouseRegion(
      onEnter: (_) => setState(() => _logoHovered = true),
      onExit: (_) => setState(() => _logoHovered = false),
      child: GestureDetector(
        onTap: _pickImage,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _logoHovered
                  ? AppColors.primaryColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.09),
              width: 1.5,
            ),
            color: _logoHovered
                ? AppColors.primaryColor.withOpacity(0.08)
                : Colors.white.withOpacity(0.04),
          ),
          clipBehavior: Clip.antiAlias,
          child: _imageBytes != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_imageBytes!, fit: BoxFit.cover),
                    AnimatedOpacity(
                      opacity: _logoHovered ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                )
              : widget.team.logoUrl != null &&
                      widget.team.logoUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.team.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _emptyLogoPlaceholder()),
                        AnimatedOpacity(
                          opacity: _logoHovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    )
                  : _emptyLogoPlaceholder(),
        ),
      ),
    );
  }

  Widget _emptyLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: _logoHovered
                ? AppColors.primaryColor
                : Colors.grey.shade600,
            size: 24),
        const SizedBox(height: 5),
        Text('Logo',
            style: TextStyle(
                color: _logoHovered
                    ? AppColors.primaryColor
                    : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCoachDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _unassignedCoachIds.contains(_selectedCoachId)
              ? _selectedCoachId
              : null,
          dropdownColor: const Color(0xFF1E2330),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 18),
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.manage_accounts_outlined,
                color: Colors.grey.shade600, size: 17),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          hint: Text('Select a coach',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
          items: _availableCoaches.map((coach) {
            final enabled =
                _unassignedCoachIds.contains(coach.id);
            return DropdownMenuItem<String>(
              value: coach.id,
              enabled: enabled,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.4,
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
                    const SizedBox(width: 7),
                    Flexible(child: Text(coach.name)),
                    if (!enabled) ...[
                      const SizedBox(width: 4),
                      Text('Assigned',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null &&
                !_unassignedCoachIds.contains(value)) return;
            setState(() => _selectedCoachId = value);
          },
        ),
      ),
    );
  }

  Widget _buildPlayersSelector() {
    final count = _selectedPlayerIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                '$count player${count == 1 ? '' : 's'} selected',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryColor,
              surface: const Color(0xFF1E2330),
            ),
            chipTheme: ChipThemeData(
              backgroundColor:
                  AppColors.primaryColor.withOpacity(0.12),
              selectedColor:
                  AppColors.primaryColor.withOpacity(0.25),
              labelStyle: const TextStyle(
                  color: Colors.white, fontSize: 12),
            ),
          ),
          child: MultiSelectDialogField<Player>(
            items: _availablePlayers
                .map((p) => MultiSelectItem<Player>(p, p.name))
                .toList(),
            initialValue: _availablePlayers
                .where((p) =>
                    _selectedPlayerIds.contains(p.id))
                .toList(),
            title: const Text('Select Players',
                style: TextStyle(color: Colors.white)),
            searchable: true,
            listType: MultiSelectListType.CHIP,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08)),
            ),
            buttonIcon: Icon(Icons.people_alt_outlined,
                color: Colors.grey.shade600, size: 17),
            buttonText: Text(
              'Select players',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13),
            ),
            onConfirm: (values) {
              setState(() {
                _selectedPlayerIds =
                    values.map((p) => p.id).toList();
              });
            },
          ),
        ),
      ],
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
}