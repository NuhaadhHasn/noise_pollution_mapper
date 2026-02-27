import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';

class ReportNoiseScreen extends StatefulWidget {
  const ReportNoiseScreen({super.key});

  @override
  State<ReportNoiseScreen> createState() => _ReportNoiseScreenState();
}

class _ReportNoiseScreenState extends State<ReportNoiseScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  double _manualDb = 50.0; // Default value
  double _latitude = 6.9271;
  double _longitude = 79.8612;
  String _locationName = 'Unknown Location';
  bool _isSubmitting = false;

  // Sound classification options
  String? _selectedSoundClass;
  final List<Map<String, dynamic>> _soundClassOptions = [
    {'value': 'Traffic', 'type': 'Pollution', 'icon': Icons.directions_car},
    {'value': 'Construction', 'type': 'Pollution', 'icon': Icons.construction},
    {'value': 'Industrial', 'type': 'Pollution', 'icon': Icons.factory},
    {'value': 'Tuk-tuk', 'type': 'Pollution', 'icon': Icons.moped},
    {'value': 'Transport', 'type': 'Pollution', 'icon': Icons.train},
    {'value': 'Alarm', 'type': 'Pollution', 'icon': Icons.alarm},
    {'value': 'Speech-Pollution', 'type': 'Pollution', 'icon': Icons.campaign},
    {'value': 'Music', 'type': 'Ambient', 'icon': Icons.music_note},
    {'value': 'Nature', 'type': 'Ambient', 'icon': Icons.nature},
    {'value': 'Speech-Ambient', 'type': 'Ambient', 'icon': Icons.person},
    {'value': 'Religious', 'type': 'Ambient', 'icon': Icons.temple_hindu},
    {'value': 'Market', 'type': 'Ambient', 'icon': Icons.store},
    {'value': 'Domestic', 'type': 'Ambient', 'icon': Icons.home},
    {'value': 'Body Sounds', 'type': 'Ambient', 'icon': Icons.favorite_border},
    {'value': 'Sports', 'type': 'Ambient', 'icon': Icons.sports_soccer},
    {'value': 'Weather', 'type': 'Ambient', 'icon': Icons.cloud},
    {'value': 'Office', 'type': 'Ambient', 'icon': Icons.business_center},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Get current GPS location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }

      // Get location name
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        setState(() {
          _locationName = placemarks.first.locality ?? 'Unknown Location';
        });
      }
    } catch (e) {
      AppLogger.error('Error getting location', e);
    }
  }

  // Submit manual noise report
  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get sound type (Pollution or Ambient) based on selected class
      String? soundType;
      if (_selectedSoundClass != null) {
        final selectedOption = _soundClassOptions.firstWhere(
          (option) => option['value'] == _selectedSoundClass,
        );
        soundType = selectedOption['type'] as String;
      }

      // Save to Firebase with sound classification
      await _firebaseService.saveNoiseReading(
        decibelLevel: _manualDb,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        soundClass: _selectedSoundClass,
        soundType: soundType,
        confidence: _selectedSoundClass != null ? 1.0 : null, // Manual entry = 100% confidence
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Noise report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to Dashboard
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Report Noise'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Decorative waveform (visual element)
            _buildWaveformDisplay(),

            const SizedBox(height: 32),

            // Manual dB entry card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${_manualDb.toInt()} dB',
                    style: TextStyle(
                      color: ThemeHelper.getTextColor(context),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(Manual Entry)',
                    style: TextStyle(
                      color: ThemeHelper.getSecondaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Slider to adjust dB value
                  Slider(
                    value: _manualDb,
                    min: 0,
                    max: 120,
                    divisions: 120,
                    activeColor: ThemeHelper.getPrimaryColor(context),
                    inactiveColor: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                    onChanged: (value) {
                      setState(() {
                        _manualDb = value;
                      });
                    },
                  ),

                  // Min and Max labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0 dB', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12)),
                      Text('120 dB', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sound Classification Dropdown
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeHelper.getCardColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, color: ThemeHelper.getPrimaryColor(context), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Sound Classification',
                        style: TextStyle(
                          color: ThemeHelper.getTextColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Optional)',
                    style: TextStyle(
                      color: ThemeHelper.getSecondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: ThemeHelper.getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: DropdownButton<String>(
                      value: _selectedSoundClass,
                      hint: Text(
                        'Select sound type...',
                        style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                      ),
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: ThemeHelper.getCardColor(context),
                      style: TextStyle(color: ThemeHelper.getTextColor(context), fontSize: 14),
                      icon: Icon(Icons.arrow_drop_down, color: ThemeHelper.getPrimaryColor(context)),
                      items: _soundClassOptions.map((option) {
                        final value = option['value'] as String;
                        final type = option['type'] as String;
                        final icon = option['icon'] as IconData;
                        final isPollution = type == 'Pollution';

                        return DropdownMenuItem<String>(
                          value: value,
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isPollution ? Colors.red[300] : Colors.green[300],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                value,
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPollution
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isPollution
                                        ? Colors.red.withValues(alpha: 0.5)
                                        : Colors.green.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    color: isPollution ? Colors.red[300] : Colors.green[300],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSoundClass = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.getPrimaryColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Location button (full width)
            _buildActionButton(
              icon: Icons.location_on,
              label: _locationName,
              onTap: _getCurrentLocation,
            ),
          ],
        ),
      ),
    );
  }

  // Decorative waveform display
  Widget _buildWaveformDisplay() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: WaveformPainter(color: ThemeHelper.getPrimaryColor(context)),
      ),
    );
  }

  // Action button (Photo, Location)
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeHelper.getPrimaryColor(context).withValues(alpha:0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ThemeHelper.getPrimaryColor(context), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: ThemeHelper.getTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Simple waveform painter for decoration
class WaveformPainter extends CustomPainter {
  final Color color;

  WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);

    // Draw simple sine wave
    for (double i = 0; i <= size.width; i += 5) {
      final y = size.height / 2 + 20 * math.sin(i / 30);
      path.lineTo(i, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
