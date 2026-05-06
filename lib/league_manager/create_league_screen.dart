import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'package:kklivescoreadmin/league_manager/league_model.dart';

// ── Design tokens ──
const _kBg = Color(0xFF0F1117);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBorder = Color(0xFF252B38);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kBlue = Color(0xFF4FC3F7);
const _kRed = Color(0xFFE57373);
const _kPurple = Color(0xFFBA68C8);

// ── Step metadata ──
const _stepTitles = [
  'League Info',
  'Match System',
  'Teams Pairing',
  'Teams & Groups',
  'Match Days',
];
const _stepIcons = [
  Icons.emoji_events_rounded,
  Icons.sports_soccer_rounded,
  Icons.people_rounded,
  Icons.grid_view_rounded,
  Icons.calendar_today_rounded,
];
const _stepColors = [_kAmber, _kBlue, _kPurple, _kGreen, _kAmber];

class CreateLeagueScreen extends StatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  State<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends State<CreateLeagueScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();

  int _currentStep = 0;

  // Step 1 — League Info
  final _nameController = TextEditingController();
  final _seasonController = TextEditingController();
  String _logoUrl = '';
  bool _uploadingLogo = false;
  bool _logoHovered = false;

  // Step 2 — Match System
  String _matchesSystem = 'Home_and_away';

  // Step 3 — Teams Pairing
  String _teamsPairing = 'ManualPairing';

  // Step 4 — Teams & Groups
  final _numTeamsController = TextEditingController();
  final _numGroupsController = TextEditingController();

  // Step 5 — Match Days: stored as "weekday|HH:mm"
  final Map<int, List<TimeOfDay>> _selectedTimesByWeekday = {};

  List<String> get _matchDays {
    final list = <String>[];
    _selectedTimesByWeekday.forEach((weekday, times) {
      for (final t in times) {
        list.add(
            '$weekday|${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      }
    });
    return list;
  }

  bool _isSubmitting = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    _numTeamsController.dispose();
    _numGroupsController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //   ORIGINAL LOGIC — UNTOUCHED
  // ════════════════════════════════════════

  Future<void> _pickAndUploadLogo() async {
    if (_uploadingLogo) return;
    setState(() => _uploadingLogo = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      Uint8List bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {
        await _showAlert(
            title: 'Image Error',
            message: 'Unable to read the selected image.');
        return;
      }

      if (bytes.lengthInBytes > 300 * 1024) {
        await _showAlert(
            title: 'Image Too Large',
            message: 'Please select an image smaller than 300KB.');
        return;
      }

      final fileName =
          'league_logos/${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final ref = FirebaseStorage.instance.ref(fileName);

      try {
        await ref.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } on FirebaseException {
        await _showAlert(
            title: 'Upload Failed',
            message: 'Unable to upload image. Please try again.');
        return;
      }

      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() => _logoUrl = url);
    } on PlatformException {
      await _showAlert(
          title: 'Permission Denied',
          message: 'Please allow access to your images.');
    } catch (_) {
      await _showAlert(
          title: 'Unexpected Error',
          message: 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _pickMatchDayTime(int weekday) async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
              primary: AppColors.primaryColor2,
              surface: _kSurface2),
          dialogBackgroundColor: _kSurface,
        ),
        child: child!,
      ),
    );
    if (t == null) return;
    final list = _selectedTimesByWeekday[weekday] ?? [];
    list.add(t);
    _selectedTimesByWeekday[weekday] = list;
    setState(() {});
  }

  bool _validateBeforeProceed(int nextStep) {
    if (_matchesSystem != 'Knockout' && _currentStep == 3) {
      final nt = int.tryParse(_numTeamsController.text) ?? 0;
      final ng = int.tryParse(_numGroupsController.text) ?? 0;
      if (ng == 0 || nt == 0 || nt % ng != 0) {
        _showValidationError(
            'Cannot divide $nt teams into $ng groups evenly.');
        return false;
      }
    }
    return true;
  }

  Future<void> _submitAndCreateLeague() async {
    final nt = int.tryParse(_numTeamsController.text) ?? 0;
    final ng = _matchesSystem == 'Knockout'
        ? 1
        : int.tryParse(_numGroupsController.text) ?? 0;

    if (_matchesSystem != 'Knockout' &&
        (ng == 0 || nt == 0 || nt % ng != 0)) {
      _showValidationError(
          'Cannot divide $nt teams into $ng groups evenly.');
      return;
    }

    if (_matchDays.isEmpty) {
      _showValidationError(
          'Please select at least one match day and time.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final league = League(
        name: _nameController.text.trim(),
        season: _seasonController.text.trim(),
        logoUrl: _logoUrl,
        MatchesSystem: _matchesSystem,
        TeamsPairing: _teamsPairing,
        NumberOfTeams: nt,
        NumberOfGroups: ng,
        MatchDays: _matchDays,
        groupNames: List.generate(
            ng, (i) => String.fromCharCode(65 + i)),
      );

      final data = league.toJson();
      data['status'] = 'inactive';
      await _firestoreService.createLeague(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('League created successfully'),
        backgroundColor: _kGreen.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showValidationError('Failed to create league: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showAlert(
      {required String title, required String message}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DarkDialog(
        title: title,
        message: message,
        icon: Icons.warning_amber_rounded,
        iconColor: _kAmber,
      ),
    );
  }

  void _showValidationError(String message) {
    showDialog(
      context: context,
      builder: (_) => _DarkDialog(
        title: 'Invalid',
        message: message,
        icon: Icons.error_outline_rounded,
        iconColor: _kRed,
      ),
    );
  }

  // ════════════════════════════════════════
  //   BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                children: [
                  // Step sidebar (desktop)
                  if (MediaQuery.of(context).size.width >= 700)
                    _buildStepSidebar(),

                  // Content
                  Expanded(
                    child: Column(
                      children: [
                        // Mobile step indicator
                        if (MediaQuery.of(context).size.width < 700)
                          _buildMobileStepIndicator(),

                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 560),
                                child: _buildCurrentStepContent(),
                              ),
                            ),
                          ),
                        ),

                        // Navigation buttons
                        _buildNavButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          _iconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create League',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                SizedBox(height: 2),
                Text('Follow the steps to set up your league',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          // Progress indicator
          _buildProgressChip(),
        ],
      ),
    );
  }

  Widget _buildProgressChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Text(
        'Step ${_currentStep + 1} of ${_stepTitles.length}',
        style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── DESKTOP STEP SIDEBAR ──
  Widget _buildStepSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STEPS',
              style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...List.generate(_stepTitles.length, (i) {
            final isDone = i < _currentStep;
            final isActive = i == _currentStep;
            final color = _stepColors[i];

            return GestureDetector(
              onTap: i < _currentStep
                  ? () => setState(() => _currentStep = i)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(color: color.withOpacity(0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _kGreen.withOpacity(0.15)
                            : isActive
                                ? color.withOpacity(0.15)
                                : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDone
                              ? _kGreen.withOpacity(0.4)
                              : isActive
                                  ? color.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                                color: _kGreen, size: 14)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: isActive
                                        ? color
                                        : Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _stepTitles[i],
                        style: TextStyle(
                          color: isDone
                              ? Colors.white60
                              : isActive
                                  ? Colors.white
                                  : Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const Spacer(),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${((_currentStep + 1) / _stepTitles.length * 100).round()}% complete',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _stepTitles.length,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  color: AppColors.primaryColor,
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── MOBILE STEP INDICATOR ──
  Widget _buildMobileStepIndicator() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_stepIcons[_currentStep],
                  color: _stepColors[_currentStep], size: 16),
              const SizedBox(width: 8),
              Text(_stepTitles[_currentStep],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _stepTitles.length,
              backgroundColor: Colors.white.withOpacity(0.07),
              color: AppColors.primaryColor,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── STEP CONTENT ROUTER ──
  Widget _buildCurrentStepContent() {
    Widget child;
    switch (_currentStep) {
      case 0:
        child = _buildStep0();
        break;
      case 1:
        child = _buildStep1();
        break;
      case 2:
        child = _buildStep2();
        break;
      case 3:
        child = _buildStep3();
        break;
      case 4:
        child = _buildStep4();
        break;
      default:
        child = const SizedBox.shrink();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: KeyedSubtree(
        key: ValueKey(_currentStep),
        child: child,
      ),
    );
  }

  // ════════════════════ STEP 0: LEAGUE INFO ════════════════════
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading('League Info', _stepIcons[0], _stepColors[0]),
        const SizedBox(height: 24),

        // Logo picker
        Center(child: _buildLogoPicker()),
        const SizedBox(height: 24),

        _buildField(
          controller: _nameController,
          label: 'League Name',
          hint: 'e.g. Rahama Super League',
          icon: Icons.emoji_events_outlined,
        ),
        const SizedBox(height: 14),

        _buildField(
          controller: _seasonController,
          label: 'Season',
          hint: 'e.g. 2025/2026',
          icon: Icons.date_range_outlined,
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return MouseRegion(
      onEnter: (_) => setState(() => _logoHovered = true),
      onExit: (_) => setState(() => _logoHovered = false),
      child: GestureDetector(
        onTap: _uploadingLogo ? null : _pickAndUploadLogo,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _logoHovered || _logoUrl.isNotEmpty
                  ? AppColors.primaryColor.withOpacity(0.55)
                  : Colors.white.withOpacity(0.09),
              width: 1.5,
            ),
            color: _logoHovered
                ? AppColors.primaryColor.withOpacity(0.08)
                : Colors.white.withOpacity(0.04),
          ),
          clipBehavior: Clip.antiAlias,
          child: _uploadingLogo
              ? Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryColor),
                )
              : _logoUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(_logoUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _emptyLogoWidget()),
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
                  : _emptyLogoWidget(),
        ),
      ),
    );
  }

  Widget _emptyLogoWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: _logoHovered
                ? AppColors.primaryColor
                : Colors.grey.shade600,
            size: 26),
        const SizedBox(height: 6),
        Text('League Logo',
            style: TextStyle(
                color: _logoHovered
                    ? AppColors.primaryColor
                    : Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ════════════════════ STEP 1: MATCH SYSTEM ════════════════════
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
            'Match System', _stepIcons[1], _stepColors[1]),
        const SizedBox(height: 8),
        Text('How matches will be played in this league',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 24),
        ...[
          _MatchSystemOption(
            value: 'Home_and_away',
            label: 'Home & Away',
            subtitle: 'Each team plays at home and away',
            icon: Icons.swap_horiz_rounded,
            color: _kBlue,
          ),
          _MatchSystemOption(
            value: 'Away_only',
            label: 'Away Only',
            subtitle: 'Single leg matches only',
            icon: Icons.arrow_forward_rounded,
            color: _kPurple,
          ),
          _MatchSystemOption(
            value: 'Knockout',
            label: 'Knockout',
            subtitle: 'Single elimination tournament',
            icon: Icons.sports_rounded,
            color: _kRed,
          ),
        ].map((opt) => _buildMatchSystemCard(opt)),
      ],
    );
  }

  Widget _buildMatchSystemCard(_MatchSystemOption opt) {
    final isSelected = _matchesSystem == opt.value;
    return GestureDetector(
      onTap: () => setState(() => _matchesSystem = opt.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? opt.color.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? opt.color.withOpacity(0.4)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: opt.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(opt.icon, color: opt.color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.label,
                      style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(opt.subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? opt.color
                    : Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: isSelected
                      ? opt.color
                      : Colors.white.withOpacity(0.15),
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════ STEP 2: TEAMS PAIRING ════════════════════
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
            'Teams Pairing', _stepIcons[2], _stepColors[2]),
        const SizedBox(height: 8),
        Text('How teams will be paired for matches',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 24),
        ...[
          _PairingOption(
            value: 'ManualPairing',
            label: 'Manual Pairing',
            subtitle:
                'Admin manually selects match pairings',
            icon: Icons.edit_rounded,
            color: _kPurple,
          ),
          _PairingOption(
            value: 'AutomatedPairing',
            label: 'Automated Pairing',
            subtitle: 'System automatically generates fixtures',
            icon: Icons.auto_awesome_rounded,
            color: _kBlue,
          ),
        ].map((opt) {
          final isSelected = _teamsPairing == opt.value;
          return GestureDetector(
            onTap: () =>
                setState(() => _teamsPairing = opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? opt.color.withOpacity(0.1)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? opt.color.withOpacity(0.4)
                      : Colors.white.withOpacity(0.07),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: opt.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(opt.icon,
                        color: opt.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(opt.label,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(opt.subtitle,
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? opt.color
                          : Colors.white.withOpacity(0.08),
                      border: Border.all(
                        color: isSelected
                            ? opt.color
                            : Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 12)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════ STEP 3: TEAMS & GROUPS ════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
            'Teams & Groups', _stepIcons[3], _stepColors[3]),
        const SizedBox(height: 8),
        Text('Configure how many teams and groups',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 24),

        _buildField(
          controller: _numTeamsController,
          label: 'Number of Teams',
          hint: 'e.g. 16',
          icon: Icons.people_alt_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),

        if (_matchesSystem == 'Knockout')
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kAmber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _kAmber.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _kAmber, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Knockout competitions do not use groups.',
                    style: TextStyle(
                        color: _kAmber.withOpacity(0.9),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          _buildField(
            controller: _numGroupsController,
            label: 'Number of Groups',
            hint: 'e.g. 4',
            icon: Icons.grid_view_outlined,
            keyboardType: TextInputType.number,
          ),

        const SizedBox(height: 16),

        // Live divisibility check
        if (_matchesSystem != 'Knockout')
          ValueListenableBuilder(
            valueListenable: _numTeamsController,
            builder: (_, __, ___) {
              return ValueListenableBuilder(
                valueListenable: _numGroupsController,
                builder: (_, __, ___) {
                  final nt = int.tryParse(
                          _numTeamsController.text) ??
                      0;
                  final ng = int.tryParse(
                          _numGroupsController.text) ??
                      0;
                  if (nt == 0 || ng == 0) {
                    return const SizedBox.shrink();
                  }

                  final valid = nt % ng == 0;
                  final color = valid ? _kGreen : _kRed;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          valid
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: color,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          valid
                              ? '${nt ~/ ng} teams per group ✓'
                              : '$nt ÷ $ng groups is not divisible',
                          style: TextStyle(
                              color: color, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ════════════════════ STEP 4: MATCH DAYS ════════════════════
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeading(
            'Match Days & Times', _stepIcons[4], _stepColors[4]),
        const SizedBox(height: 8),
        Text('Select which days and times matches will be played',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 24),

        // Weekday chips
        _sectionLabel('Select Weekdays'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            final weekday = i + 1;
            final selected =
                _selectedTimesByWeekday.containsKey(weekday);
            return _WeekdayChip(
              label: _weekdayNames[i],
              isSelected: selected,
              onTap: () {
                if (!selected) {
                  _selectedTimesByWeekday[weekday] = [];
                } else {
                  _selectedTimesByWeekday.remove(weekday);
                }
                setState(() {});
              },
            );
          }),
        ),

        const SizedBox(height: 20),

        // Selected days with times
        if (_selectedTimesByWeekday.isNotEmpty) ...[
          _sectionLabel('Match Times'),
          const SizedBox(height: 10),
          ..._selectedTimesByWeekday.entries.map((e) {
            final weekday = e.key;
            final times = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.07)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor
                              .withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primaryColor2
                                  .withOpacity(0.3)),
                        ),
                        child: Text(_weekdayNames[weekday - 1],
                            style: TextStyle(
                                color: AppColors.primaryColor2,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            _pickMatchDayTime(weekday),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kGreen.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    _kGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add_rounded,
                                  color: _kGreen, size: 14),
                              SizedBox(width: 4),
                              Text('Add Time',
                                  style: TextStyle(
                                      color: _kGreen,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (times.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: times.asMap().entries.map((te) {
                        final idx = te.key;
                        final t = te.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white
                                    .withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 5),
                              Text(
                                t.format(context),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  times.removeAt(idx);
                                  _selectedTimesByWeekday[
                                      weekday] = times;
                                  setState(() {});
                                },
                                child: Icon(Icons.close_rounded,
                                    size: 13,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('No times added yet',
                          style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 11)),
                    ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── NAVIGATION BUTTONS ──
  Widget _buildNavButtons() {
    final isLast = _currentStep == _stepTitles.length - 1;
    final isFirst = _currentStep == 0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          // Back / Cancel
          GestureDetector(
            onTap: () {
              if (isFirst) {
                Navigator.of(context).pop();
              } else {
                setState(() => _currentStep -= 1);
              }
            },
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: Center(
                child: Text(
                  isFirst ? 'Cancel' : 'Back',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Next / Create
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (isLast) {
                          _submitAndCreateLeague();
                        } else {
                          final next = _currentStep + 1;
                          if (_validateBeforeProceed(next)) {
                            setState(() => _currentStep = next);
                          }
                        }
                      },
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
                            strokeWidth: 2,
                            color: Colors.white))
                    : Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            isLast ? 'Create League' : 'Next',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SHARED UI HELPERS ──
  Widget _stepHeading(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3)),
      ],
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: Colors.grey.shade600, fontSize: 14),
            prefixIcon:
                Icon(icon, color: Colors.grey.shade600, size: 18),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.primaryColor.withOpacity(0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   HELPER MODELS
// ════════════════════════════════════════════════════════════════════

class _MatchSystemOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MatchSystemOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _PairingOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PairingOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// ════════════════════════════════════════════════════════════════════
//   WEEKDAY CHIP
// ════════════════════════════════════════════════════════════════════
class _WeekdayChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeekdayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_WeekdayChip> createState() => _WeekdayChipState();
}

class _WeekdayChipState extends State<_WeekdayChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primaryColor.withOpacity(0.15)
                : _hovered
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primaryColor.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isSelected
                  ? AppColors.primaryColor
                  : Colors.grey.shade500,
              fontSize: 12,
              fontWeight: widget.isSelected
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   DARK DIALOG
// ════════════════════════════════════════════════════════════════════
class _DarkDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;

  const _DarkDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1F2E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(message,
                style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.5)),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}