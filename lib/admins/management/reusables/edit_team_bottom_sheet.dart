import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart'; // ✅ NEW
import 'constants.dart'; // Adjust import path
import '../models/team_model.dart';
import '../models/player_model.dart';
import '../models/coach_model.dart';
import '../services/team_service.dart';
import '../services/player_service.dart';
import '../services/coach_service.dart';

class EditTeamBottomSheet extends StatefulWidget {
  final Team team;

  const EditTeamBottomSheet({super.key, required this.team});

  @override
  State<EditTeamBottomSheet> createState() => _EditTeamBottomSheetState();
}

class _EditTeamBottomSheetState extends State<EditTeamBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _teamService = TeamService();
  final _nameController = TextEditingController();
  final _abbrController = TextEditingController();
  String? _selectedCoachId;
  List<String> _selectedPlayerIds = [];
  File? _imageFile;
  String? _logoUrl;

  final List<Player> _availablePlayers = [];
  final List<Coach> _availableCoaches = [];
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PlayerService _playerService = PlayerService();
  final CoachService _coachService = CoachService();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.team.name;
    _abbrController.text = widget.team.abbr;
    _selectedCoachId = widget.team.coachId;
   _selectedPlayerIds = List<String>.from(widget.team.players).cast<String>();

    _logoUrl = widget.team.logoUrl;
    _fetchAvailablePlayers();
    _fetchAvailableCoaches();
  }

  Future<void> _fetchAvailablePlayers() async {
    final snapshot = await _playerService.fetchPlayers();
    setState(() {
      _availablePlayers.addAll(snapshot.where((player) =>
          player.team == null || player.team == widget.team.id));
    });
  }

  Future<void> _fetchAvailableCoaches() async {
    final snapshot = await _coachService.fetchCoaches();
     if (!mounted) return; // ✅ Prevent setState after dispose
    setState(() {
      _availableCoaches.addAll(snapshot); // Include all coaches
      // Filter only unassigned coaches or coaches assigned to this team
    });
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.isGranted ||
          await Permission.photos.isGranted ||
          await Permission.mediaLibrary.isGranted) {
        return true;
      }

      if (await Permission.storage.request().isGranted) return true;

      // For Android 13+
      if (await Permission.photos.request().isGranted) return true;
      if (await Permission.mediaLibrary.request().isGranted) return true;

      return false;
    } else if (Platform.isIOS) {
      return await Permission.photos.request().isGranted;
    }
    return false;
  }

  Future<void> _pickImage() async {
    if (await _requestPermission()) {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final compressedFile = await _compressImage(File(pickedFile.path));
        if (mounted) {
          setState(() {
             if (!mounted) return; // ✅ Prevent setState after dispose
            _imageFile = compressedFile;
          });
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied for image access')),
      );
    }
  }

  Future<File> _compressImage(File file) async {
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.parent.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      quality: 85,
      minHeight: 300,
      minWidth: 300,
    );
    if (compressed != null) {
      final sizeInBytes = await compressed.length();
      if (sizeInBytes > 150 * 1024) {
        throw Exception('Image size exceeds 150KB after compression');
      }
      return File(compressed.path);
    }
    return file;
  }

  Future<String> _uploadImage(File image) async {
    final ref = _storage
        .ref()
        .child('teams/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      try {
        String newLogoUrl = _logoUrl ?? '';

        // ✅ Upload new logo only if a new file was picked
        if (_imageFile != null) {
          newLogoUrl = await _uploadImage(_imageFile!);
        }

        // ✅ Track old vs new players
        final oldPlayerIds = List<String>.from(widget.team.players);
        final newPlayerIds = List<String>.from(_selectedPlayerIds);

        // Players added
        final addedPlayers =
            newPlayerIds.where((id) => !oldPlayerIds.contains(id)).toList();

        // Players removed
        final removedPlayers =
            oldPlayerIds.where((id) => !newPlayerIds.contains(id)).toList();

        // ✅ Update Firestore for added players
        for (final playerId in addedPlayers) {
          await _playerService.updatePlayerTeam(playerId, widget.team.id);
        }

        // ✅ Update Firestore for removed players (clear team)
        for (final playerId in removedPlayers) {
          await _playerService.updatePlayerTeam(playerId, null);
        }

// ✅ Handle coach reassignment
        final oldCoachId = widget.team.coachId;
        final newCoachId = _selectedCoachId;

        if (oldCoachId != newCoachId) {
          // Clear old coach assignment
          if (oldCoachId != null && oldCoachId.isNotEmpty) {
            await _coachService.updateCoach(oldCoachId, {
              'teamId': null,
              'teamName': null,
            });
          }

          // Assign new coach
          if (newCoachId != null && newCoachId.isNotEmpty) {
            await _coachService.updateCoach(newCoachId, {
              'teamId': widget.team.id,
              'teamName': _nameController.text,
            });
          }
        }

        final updatedTeam = Team(
          id: widget.team.id,
          name: _nameController.text,
          abbr: _abbrController.text,
          coachId: _selectedCoachId,
          logoUrl: newLogoUrl.isNotEmpty ? newLogoUrl : null,
          players: newPlayerIds,
        );

        await _teamService.editTeam(widget.team.id, updatedTeam);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Team updated successfully')),
          );
          Navigator.pop(context); // ✅ Close only after success
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating team: $e')),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  'Edit Team',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _abbrController,
                  decoration: const InputDecoration(labelText: 'Abbreviation'),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter an abbreviation' : null,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickImage,
                  child: AbsorbPointer(
                    child: TextFormField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Team Logo',
                        suffixIcon: const Icon(Icons.camera_alt),
                        errorText: _imageFile == null &&
                                (widget.team.logoUrl == null ||
                                    widget.team.logoUrl!.isEmpty)
                            ? 'Please select a logo'
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedCoachId,
                  hint: const Text('Select Coach'),
                  items: _availableCoaches.map((coach) {
                    final isCurrentCoach = coach.id == widget.team.coachId;

                    return DropdownMenuItem<String>(
                      value: coach.id,
                      enabled: coach.teamId == null  || isCurrentCoach, // ✅ allow current coach, // Only coaches with null teamId are clickable
                      child: Opacity(
                        opacity: coach.teamId == null || isCurrentCoach ? 1.0 : 0.5, // Full opacity for clickable, low opacity for non-clickable
                        child: Text(coach.name),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCoachId = value;
                      });
                    }
                  },
                  validator: (value) => null, // coachId is nullable, no validation required
                ),
                const SizedBox(height: 20),

                /// ✅ Multi-select for players
                MultiSelectDialogField<Player>(
              items: _availablePlayers
                  .map((player) => MultiSelectItem<Player>(player, player.name))
                  .toList(),
              title: const Text("Select Players"),
              buttonText: const Text("Select Players"),
              searchable: true,
              listType: MultiSelectListType.LIST,
              initialValue:
              _availablePlayers.where((p) => _selectedPlayerIds.contains(p.id)).toList(),

              onConfirm: (values) {
                setState(() {
                _selectedPlayerIds =  values.map((player) => player.id).toList(); // can be empty

    });
  },

  // ✅ No validation — players can be empty
  validator: (values) => null,
),


                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    super.dispose();
  }
}

// Helper function to show the bottom sheet
void showEditTeamBottomSheet(BuildContext context, Team team) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => EditTeamBottomSheet(team: team),
  );
}