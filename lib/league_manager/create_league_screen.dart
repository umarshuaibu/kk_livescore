import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'package:kklivescoreadmin/league_manager/league_model.dart';

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({Key? key}) : super(key: key);

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen> {
  final _firestoreService = FirestoreService();

  int _currentStep = 0;

  // Step 1
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();
  String _logoUrl = '';

  // Step 2
  String _matchesSystem = 'Home_and_away';

  // Step 3
  String _teamsPairing = 'ManualPairing';

  // Step 4-5
  final TextEditingController _numTeamsController = TextEditingController();
  final TextEditingController _numGroupsController = TextEditingController();

  // Step 7 MatchDays: stored as "weekday|HH:mm"
  Map<int, List<TimeOfDay>> _selectedTimesByWeekday = {};
  List<String> get _matchDays {
    final list = <String>[];
    _selectedTimesByWeekday.forEach((weekday, times) {
      for (final t in times) {
        list.add('$weekday|${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      }
    });
    return list;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    _numTeamsController.dispose();
    _numGroupsController.dispose();
    super.dispose();
  }

bool _uploadingLogo = false;

Future<void> _pickAndUploadLogo() async {
  if (_uploadingLogo) return;

  _uploadingLogo = true;

  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    // User cancelled selection
    if (picked == null) return;

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      await _showAlert(
        title: 'Image Error',
        message: 'Unable to read the selected image.',
      );
      return;
    }

    // File size guard (300KB)
    if (bytes.lengthInBytes > 300 * 1024) {
      await _showAlert(
        title: 'Image Too Large',
        message: 'Please select an image smaller than 300KB.',
      );
      return;
    }

    final fileName =
        'league_logos/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';

    final ref = FirebaseStorage.instance.ref(fileName);

    try {
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } on FirebaseException {
      await _showAlert(
        title: 'Upload Failed',
        message: 'Unable to upload image. Please try again.',
      );
      return;
    }

    final url = await ref.getDownloadURL();

    if (!mounted) return;
    setState(() => _logoUrl = url);
  }

  // Permission / platform errors
  on PlatformException {
    await _showAlert(
      title: 'Permission Denied',
      message: 'Please allow access to your images.',
    );
  }

  // Absolute fallback
  catch (_) {
    await _showAlert(
      title: 'Unexpected Error',
      message: 'Something went wrong. Please try again.',
    );
  } finally {
    _uploadingLogo = false;
  }
}


  List<Step> _buildSteps() {
    // Fixed set of steps (no dynamic step counts)
    return [
      Step(
        title: const Text('League Info'),
        isActive: _currentStep >= 0,
        state: StepState.indexed,
        content: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'League Name')),
            TextField(controller: _seasonController, decoration: const InputDecoration(labelText: 'Season')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _logoUrl,
                    decoration: const InputDecoration(labelText: 'Logo URL'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _pickAndUploadLogo, child: const Text('Upload')),
              ],
            ),
          ],
        ),
      ),
      Step(
        title: const Text('Match System'),
        isActive: _currentStep >= 1,
        state: StepState.indexed,
        content: DropdownButtonFormField<String>(
          value: _matchesSystem,
          items: const [
            DropdownMenuItem(value: 'Home_and_away', child: Text('Home and away')),
            DropdownMenuItem(value: 'Away_only', child: Text('Away only')),
          ],
          onChanged: (v) => setState(() => _matchesSystem = v ?? _matchesSystem),
          decoration: const InputDecoration(labelText: 'Matches System'),
        ),
      ),
      Step(
        title: const Text('Teams Pairing'),
        isActive: _currentStep >= 2,
        state: StepState.indexed,
        content: DropdownButtonFormField<String>(
          value: _teamsPairing,
          items: const [
            DropdownMenuItem(value: 'ManualPairing', child: Text('Manual Pairing')),
            DropdownMenuItem(value: 'AutomatedPairing', child: Text('Automated Pairing')),
          ],
          onChanged: (v) => setState(() => _teamsPairing = v ?? _teamsPairing),
          decoration: const InputDecoration(labelText: 'Teams Pairing'),
        ),
      ),
      Step(
        title: const Text('Number of Teams'),
        isActive: _currentStep >= 3,
        state: StepState.indexed,
        content: TextField(
          controller: _numTeamsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'NumberOfTeams'),
        ),
      ),
      Step(
        title: const Text('Number of Groups'),
        isActive: _currentStep >= 4,
        state: StepState.indexed,
        content: TextField(
          controller: _numGroupsController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'NumberOfGroups'),
        ),
      ),
      Step(
        title: const Text('Match Days and Times'),
        isActive: _currentStep >= 5,
        state: StepState.indexed,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select weekdays and add times'),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final weekday = i + 1;
                final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final selected = _selectedTimesByWeekday.containsKey(weekday);
                return ChoiceChip(
                  label: Text(names[i]),
                  selected: selected,
                  onSelected: (sel) {
                    if (!sel) {
                      _selectedTimesByWeekday.remove(weekday);
                    } else {
                      _selectedTimesByWeekday[weekday] = _selectedTimesByWeekday[weekday] ?? [];
                    }
                    setState(() {});
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Column(
                children: _selectedTimesByWeekday.entries.map((e) {
              final weekday = e.key;
              final times = e.value;
              final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              return ListTile(
                title: Text(names[weekday - 1]),
                subtitle: Text(times.map((t) => '${t.format(context)}').join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _pickMatchDayTime(weekday),
                ),
              );
            }).toList()),
          ],
        ),
      ),
    ];
  }

  Future<void> _pickMatchDayTime(int weekday) async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (t == null) return;
    final list = _selectedTimesByWeekday[weekday] ?? [];
    list.add(t);
    _selectedTimesByWeekday[weekday] = list;
    setState(() {});
  }

  bool _validateBeforeProceed(int nextStep) {
    // Validate divisibility when trying to move past Number of Groups (index 4)
    if (_currentStep == 4) {
      final nt = int.tryParse(_numTeamsController.text) ?? 0;
      final ng = int.tryParse(_numGroupsController.text) ?? 0;
      if (ng == 0 || nt == 0 || nt % ng != 0) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Invalid'),
            content: const Text('Cannot divide number of teams into number of groups'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _submitAndCreateLeague() async {
    // Parse numeric fields
    final numberOfTeams = int.tryParse(_numTeamsController.text) ?? 0;
    final numberOfGroups = int.tryParse(_numGroupsController.text) ?? 0;

    final league = League(
      name: _nameController.text,
      season: _seasonController.text,
      logoUrl: _logoUrl,
      MatchesSystem: _matchesSystem,
      TeamsPairing: _teamsPairing,
      NumberOfTeams: numberOfTeams,
      NumberOfGroups: numberOfGroups,
      MatchDays: _matchDays,
      groupNames: List.generate(numberOfGroups, (i) => String.fromCharCode(65 + i)),
    );

    // Add mandatory status: "inactive"
    final data = league.toJson();
    data['status'] = 'inactive';

    await _firestoreService.createLeague(data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('League created (inactive)')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CREATE A NEW LEAGUE'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        child: Stepper(
          physics: const ClampingScrollPhysics(),
          currentStep: _currentStep,
          steps: steps,
          onStepContinue: () {
            final next = _currentStep + 1;
            if (next <= steps.length - 1) {
              if (_validateBeforeProceed(next)) {
                setState(() {
                  _currentStep = next;
                });
              }
            }
          },
          onStepCancel: () {
            if (_currentStep == 0) {
              Navigator.of(context).pop();
            } else {
              setState(() {
                _currentStep -= 1;
              });
            }
          },
          controlsBuilder: (context, details) {
            final isLast = _currentStep == steps.length - 1;
            return Row(
              children: [
                if (!isLast)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('NEXT'),
                  ),
                if (_currentStep > 0) const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(onPressed: details.onStepCancel, child: const Text('BACK')),
                if (isLast) const SizedBox(width: 8),
                if (isLast)
                  ElevatedButton(
                    onPressed: () async {
                      // Validate divisibility before final submit
                      final nt = int.tryParse(_numTeamsController.text) ?? 0;
                      final ng = int.tryParse(_numGroupsController.text) ?? 0;
                      if (ng == 0 || nt == 0 || nt % ng != 0) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Invalid'),
                            content: const Text('Cannot divide number of teams into number of groups'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                            ],
                          ),
                        );
                        return;
                      }
                      if (_matchDays.isEmpty) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Invalid'),
                            content: const Text('Please select at least one match day and time'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                            ],
                          ),
                        );
                        return;
                      }
                      await _submitAndCreateLeague();
                    },
                    child: const Text('CREATE NOW'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  // -- HELPERS -- 

 Future<void> _showAlert({
  required String title,
  required String message,
}) async {
  if (!mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

}