import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings values
  bool _useDbA = true; // true = dBA, false = dBC
  bool _useFastResponse = true; // true = Fast, false = Slow

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved settings
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _useDbA = prefs.getBool('use_dba') ?? true;
        _useFastResponse = prefs.getBool('use_fast_response') ?? true;
      });
    }
  }

  // Save settings
  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Units Section
          _buildSectionTitle('Units'),
          const SizedBox(height: 12),

          _buildToggleSetting(
            title: 'Decibel Scale',
            leftOption: 'dBA',
            rightOption: 'dBC',
            isLeftSelected: _useDbA,
            onChanged: (isLeft) {
              setState(() {
                _useDbA = isLeft;
              });
              _saveSetting('use_dba', isLeft);
            },
          ),

          const SizedBox(height: 12),

          _buildToggleSetting(
            title: 'Response Time',
            leftOption: 'Fast',
            rightOption: 'Slow',
            isLeftSelected: _useFastResponse,
            onChanged: (isLeft) {
              setState(() {
                _useFastResponse = isLeft;
              });
              _saveSetting('use_fast_response', isLeft);
            },
          ),

          const SizedBox(height: 32),

          // Apps Section
          _buildSectionTitle('Apps'),
          const SizedBox(height: 12),

          _buildMenuCard([
            _buildMenuItem(Icons.widgets, 'General', () {
              // TODO: Navigate to general settings
            }),
            _buildMenuItem(Icons.info_outline, 'About', () {
              _showAboutDialog();
            }),
            _buildMenuItem(Icons.share, 'Share', () {
              // TODO: Share app functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality coming soon!')),
              );
            }),
            _buildMenuItem(Icons.group_add, 'Join with us', () {
              // TODO: Join/community page
            }),
          ]),

          const SizedBox(height: 24),

          // Review Button
          _buildActionButton('Review', () {
            // TODO: Open app store for review
          }),

          const SizedBox(height: 12),

          // Feedback Button
          _buildActionButton('Feedback', () {
            // TODO: Open feedback form
          }),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Section title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textWhite,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Toggle setting widget (dBA/dBC style)
  Widget _buildToggleSetting({
    required String title,
    required String leftOption,
    required String rightOption,
    required bool isLeftSelected,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildToggleButton(leftOption, isLeftSelected, () => onChanged(true)),
                _buildToggleButton(rightOption, !isLeftSelected, () => onChanged(false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Toggle button
  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textGray,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Menu card container
  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items,
      ),
    );
  }

  // Menu item
  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.darkPurple, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textGray),
          ],
        ),
      ),
    );
  }

  // Action button (Review, Feedback)
  Widget _buildActionButton(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Show about dialog
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'About',
          style: TextStyle(color: AppTheme.textWhite),
        ),
        content: const Text(
          'Urban Noise Pollution Mapper\n\n'
          'Version: 1.0.0\n\n'
          'A community-driven noise monitoring solution for Sri Lankan cities.\n\n'
          'Developed by: Nuhaadh Hassan\n'
          'Student ID: 20230670',
          style: TextStyle(color: AppTheme.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryPurple)),
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.darkPurple,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(Icons.map_outlined, () => Navigator.pop(context)),
          _buildNavButton(Icons.bar_chart, () => Navigator.pop(context)),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha:0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.home, color: Colors.white, size: 28),
            ),
          ),
          _buildNavButton(Icons.add_circle_outline, () {}),
          _buildNavButton(Icons.settings_outlined, () {}, isActive: true),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isActive ? AppTheme.primaryPurple : AppTheme.textGray,
          size: 28,
        ),
      ),
    );
  }
}
