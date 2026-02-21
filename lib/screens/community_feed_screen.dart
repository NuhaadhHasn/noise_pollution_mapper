import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get color based on decibel level
  Color _getNoiseColor(double db) {
    if (db < 50) return AppTheme.lowNoise;
    if (db < 70) return AppTheme.moderateNoise;
    return AppTheme.highNoise;
  }

  // Get noise level label
  String _getNoiseLevelLabel(double db) {
    if (db < 50) return 'Safe';
    if (db < 70) return 'Moderate';
    return 'High';
  }

  // Format timestamp to "X mins ago" or "X hours ago"
  String _getTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Community Feed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('noise_readings')
            .orderBy('timestamp', descending: true)
            .limit(100) // Load last 100 reports
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryPurple,
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme
                        .of(context)
                        .brightness == Brightness.dark
                        ? AppTheme.textGray
                        : AppTheme.textLightGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading community feed',
                    style: TextStyle(
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? AppTheme.textGray
                          : AppTheme.textLightGray,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // No data state
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Theme
                        .of(context)
                        .brightness == Brightness.dark
                        ? AppTheme.textGray
                        : AppTheme.textLightGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No community reports yet',
                    style: TextStyle(
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? AppTheme.textGray
                          : AppTheme.textLightGray,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to contribute!',
                    style: TextStyle(
                      color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? AppTheme.textGray
                          : AppTheme.textLightGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          // Display community reports
          final reports = snapshot.data!.docs;

          return RefreshIndicator(
            color: AppTheme.primaryPurple,
            onRefresh: () async {
              // The stream automatically refreshes, but we add a small delay for UX
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index].data() as Map<String, dynamic>;
                final decibelLevel = (report['decibelLevel'] ?? 0.0).toDouble();
                final locationName = report['locationName'] ??
                    'Unknown Location';
                final userEmail = report['userEmail'] ?? 'Anonymous';

                // Use server timestamp if available, otherwise fallback to client timestamp
                Timestamp? timestamp = report['timestamp'] as Timestamp?;
                if (timestamp == null && report['createdAt'] != null) {
                  // Convert DateTime to Timestamp if createdAt exists
                  final createdAt = report['createdAt'];
                  if (createdAt is Timestamp) {
                    timestamp = createdAt;
                  } else if (createdAt is DateTime) {
                    timestamp = Timestamp.fromDate(createdAt);
                  }
                }

                return _buildReportCard(
                  decibelLevel: decibelLevel,
                  locationName: locationName,
                  userEmail: userEmail,
                  timestamp: timestamp,
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Build individual report card
  Widget _buildReportCard({
    required double decibelLevel,
    required String locationName,
    required String userEmail,
    Timestamp? timestamp,
  }) {
    final noiseColor = _getNoiseColor(decibelLevel);
    final noiseLevelLabel = _getNoiseLevelLabel(decibelLevel);
    final timeAgo = timestamp != null ? _getTimeAgo(timestamp) : 'Unknown time';

    // Mask email for privacy (show first 3 chars + ***)
    String displayName = userEmail;
    if (userEmail != 'Anonymous' && userEmail != 'Deleted User' &&
        userEmail.contains('@')) {
      final emailParts = userEmail.split('@');
      if (emailParts[0].length > 3) {
        displayName = '${emailParts[0].substring(0, 3)}***@${emailParts[1]}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Theme
          .of(context)
          .brightness == Brightness.dark
          ? AppTheme.cardBackground
          : AppTheme.lightCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: noiseColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left side: Decibel level circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: noiseColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: noiseColor,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    decibelLevel.toStringAsFixed(0),
                    style: TextStyle(
                      color: noiseColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'dB',
                    style: TextStyle(
                      color: noiseColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right side: Report details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location with icon
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: Theme
                            .of(context)
                            .brightness == Brightness.dark
                            ? AppTheme.primaryPurple
                            : AppTheme.accentPurple,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          locationName,
                          style: TextStyle(
                            color: Theme
                                .of(context)
                                .brightness == Brightness.dark
                                ? AppTheme.textWhite
                                : AppTheme.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Noise level badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: noiseColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      noiseLevelLabel,
                      style: TextStyle(
                        color: noiseColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // User and time info
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Theme
                            .of(context)
                            .brightness == Brightness.dark
                            ? AppTheme.textGray
                            : AppTheme.textLightGray,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: Theme
                                .of(context)
                                .brightness == Brightness.dark
                                ? AppTheme.textGray
                                : AppTheme.textLightGray,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Theme
                            .of(context)
                            .brightness == Brightness.dark
                            ? AppTheme.textGray
                            : AppTheme.textLightGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: Theme
                              .of(context)
                              .brightness == Brightness.dark
                              ? AppTheme.textGray
                              : AppTheme.textLightGray,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
