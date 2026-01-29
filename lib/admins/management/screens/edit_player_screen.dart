import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kklivescoreadmin/admins/management/models/player_model.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';
import 'package:kklivescoreadmin/admins/management/services/player_service.dart';
import 'package:kklivescoreadmin/constants/buttons.dart';

class EditPlayerScreen extends StatefulWidget {
  final String playerId;
  final VoidCallback onDone;

  const EditPlayerScreen({
    super.key,
    required this.playerId,
    required this.onDone,
  });

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final PlayerService _playerService = PlayerService();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _jerseyController;
  late TextEditingController _stateController;
  late TextEditingController _townController;
  late TextEditingController _dobController;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _initialized = false;

  Uint8List? _webImage;
  File? _imageFile;
  XFile? _pickedFile;

  DateTime? _selectedDob;
  String? _selectedPosition;
  String? _selectedTeamId;
  String? _selectedTeamName;

  late Player _player;

  final List<String> _positions = [
    'Goalkeeper',
    'Defender',
    'Midfielder',
    'Forward',
  ];

  final List<Map<String, String>> _teams = [];

      // ---------------- FETCH PLAYER ----------------
      Future<Player> _fetchPlayer() async {
        final doc = await FirebaseFirestore.instance
            .collection('players')
            .doc(widget.playerId)
            .get();

        if (!doc.exists) {
          throw Exception('Player not found');
        }

        final data = doc.data() as Map<String, dynamic>;

        return Player.fromMap(data, doc.id);
      }


  // ---------------- INIT FORM ----------------

  void _initForm(Player p) {
    if (_initialized) return;

    _player = p;

    _nameController = TextEditingController(text: p.name);
    _jerseyController =
        TextEditingController(text: p.jerseyNo.toString());
    _stateController = TextEditingController(text: p.state);
    _townController = TextEditingController(text: p.town);
    _dobController = TextEditingController(
      text:
          '${p.dateOfBirth.day.toString().padLeft(2, '0')}/${p.dateOfBirth.month.toString().padLeft(2, '0')}/${p.dateOfBirth.year}',
    );

    _selectedDob = p.dateOfBirth;
    _selectedPosition = p.position;
    _selectedTeamId = p.teamId;
    _selectedTeamName = p.team;

    _fetchTeams();
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyController.dispose();
    _stateController.dispose();
    _townController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ---------------- TEAMS ----------------

  Future<void> _fetchTeams() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('teams').get();

    _teams
      ..clear()
      ..addAll(snapshot.docs.map((doc) => {
            'id': doc.id,
            'name': doc['name'].toString(),
          }));

    if (mounted) setState(() {});
  }

  // ---------------- IMAGE ----------------

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    _pickedFile = picked;

    if (kIsWeb) {
      _webImage = await picked.readAsBytes();
    } else {
      _imageFile = File(picked.path);
    }

    setState(() {});
  }

  Future<String> _uploadImage() async {
    final ref =
        _storage.ref().child('players/${widget.playerId}.jpg');

    UploadTask task;

    if (kIsWeb && _webImage != null) {
      task = ref.putData(_webImage!);
    } else {
      task = ref.putFile(_imageFile!);
    }

    await task;
    return await ref.getDownloadURL();
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String photoUrl = _player.playerPhoto;

      if (_pickedFile != null) {
        photoUrl = await _uploadImage();
      }

      final updatedPlayer = _player.copyWith(
        name: _nameController.text.trim(),
        jerseyNo: int.parse(_jerseyController.text),
        state: _stateController.text.trim(),
        town: _townController.text.trim(),
        position: _selectedPosition!,
        teamId: _selectedTeamId,
        team: _selectedTeamName,
        playerPhoto: photoUrl,
        dateOfBirth: _selectedDob!,
      );

      await _playerService.updatePlayerWithTeam(
        updatedPlayer: updatedPlayer,
        previousTeamId: _player.teamId,
      );

      widget.onDone();
    } catch (e) {
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to update player: $e',
        type: DialogType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Player>(
      future: _fetchPlayer(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        final player = snapshot.data!;
        _initForm(player);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Player'),
            leading: BackButton(onPressed: widget.onDone),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 55,
                          backgroundImage: _pickedFile != null
                              ? (kIsWeb
                                      ? MemoryImage(_webImage!)
                                      : FileImage(_imageFile!))
                                  as ImageProvider
                              : NetworkImage(player.playerPhoto),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _jerseyController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Jersey'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedPosition,
                        items: _positions
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedPosition = v),
                        decoration:
                            const InputDecoration(labelText: 'Position'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        items: _teams
                            .map(
                              (t) => DropdownMenuItem(
                                value: t['id'],
                                child: Text(t['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          final team = _teams
                              .firstWhere((t) => t['id'] == id);
                          setState(() {
                            _selectedTeamId = id;
                            _selectedTeamName = team['name'];
                          });
                        },
                        decoration:
                            const InputDecoration(labelText: 'Team'),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: 'SAVE CHANGES',
                        onPressed: _isLoading ? () {} : _submit,
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }
}
