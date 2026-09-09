import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../main.dart' show themeNotifier, themeColorNotifier;
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'classification_guide_screen.dart';
import 'donation_screen.dart';
import '../utils/theme_helper.dart';
import '../utils/firestore_batch_utils.dart';
import '../utils/app_logger.dart';

class SettingsScreenEnhanced extends StatefulWidget {
  final bool isInAppShell;

  const SettingsScreenEnhanced({super.key, this.isInAppShell = false});

  @override
  State<SettingsScreenEnhanced> createState() => _SettingsScreenEnhancedState();
}

class _SettingsScreenEnhancedState extends State<SettingsScreenEnhanced> {
  // Settings values
  bool _notificationsEnabled = true;
  bool _darkMode = true;
  bool _anonymizeLocation = false;
  bool _highNoiseAlerts = true;
  bool _dailyReminders = false;
  int _recordingDuration = 10; // seconds
  int _saveFrequency = 5; // seconds
  double _dbThreshold = 70.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Cleanup of legacy keys whose controls were removed (settings-6):
    // phone hardware (noise_meter) exposes no A/C weighting or fast/slow
    // response time, so these settings could never do anything.
    await prefs.remove('use_dba');
    await prefs.remove('use_fast_response');
    // arch-1: 'share_data_with_researchers' had zero backend consumers;
    // all readings already flow to the shared community collection, and the
    // real privacy control is 'anonymize_location' (playbook 04).
    await prefs.remove('share_data_with_researchers');
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _highNoiseAlerts = prefs.getBool('high_noise_alerts') ?? true;
        _dailyReminders = prefs.getBool('daily_reminders') ?? false;
        _darkMode = prefs.getBool('dark_mode') ?? true;
        _anonymizeLocation = prefs.getBool('anonymize_location') ?? false;
        _recordingDuration = prefs.getInt('recording_duration') ?? 10;
        _saveFrequency = prefs.getInt('save_frequency') ?? 5;
        _dbThreshold = prefs.getDouble('db_threshold') ?? 70.0;
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        leading: widget.isInAppShell
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // APPEARANCE SECTION
          _buildSectionHeader('Appearance', Icons.palette),
          _buildSettingCard([
            _buildSwitchSetting('Dark Mode', Icons.dark_mode, _darkMode, (val) {
              setState(() => _darkMode = val);
              _saveSetting('dark_mode', val);
              // Actually change theme immediately
              themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    val ? 'Dark mode enabled' : 'Light mode enabled',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 1),
                ),
              );
            }),
            _buildNavigationItem(
              'Theme Colors',
              Icons.color_lens,
              () => _showThemeColorPicker(),
            ),
          ]),

          const SizedBox(height: 24),

          // MEASUREMENT SECTION
          _buildSectionHeader('Measurement', Icons.mic),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Readings use your phone microphone\'s built-in response. '
              'Professional A/C frequency weighting and fast/slow response '
              'modes are not supported by phone hardware.',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(
                  context,
                ).withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          _buildSettingCard([
            _buildSliderSetting(
              'Recording Duration',
              _recordingDuration.toDouble(),
              1,
              60,
              'seconds',
              (val) {
                setState(() => _recordingDuration = val.toInt());
                _saveSetting('recording_duration', val.toInt());
              },
            ),
            _buildSliderSetting(
              'Save Frequency',
              _saveFrequency.toDouble(),
              5,
              30,
              'seconds',
              (val) {
                setState(() => _saveFrequency = val.toInt());
                _saveSetting('save_frequency', val.toInt());
              },
            ),
            _buildSliderSetting(
              'Alert Threshold',
              _dbThreshold,
              50,
              100,
              'dB',
              (val) {
                setState(() => _dbThreshold = val);
                _saveSetting('db_threshold', val);
              },
            ),
          ]),

          const SizedBox(height: 24),

          // NOTIFICATIONS SECTION
          _buildSectionHeader('Notifications', Icons.notifications),
          _buildSettingCard([
            _buildSwitchSetting(
              'Enable Notifications',
              Icons.notifications_active,
              _notificationsEnabled,
              (val) {
                setState(() => _notificationsEnabled = val);
                _saveSetting('notifications_enabled', val);
              },
            ),
            _buildSwitchSetting(
              'High Noise Alerts',
              Icons.warning,
              _highNoiseAlerts,
              (val) {
                setState(() => _highNoiseAlerts = val);
                _saveSetting('high_noise_alerts', val);
              },
            ),
            _buildSwitchSetting(
              'Daily Reminders',
              Icons.alarm,
              _dailyReminders,
              (val) {
                setState(() => _dailyReminders = val);
                _saveSetting('daily_reminders', val);
              },
            ),
          ]),

          const SizedBox(height: 24),

          // PRIVACY SECTION
          _buildSectionHeader('Privacy & Security', Icons.security),
          _buildSettingCard([
            _buildSwitchSetting(
              'Anonymize Location',
              Icons.location_off,
              _anonymizeLocation,
              (val) {
                setState(() => _anonymizeLocation = val);
                _saveSetting('anonymize_location', val);
              },
            ),
            _buildNavigationItem('Privacy Policy', Icons.policy, () {}),
          ]),

          const SizedBox(height: 24),

          // ACCOUNT SECTION
          _buildSectionHeader('Account', Icons.person),
          _buildSettingCard([
            _buildNavigationItem('Edit Profile', Icons.edit, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            }),
            _buildNavigationItem(
              'Change Password',
              Icons.lock,
              () => _showChangePassword(),
            ),
            _buildNavigationItem(
              'Delete Account',
              Icons.delete_forever,
              () => _showDeleteAccountConfirmation(),
              isDestructive: true,
            ),
          ]),

          const SizedBox(height: 24),

          // DATA MANAGEMENT SECTION
          _buildSectionHeader('Data Management', Icons.storage),
          _buildSettingCard([
            _buildNavigationItem('Export All Data', Icons.download, () {}),
            _buildNavigationItem(
              'Clear History',
              Icons.clear_all,
              () => _showClearHistoryConfirmation(),
              isDestructive: true,
            ),
          ]),

          const SizedBox(height: 24),

          // ABOUT SECTION
          _buildSectionHeader('About & Support', Icons.info),
          _buildSettingCard([
            // DONATION BUTTON - Support This Project
            _buildNavigationItem(
              'Support This Project',
              Icons.favorite,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonationScreen(),
                  ),
                );
              },
              subtitle: 'Help us keep this app free',
              isDonation: true,
            ),
            _buildNavigationItem(
              'About App',
              Icons.info_outline,
              _showAboutDialog,
            ),
            _buildNavigationItem(
              'Sound Classification Guide',
              Icons.help_outline,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClassificationGuideScreen(),
                  ),
                );
              },
            ),
            _buildNavigationItem('Rate Us', Icons.star_outline, () {}),
            _buildNavigationItem(
              'Contact Support',
              Icons.email_outlined,
              () {},
            ),
            _buildNavigationItem(
              'Terms of Service',
              Icons.description_outlined,
              () {},
            ),
          ]),

          const SizedBox(height: 40),

          // App Version
          Center(
            child: Text(
              'Version 1.0.0 (Build 1)',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(
                  context,
                ).withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: null,
    );
  }

  // Section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ThemeHelper.getPrimaryColor(context), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: ThemeHelper.getTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Setting card container
  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }

  // Switch setting
  Widget _buildSwitchSetting(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: ThemeHelper.getPrimaryColor(context), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ThemeHelper.getPrimaryColor(context),
          ),
        ],
      ),
    );
  }

  // Slider setting
  Widget _buildSliderSetting(
    String title,
    double value,
    double min,
    double max,
    String unit,
    Function(double) onChanged,
  ) {
    final isDark = ThemeHelper.isDark(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: ThemeHelper.getTextColor(context)),
              ),
              Text(
                '${value.toInt()} $unit',
                style: TextStyle(
                  color: ThemeHelper.getPrimaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: ThemeHelper.getPrimaryColor(context),
            inactiveColor: isDark
                ? AppTheme.darkPurple
                : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // Navigation item
  Widget _buildNavigationItem(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    String? subtitle,
    bool isDonation = false,
  }) {
    final isDark = ThemeHelper.isDark(context);
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDonation
                  ? Colors.red
                  : isDestructive
                      ? Colors.red
                      : ThemeHelper.getPrimaryColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive
                          ? Colors.red
                          : ThemeHelper.getTextColor(context),
                      fontWeight: isDonation ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: ThemeHelper.getSecondaryTextColor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Theme color picker dialog
  void _showThemeColorPicker() {
    // Capture brightness before showing dialog to avoid context issues
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark
            ? AppTheme.cardBackground
            : AppTheme.lightCardBackground,
        title: Text(
          'Choose Theme Color',
          style: TextStyle(
            color: isDark
                ? AppTheme.textWhite
                : AppTheme.textDark,
          ),
        ),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: AppTheme.themeColors.entries.map((entry) {
            return _buildColorOption(entry.value, entry.key, isDark);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color, String name, bool isDark) {
    // Check if this is the currently selected color
    final isSelected = themeColorNotifier.value.toARGB32() == color.toARGB32();

    return GestureDetector(
      onTap: () async {
        // Apply the color instantly
        themeColorNotifier.value = color;

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('theme_color', color.toARGB32());

        // Close dialog
        if (mounted) {
          Navigator.pop(context);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name theme applied!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              color: isDark
                  ? (isSelected ? AppTheme.textWhite : AppTheme.textGray)
                  : (isSelected ? AppTheme.textDark : AppTheme.textLightGray),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Change password dialog
  void _showChangePassword() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text(
          'Change Password',
          style: TextStyle(color: ThemeHelper.getTextColor(context)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();

              // Validation
              if (currentPassword.isEmpty || newPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New password must be at least 6 characters'),
                  ),
                );
                return;
              }

              if (currentPassword == newPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New password must be different from current password',
                    ),
                  ),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null || user.email == null) {
                  throw Exception('No user logged in');
                }

                // Re-authenticate user before password change (Firebase requirement for sensitive operations)
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );

                await user.reauthenticateWithCredential(credential);

                // Now change the password
                await user.updatePassword(newPassword);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password changed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String errorMessage = 'Failed to change password';

                if (e.code == 'wrong-password') {
                  errorMessage = 'Current password is incorrect';
                } else if (e.code == 'weak-password') {
                  errorMessage = 'New password is too weak';
                } else if (e.code == 'requires-recent-login') {
                  errorMessage =
                      'Please log out and log in again before changing password';
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Change',
              style: TextStyle(color: ThemeHelper.getPrimaryColor(context)),
            ),
          ),
        ],
      ),
    );
  }

  // Delete account confirmation. Collects the password up front because
  // deletion re-authenticates BEFORE touching any data
  // (settings-1/sec-3/flow6-01).
  void _showDeleteAccountConfirmation() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will delete your account, but your noise recordings will be preserved as anonymous community data to help reduce noise pollution. This action cannot be undone.\n\nEnter your password to confirm.',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your password to confirm'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _deleteAccount(password);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Delete account implementation.
  // Order is CRITICAL (settings-1/sec-3/flow6-01):
  //   1. Re-authenticate — the only step that can fail with
  //      requires-recent-login, so it must fail BEFORE any data is
  //      touched (mirrors the change-password flow above).
  //   2. Anonymize readings in chunked batches (arch-4/flow6-05).
  //   3. Delete the Firebase Auth user.
  Future<void> _deleteAccount(String password) async {
    var loadingShown = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user logged in');
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
          ),
        ),
      );
      loadingShown = true;

      // Step 1: Re-authenticate FIRST. Destructive writes only run once
      // Firebase has accepted a fresh credential, so a stale session can
      // never orphan the user's data.
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Step 2: Anonymize user's noise readings (DON'T DELETE - preserve
      // community data!) in chunked batches.
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('noise_readings')
          .where('userId', isEqualTo: uid)
          .get();

      await FirestoreBatchUtils.applyInChunks(
        firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.update(ref, {
          'userEmail': 'Deleted User',
          'userId': 'deleted_user_${uid.substring(0, 8)}',
          // Keep partial ID for data integrity
        }),
      );

      // Step 3: Delete the Firebase Auth user (but data stays!)
      await user.delete();

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      loadingShown = false;

      // Navigate to login screen and clear all previous routes
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.error('[Settings] Account deletion failed', e);

      // Close loading dialog if open
      if (loadingShown && mounted) {
        Navigator.pop(context);
      }

      String errorMessage = 'Failed to delete account';

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage =
            'Password is incorrect. Your account and data were NOT changed.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'Please log out and log in again before deleting your account';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      AppLogger.error('[Settings] Account deletion failed', e);

      // Close loading dialog if open
      if (loadingShown && mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Clear history confirmation
  void _showClearHistoryConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text(
          'Clear History?',
          style: TextStyle(color: ThemeHelper.getTextColor(context)),
        ),
        content: Text(
          'This will delete all your noise recordings. This action cannot be undone.',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearHistory();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Clear history implementation
  Future<void> _clearHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: ThemeHelper.getPrimaryColor(context),
          ),
        ),
      );

      // Get all user's noise readings
      final uid = user.uid;
      final firestore = FirebaseFirestore.instance;

      final snapshot = await firestore
          .collection('noise_readings')
          .where('userId', isEqualTo: uid)
          .get();

      // Delete all readings in chunked batches (arch-4/flow6-05: a single
      // WriteBatch fails outright over 500 operations)
      await FirestoreBatchUtils.applyInChunks(
        firestore,
        snapshot.docs.map((doc) => doc.reference).toList(),
        (batch, ref) => batch.delete(ref),
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'History cleared successfully (${snapshot.docs.length} recordings deleted)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseException catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear history: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // About dialog
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Urban Noise Pollution Mapper',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: ThemeHelper.getPrimaryColor(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.mic, color: Colors.white, size: 30),
      ),
      children: [
        const Text('Urban Noise Pollution Mapper'),
        const SizedBox(height: 8),
        const Text(
          'A community-driven noise monitoring solution for Sri Lankan cities.',
        ),
        const SizedBox(height: 16),
        const Text('Developed by: Nuhaadh Hassan'),
        const Text('Student ID: 20230670'),
        const Text('KD/BSCSD/20/74'),
      ],
    );
  }

}
