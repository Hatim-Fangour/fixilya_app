import 'package:fixilya_app/services/app_config_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class AdminConfigPage extends StatefulWidget {
  const AdminConfigPage({super.key});

  @override
  State<AdminConfigPage> createState() => _AdminConfigPageState();
}

class _AdminConfigPageState extends State<AdminConfigPage> {
  // ── Palette (matches admin dashboard) ─────────────────────────────────────
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);

  final _configService = AppConfigService();

  List<String> _cities = [];
  List<Map<String, dynamic>> _skills = [];
  bool _isLoading = true;

  // Icon choices shown in the "Add Skill" picker
  static final List<MapEntry<String, dynamic>> _iconChoices =
      AppConfigService.iconMap.entries.toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    // Seed Firestore with defaults on first admin visit
    await _configService.seedIfEmpty();
    final results = await Future.wait([
      _configService.getCities(),
      _configService.getSkills(),
    ]);
    if (!mounted) return;
    setState(() {
      _cities = results[0] as List<String>;
      _skills = results[1] as List<Map<String, dynamic>>;
      _isLoading = false;
    });
  }

  // ── Cities ─────────────────────────────────────────────────────────────────

  Future<void> _addCity() async {
    final name = await _showTextDialog(
      title: 'Add City',
      hint: 'e.g. Oujda',
    );
    if (name == null || name.isEmpty) return;
    await _configService.addCity(name);
    await _load();
    Get.snackbar(
      'City Added',
      '"$name" is now available for users.',
      backgroundColor: accentGreen,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _deleteCity(String city) async {
    final confirmed = await _showConfirmDialog(
      'Remove "$city"?',
      'Users will no longer see this city during registration.',
    );
    if (confirmed != true) return;
    await _configService.deleteCity(city);
    await _load();
  }

  // ── Skills ─────────────────────────────────────────────────────────────────

  Future<void> _addSkill() async {
    // Use a proper StatefulWidget dialog to avoid the _dependents.isEmpty
    // assertion that fires when StatefulBuilder rebuilds (icon tap) while
    // the keyboard is simultaneously animating open/closed.
    final result = await showDialog<({String name, String icon})>(
      context: context,
      builder: (_) => _AddSkillDialog(iconChoices: _iconChoices),
    );

    if (result == null || result.name.isEmpty) return;

    try {
      final added = await _configService.addSkill(result.name, result.icon);
      await _load();

      if (added) {
        Get.snackbar(
          'Skill Added',
          '"${result.name}" is now available for handymen.',
          backgroundColor: accentGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } else {
        Get.snackbar(
          'Already Exists',
          '"${result.name}" is already in the skills list.',
          backgroundColor: primaryGold,
          colorText: deepNavy,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add skill: $e',
        backgroundColor: accentRed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> _deleteSkill(String name) async {
    final confirmed = await _showConfirmDialog(
      'Remove "$name"?',
      'Handymen will no longer see this skill during registration.',
    );
    if (confirmed != true) return;
    await _configService.deleteSkill(name);
    await _load();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<String?> _showTextDialog({
    required String title,
    required String hint,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: softWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: softWhite),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: softWhite.withValues(alpha: 0.4)),
            filled: true,
            fillColor: deepNavy,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGold,
              foregroundColor: deepNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: softWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: softWhite.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: softWhite.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Cities',
            subtitle: 'Available city options during user registration',
            icon: FontAwesomeIcons.locationDot,
            addLabel: 'Add City',
            onAdd: _addCity,
            child: _buildCitiesList(),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Skills',
            subtitle:
                'Service categories handymen can select during registration',
            icon: FontAwesomeIcons.screwdriverWrench,
            addLabel: 'Add Skill',
            onAdd: _addSkill,
            child: _buildSkillsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required dynamic icon,
    required String addLabel,
    required Future<void> Function() onAdd,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: charcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withValues(alpha: 0.15), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: FaIcon(icon as dynamic, color: primaryGold, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: softWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: softWhite.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onAdd(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: primaryGold,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: deepNavy, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        addLabel,
                        style: const TextStyle(
                          color: deepNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCitiesList() {
    if (_cities.isEmpty) {
      return _buildEmpty('No cities yet. Add one above.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _cities.map((city) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: deepNavy,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryGold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(
                FontAwesomeIcons.locationDot,
                size: 11,
                color: primaryGold,
              ),
              const SizedBox(width: 6),
              Text(
                city,
                style: const TextStyle(color: softWhite, fontSize: 13),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteCity(city),
                child: const Icon(Icons.close, size: 14, color: accentRed),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsList() {
    if (_skills.isEmpty) {
      return _buildEmpty('No skills yet. Add one above.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _skills.map((skill) {
        final name = skill['name'] as String;
        final icon = skill['icon'];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: deepNavy,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryGold.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icon as dynamic, size: 11, color: primaryGold),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(color: softWhite, fontSize: 13),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteSkill(name),
                child: const Icon(Icons.close, size: 14, color: accentRed),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          message,
          style: TextStyle(color: softWhite.withValues(alpha: 0.4), fontSize: 13),
        ),
      ),
    );
  }
}

// ── Add Skill Dialog ──────────────────────────────────────────────────────────
// Isolated StatefulWidget so icon-tap rebuilds never touch the parent's
// InheritedWidget dependents — fixes the _dependents.isEmpty assertion.

class _AddSkillDialog extends StatefulWidget {
  final List<MapEntry<String, dynamic>> iconChoices;
  const _AddSkillDialog({required this.iconChoices});

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  static const Color _primaryGold = Color(0xFFD4AF37);
  static const Color _deepNavy   = Color(0xFF0A1929);
  static const Color _charcoal   = Color(0xFF1A2332);
  static const Color _softWhite  = Color(0xFFFAFAFA);

  final _nameCtrl = TextEditingController();
  String _selectedIcon = 'wrench';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _charcoal,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Add Skill',
        style: TextStyle(color: _softWhite, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(color: _softWhite),
              decoration: InputDecoration(
                hintText: 'e.g. Tile Laying',
                hintStyle: TextStyle(color: _softWhite.withValues(alpha: 0.4)),
                filled: true,
                fillColor: _deepNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Icon',
              style: TextStyle(color: _softWhite.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.iconChoices.map((entry) {
                final selected = entry.key == _selectedIcon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? _primaryGold.withValues(alpha: 0.25)
                          : _deepNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? _primaryGold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: FaIcon(
                        entry.value as dynamic,
                        size: 16,
                        color: selected ? _primaryGold : _softWhite,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: _softWhite.withValues(alpha: 0.6)),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGold,
            foregroundColor: _deepNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context, (name: name, icon: _selectedIcon));
          },
          child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
