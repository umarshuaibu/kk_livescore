import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/constants/buttons.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/coach_model.dart';
import '../services/team_service.dart';
import '../services/player_service.dart';
import '../services/coach_service.dart';
import '../reusables/custom_dialog.dart';

class EditTeamScreen extends StatefulWidget {
  final String teamId;

  const EditTeamScreen({super.key, required this.teamId});

  @override
  State<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends State<EditTeamScreen> {
  final _formKey = GlobalKey<FormState>();

  final TeamService _teamService = TeamService();
  final PlayerService _playerService = PlayerService();
  final CoachService _coachService = CoachService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _abbrController = TextEditingController();
  final TextEditingController _tmNameController = TextEditingController();
  final TextEditingController _tmPhoneController = TextEditingController();

  String? _selectedCoachId;
  List<String> _selectedPlayerIds = [];

  List<Player> _availablePlayers = [];
  List<Coach> _availableCoaches = [];
  Set<String> _unassignedCoachIds = {};

  Uint8List? _imageBytes;
  String? _logoUrl;

  bool _loading = true;
  bool _fetchError = false;
  bool _isPicking = false;

  Team? _team;

  static const double kDesktopBreakpoint = 1100;
  static const double kTabletBreakpoint = 800;

  @override
  void initState() {
    super.initState();
    _loadTeamAndData();
  }

String? _validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final cleaned = value.replaceAll(RegExp(r'[^\d+]'), '');
  if (cleaned.length < 6 || cleaned.length > 15) {
    return 'Enter a valid phone number';
  }
  return null;
}


