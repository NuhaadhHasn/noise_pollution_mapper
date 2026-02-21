import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/theme_helper.dart';
import '../services/firebase_service.dart';
import 'report_noise_screen.dart';

class HistoryScreen extends StatelessWidget {
  final bool isInAppShell;

  const HistoryScreen({super.key, this.isInAppShell = false});

  // Export data to CSV
  Future<void> _exportDataToCSV(BuildContext context) async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing export...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Get all readings from Firebase
      final snapshot = await FirebaseFirestore.instance
          .collection('noise_readings')
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      // Create CSV content
      StringBuffer csvData = StringBuffer();

      // CSV Header (includes sound classification fields)
      csvData.writeln('Timestamp,Location,Latitude,Longitude,Decibel Level (dB),Sound Classification,Sound Type,Confidence (%),User Email,Device');

      // Add data rows
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        final timestampStr = timestamp != null
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)
            : 'N/A';

        final location = data['locationName'] ?? 'Unknown';
        final lat = data['latitude'] ?? 0.0;
        final lng = data['longitude'] ?? 0.0;
        final db = data['decibelLevel'] ?? 0.0;
        final email = data['userEmail'] ?? 'N/A';
        final device = data['deviceInfo'] ?? 'N/A';

        // Sound classification data (may be null for older records)
        final soundClass = data['soundClass'] ?? 'N/A';
        final soundType = data['soundType'] ?? 'N/A';
        final confidence = data['confidence'];
        final confidenceStr = confidence != null
            ? (confidence * 100).toStringAsFixed(1)
            : 'N/A';

        csvData.writeln('$timestampStr,"$location",$lat,$lng,$db,"$soundClass","$soundType",$confidenceStr,$email,$device');
      }

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'noise_pollution_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvData.toString());

      // Success message
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ThemeHelper.getCardColor(context),
            title: Text('Export Successful!', style: TextStyle(color: ThemeHelper.getTextColor(context))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exported ${snapshot.docs.length} recordings',
                  style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                ),
                const SizedBox(height: 12),
                Text(
                  'File saved to:',
                  style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  file.path,
                  style: TextStyle(color: ThemeHelper.getPrimaryColor(context), fontSize: 11),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: ThemeHelper.getPrimaryColor(context))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // If no user is logged in, show error
    if (userId == null) {
      return Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        appBar: AppBar(
          title: Text('History'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Please log in to view history',
            style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Your Recordings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
        actionsIconTheme: const IconThemeData(color: AppTheme.textWhite),
        leading: isInAppShell
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          // Export button - same color as History title
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _exportDataToCSV(context),
            tooltip: 'Export Data to CSV',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getUserReadings(userId),
        builder: (context, snapshot) {
          // Show error if there's an error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading history',
                    style: TextStyle(color: ThemeHelper.getTextColor(context), fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: ThemeHelper.getPrimaryColor(context)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha:0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recordings yet',
                    style: TextStyle(
                      color: ThemeHelper.getSecondaryTextColor(context),
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start recording to build your history',
                    style: TextStyle(
                      color: ThemeHelper.getSecondaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final db = (data['decibelLevel'] as num).toDouble();
              final location = data['locationName'] as String? ?? 'Unknown';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final soundClass = data['soundClass'] as String?;
              final soundType = data['soundType'] as String?;
              final confidence = data['confidence'] as num?;

              return FadeInListItem(
                index: index,
                child: _buildHistoryItem(
                  context,
                  db,
                  location,
                  timestamp,
                  docs[index].id,
                  soundClass: soundClass,
                  soundType: soundType,
                  confidence: confidence?.toDouble(),
                ),
              );
            },
          );
        },
      ),
      // Floating Action Button - Add Manual Entry
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportNoiseScreen()),
          );
        },
        backgroundColor: ThemeHelper.getPrimaryColor(context),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Manual',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: null,
    );
  }

  // History item widget
  Widget _buildHistoryItem(
    BuildContext context,
    double db,
    String location,
    DateTime? timestamp,
    String docId, {
    String? soundClass,
    String? soundType,
    double? confidence,
  }) {
    Color dbColor;
    if (db < 50) {
      dbColor = AppTheme.lowNoise;
    } else if (db < 70) {
      dbColor = AppTheme.moderateNoise;
    } else {
      dbColor = AppTheme.highNoise;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: dbColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          // dB level circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: dbColor.withValues(alpha:0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                db.toStringAsFixed(0),
                style: TextStyle(
                  color: dbColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: TextStyle(
                    color: ThemeHelper.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (timestamp != null)
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp),
                    style: TextStyle(
                      color: ThemeHelper.getSecondaryTextColor(context),
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _getNoiseLevel(db),
                  style: TextStyle(
                    color: dbColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Sound Classification Badge
                if (soundClass != null && soundType != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: soundType == 'Pollution'
                              ? Colors.red.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: soundType == 'Pollution'
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.green.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getSoundIcon(soundClass),
                              size: 12,
                              color: soundType == 'Pollution'
                                  ? Colors.red[300]
                                  : Colors.green[300],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              soundClass,
                              style: TextStyle(
                                color: soundType == 'Pollution'
                                    ? Colors.red[300]
                                    : Colors.green[300],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (confidence != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${(confidence * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: soundType == 'Pollution'
                                      ? Colors.red[200]
                                      : Colors.green[200],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: ThemeHelper.getSecondaryTextColor(context)),
            onPressed: () {
              _showDeleteConfirmation(context, docId);
            },
          ),
        ],
      ),
    );
  }

  String _getNoiseLevel(double db) {
    if (db < 50) return 'Low Noise - Safe';
    if (db < 70) return 'Moderate Noise';
    return 'High Noise - Dangerous!';
  }

  // Get icon for sound classification
  IconData _getSoundIcon(String soundClass) {
    switch (soundClass.toLowerCase()) {
      case 'traffic':
        return Icons.directions_car;
      case 'construction':
        return Icons.construction;
      case 'industrial':
        return Icons.factory;
      case 'speech':
      case 'speech-ambient':
      case 'speech-pollution':
        return Icons.person;
      case 'music':
        return Icons.music_note;
      case 'religious':
        return Icons.temple_hindu;
      case 'market':
        return Icons.store;
      case 'nature':
        return Icons.nature;
      case 'tuk-tuk':
        return Icons.moped;
      default:
        return Icons.volume_up;
    }
  }

  // Delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text('Delete Recording', style: TextStyle(color: ThemeHelper.getTextColor(context))),
        content: Text(
          'Are you sure you want to delete this recording?',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('noise_readings').doc(docId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recording deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}
