import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';
import 'package:kklivescoreadmin/constants/buttons.dart';

import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/coach_model.dart';
import '../services/team_service.dart';
import '../services/player_service.dart';
import '../services/coach_service.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
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

  final List<Player> _availablePlayers = [];
  final List<Coach> _availableCoaches = [];
  final Set<String> _unassignedCoachIds = {};

  Uint8List? _imageBytes;
  String? _logoUrl;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _loading = false;
  bool _fetchError = false;
  bool _isPicking = false;

  // Responsive breakpoints
  static const double kDesktopBreakpoint = 1100;
  static const double kTabletBreakpoint = 800;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _fetchError = false;
    });

    try {
      final players = await _playerService.fetchPlayers();
      final coaches = await _coachService.fetchCoaches();

      final freePlayers = players.where((p) => p.team == null || p.team!.trim().isEmpty).toList();
      final freeCoachIds = coaches.where((c) => c.teamId == null || c.teamId!.trim().isEmpty).map((c) => c.id).toSet();

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
      debugPrint('[_loadInitialData] failed: $e');
      setState(() {
        _fetchError = true;
      });

      await CustomDialog.show(
        context,
        title: 'Load Error',
        message: 'Unable to load players or coaches. Please check your connection.',
        type: DialogType.error,
        confirmText: 'Retry',
        onConfirm: _loadInitialData,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_isPicking) return;
    _isPicking = true;

    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      Uint8List bytes = await pickedFile.readAsBytes();
      final compressedBytes = await _compressImage(bytes);

      if (compressedBytes == null) {
        await CustomDialog.show(
          context,
          title: 'Image Error',
          message: 'Unable to process the selected image.',
          type: DialogType.error,
        );
        return;
      }

      if (compressedBytes.lengthInBytes > 200 * 1024) {
        await CustomDialog.show(
          context,
          title: 'Image Too Large',
          message: 'The selected image is too large. Please choose a smaller image.',
          type: DialogType.warning,
        );
        return;
      }

      setState(() => _imageBytes = compressedBytes);
    } catch (e) {
      debugPrint('[_pickImage] error: $e');
      await CustomDialog.show(
        context,
        title: 'Pick Error',
        message: 'Failed to pick image.',
        type: DialogType.error,
      );
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
      debugPrint('[_compressImage] error: $e');
      return null;
    }
  }

  Future<String?> _uploadImage() async {
    try {
      if (_imageBytes == null) return null;
      final fileName = 'teams/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[_uploadImage] error: $e');
      await CustomDialog.show(
        context,
        title: 'Upload Error',
        message: 'Failed to upload image.',
        type: DialogType.error,
      );
      return null;
    }
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final normalized = v.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (RegExp(r'^[\d\+\-]{6,20}$').hasMatch(normalized)) return null;
    return 'Please enter a valid phone number';
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_imageBytes == null) {
      await CustomDialog.show(
        context,
        title: 'Logo Required',
        message: 'Please select a team logo.',
        type: DialogType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      _logoUrl = await _uploadImage();
      if (_logoUrl == null) return;

      final team = Team(
        id: '',
        name: _nameController.text.trim(),
        abbr: _abbrController.text.trim(),
        coachId: _selectedCoachId,
        logoUrl: _logoUrl,
        players: List<String>.from(_selectedPlayerIds),
        tmName: _tmNameController.text.trim().isNotEmpty ? _tmNameController.text.trim() : null,
        tmPhone: _tmPhoneController.text.trim().isNotEmpty ? _tmPhoneController.text.trim() : null,
      );

      final newTeamId = await _teamService.addTeam(team);

      for (final playerId in _selectedPlayerIds) {
        await _playerService.updatePlayerTeam(playerId, newTeamId);
      }

      if (_selectedCoachId != null && _selectedCoachId!.isNotEmpty) {
        await _coachService.updateCoachTeam(_selectedCoachId!, newTeamId);
      }

      await CustomDialog.show(
        context,
        title: 'Success',
        message: 'Team created successfully!',
        type: DialogType.success,
        confirmText: 'OK',
        onConfirm: () {
          try {
            context.go('/admin_panel');
          } catch (_) {
            Navigator.of(context).maybePop();
          }
        },
      );
    } catch (e) {
      debugPrint('[_submitForm] error: $e');
      await CustomDialog.show(
        context,
        title: 'Error',
        message: 'An error occurred while creating the team. Please try again.',
        type: DialogType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
      title: const Text('Add New Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                      PrimaryButton(text: 'Retry', onPressed: _loadInitialData, width: 180),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  final contentMaxWidth = maxWidth > 700 ? 700.0 : maxWidth; // modern centered card width

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
                errorText: _imageBytes == null ? 'Please select a logo' : null,
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
          title: const Text('Select Players'),
          buttonText: const Text('Select Players'),
          searchable: true,
          listType: MultiSelectListType.CHIP,
          onConfirm: (values) {
            setState(() {
              _selectedPlayerIds = values.map((player) => player.id).toList();
            });
          },
        ),
        SizedBox(height: eqW(16)),
        if (_imageBytes != null)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(eqW(8)),
            decoration: BoxDecoration(color: kScaffoldColor, borderRadius: BorderRadius.circular(eqW(8))),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(eqW(8)),
                  child: Image.memory(_imageBytes!,
                      width: isDesktop ? 140 : 80,
                      height: isDesktop ? 140 : 80,
                      fit: BoxFit.cover),
                ),
                SizedBox(width: eqW(12)),
                Flexible(child: Text('Selected logo preview', style: kText12White)),
                SizedBox(width: eqW(8)),
                SecondaryButton(
                  text: 'Change',
                  onPressed: _pickImage,
                  width: 90,
                  height: eqW(40),
                ),
              ],
            ),
          ),
        SizedBox(height: eqW(24)),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: _loading ? 'Please wait...' : 'Submit',
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

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _tmNameController.dispose();
    _tmPhoneController.dispose();
    super.dispose();
  }
}