  Future<void> _loadTeamAndData() async {
    setState(() {
      _loading = true;
      _fetchError = false;
    });

    try {
      _team = await _teamService.fetchTeamById(widget.teamId);
      if (_team == null) throw Exception('Team not found');

      final players = await _playerService.fetchPlayers();
      final coaches = await _coachService.fetchCoaches();

      /// -------------------------------
      /// SAFE COACH VALIDATION
      /// -------------------------------
      final coachExists = coaches.any((c) => c.id == _team!.coachId);
      if (!coachExists && _team!.coachId != null) {
        // 🔒 Clean stale coach reference silently
        await _teamService.editTeam(
          _team!.id,
          _team!.copyWith(coachId: null),
        );
        _team = _team!.copyWith(coachId: null);
      }

      final freePlayers =
          players.where((p) => p.team == null || p.team!.isEmpty).toList();

      final freeCoachIds = coaches
          .where((c) => c.teamId == null || c.teamId!.isEmpty)
          .map((c) => c.id)
          .toSet();

      _nameController.text = _team!.name;
      _abbrController.text = _team!.abbr ?? '';
      _tmNameController.text = _team!.tmName ?? '';
      _tmPhoneController.text = _team!.tmPhone ?? '';
      _selectedCoachId = _team!.coachId;
      _selectedPlayerIds = List<String>.from(_team!.players ?? []);
      _logoUrl = _team!.logoUrl;

      _availablePlayers = [
        ...freePlayers,
        ...players.where((p) => _selectedPlayerIds.contains(p.id))
      ];

      _availableCoaches = coaches;
      _unassignedCoachIds = {...freeCoachIds};

      if (_selectedCoachId != null) {
        _unassignedCoachIds.add(_selectedCoachId!);
      }
    } catch (e) {
      debugPrint('[EditTeam] load error: $e');
      setState(() => _fetchError = true);

      await CustomDialog.show(
        context,
        title: 'Load Error',
        message: 'Unable to load team data.',
        type: DialogType.error,
        confirmText: 'Retry',
        onConfirm: _loadTeamAndData,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- IMAGE PICK / UPLOAD (UNCHANGED) ----------------

  Future<void> _pickImage() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 85,
        minWidth: 400,
        minHeight: 400,
      );

      if (compressed.lengthInBytes > 200 * 1024) {
        await CustomDialog.show(
          context,
          title: 'Image Too Large',
          message: 'Please select a smaller image.',
          type: DialogType.warning,
        );
        return;
      }

      setState(() => _imageBytes = compressed);
    } finally {
      _isPicking = false;
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _logoUrl;

    final ref = FirebaseStorage.instance
        .ref('teams/${DateTime.now().millisecondsSinceEpoch}.jpg');

    await ref.putData(
      _imageBytes!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await ref.getDownloadURL();
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      _logoUrl = await _uploadImage();

      final updatedTeam = _team!.copyWith(
        name: _nameController.text.trim(),
        abbr: _abbrController.text.trim(),
        logoUrl: _logoUrl,
        coachId: _selectedCoachId,
        players: List<String>.from(_selectedPlayerIds),
        tmName: _tmNameController.text.trim().isEmpty
            ? null
            : _tmNameController.text.trim(),
        tmPhone: _tmPhoneController.text.trim().isEmpty
            ? null
            : _tmPhoneController.text.trim(),
      );

      await _teamService.editTeam(updatedTeam.id, updatedTeam);

      for (final p in _availablePlayers) {
        final assigned = _selectedPlayerIds.contains(p.id);
        if (assigned && p.team != updatedTeam.id) {
          await _playerService.updatePlayerTeam(p.id, updatedTeam.id);
        } else if (!assigned && p.team == updatedTeam.id) {
          await _playerService.updatePlayerTeam(p.id, null);
        }
      }

      if (_selectedCoachId != null && _selectedCoachId!.isNotEmpty) {
        await _coachService.updateCoachTeam(_selectedCoachId!, updatedTeam.id);
      }

      await CustomDialog.show(
        context,
        title: 'Success',
        message: 'Team updated successfully!',
        type: DialogType.success,
        onConfirm: () => context.go('/admin_panel'),
      );
    } catch (e) {
      await CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to update team.',
        type: DialogType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _tmNameController.dispose();
    _tmPhoneController.dispose();
    super.dispose();
  }

  // UI BUILD METHODS REMAIN UNCHANGED
  
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            try {
              context.push('/admin_panel');
            } catch (_) {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text('Edit Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhiteColor,
      ),
      backgroundColor: kGrey1,
      body: _loading && !_fetchError
          ? const Center(child: CircularProgressIndicator())
          : _fetchError
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(eqW(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unable to load data. Please check your connection and try again.',
                          style: kText12White,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: eqW(12)),
                        PrimaryButton(text: 'Retry', onPressed: _loadTeamAndData, width: 180),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final contentMaxWidth = maxWidth > 700 ? 700.0 : maxWidth;

                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(eqW(16)),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(eqW(16)),
                          ),
                          color: kWhiteColor,
                          child: Padding(
                            padding: EdgeInsets.all(eqW(24)),
                            child: Form(
                              key: _formKey,
                              child: _buildForm(contentMaxWidth),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildForm(double maxWidth) {
    final isDesktop = maxWidth >= kDesktopBreakpoint;
    final isTablet = maxWidth >= kTabletBreakpoint && maxWidth < kDesktopBreakpoint;

    Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Team Name'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Please enter a team name' : null,
        ),
        SizedBox(height: eqW(16)),
        TextFormField(
          controller: _abbrController,
          decoration: const InputDecoration(labelText: 'Abbreviation'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Please enter abbreviation' : null,
        ),
        SizedBox(height: eqW(16)),
        GestureDetector(
          onTap: _pickImage,
          child: AbsorbPointer(
            child: TextFormField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Team Logo',
                suffixIcon: const Icon(Icons.camera_alt),
                errorText: _logoUrl == null && _imageBytes == null ? 'Please select a logo' : null,
              ),
            ),
          ),
        ),
        SizedBox(height: eqW(16)),
        TextFormField(
          controller: _tmNameController,
          decoration: const InputDecoration(labelText: 'Team Manager Name (optional)'),
        ),
        SizedBox(height: eqW(16)),
        TextFormField(
          controller: _tmPhoneController,
          decoration: const InputDecoration(labelText: 'Team Manager Phone (optional)'),
          keyboardType: TextInputType.phone,
          validator: _validatePhone,
        ),
      ],
    );

    Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCoachId,
          hint: const Text('Select Coach (optional)'),
          items: _availableCoaches.map((coach) {
            final enabled = _unassignedCoachIds.contains(coach.id);
            return DropdownMenuItem<String>(
              value: coach.id,
              enabled: enabled,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(coach.name)),
                    if (!enabled) const Text('Assigned', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && !_unassignedCoachIds.contains(value)) return;
            setState(() => _selectedCoachId = value);
          },
        ),
        SizedBox(height: eqW(16)),
        MultiSelectDialogField<Player>(
          items: _availablePlayers.map((p) => MultiSelectItem<Player>(p, p.name)).toList(),
          initialValue: _availablePlayers.where((p) => _selectedPlayerIds.contains(p.id)).toList(),
          title: const Text('Select Players'),
          buttonText: const Text('Select Players'),
          searchable: true,
          listType: MultiSelectListType.CHIP,
          onConfirm: (values) {
            setState(() => _selectedPlayerIds = values.map((p) => p.id).toList());
          },
        ),
        SizedBox(height: eqW(16)),
if (_imageBytes != null || _logoUrl != null)
  Container(
    width: double.infinity,
    padding: EdgeInsets.all(eqW(8)),
    decoration: BoxDecoration(
      color: kScaffoldColor,
      borderRadius: BorderRadius.circular(eqW(8)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 400; // small width breakpoint
        return isSmall
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(eqW(8)),
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                          )
                        : _logoUrl != null
                            ? Image.network(
                                _logoUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox.shrink(),
                  ),
                  SizedBox(height: eqW(8)),
                  Text('Team logo preview', style: kText12White),
                  SizedBox(height: eqW(8)),
                  SecondaryButton(
                    text: 'Change',
                    onPressed: _pickImage,
                    width: 90,
                    height: eqW(40),
                  ),
                ],
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(eqW(8)),
                    child: _imageBytes != null
                        ? Image.memory(
                            _imageBytes!,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                          )
                        : _logoUrl != null
                            ? Image.network(
                                _logoUrl!,
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                              )
                            : const SizedBox.shrink(),
                  ),
                  SizedBox(width: eqW(12)),
                  Expanded(child: Text('Team logo preview', style: kText12White)),
                  SizedBox(width: eqW(8)),
                  SecondaryButton(
                    text: 'Change',
                    onPressed: _pickImage,
                    width: 90,
                    height: eqW(40),
                  ),
                ],
              );
      },
    ),
  ),

        SizedBox(height: eqW(24)),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: _loading ? 'Please wait...' : 'Update',
                onPressed: _loading ? () {} : _submitForm,
                height: eqW(48),
              ),
            ),
            SizedBox(width: eqW(12)),
            Expanded(
              child: SecondaryButton(
                text: 'Cancel',
                onPressed: () {
                  try {
                    context.push('/admin_panel');
                  } catch (_) {
                    Navigator.of(context).maybePop();
                  }
                },
                height: eqW(48),
              ),
            ),
          ],
        ),
      ],
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: leftColumn),
          SizedBox(width: eqW(24)),
          Expanded(flex: 2, child: rightColumn),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leftColumn,
          SizedBox(height: eqW(16)),
          rightColumn,
        ],
      );
    }
  }


  
}
