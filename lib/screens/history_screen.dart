import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/csv_builder.dart';
import '../utils/theme_helper.dart';
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';
import 'report_noise_screen.dart';

class HistoryScreen extends StatefulWidget {
  final bool isInAppShell;

  const HistoryScreen({super.key, this.isInAppShell = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  
  List<DocumentSnapshot> _recordings = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  int _totalCount = 0;
  bool _isOffline = false;
  
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndLoad();
    _scrollController.addListener(_onScroll);
  }

  // Check connectivity and load data
  Future<void> _checkConnectivityAndLoad() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.any((result) => 
        result != ConnectivityResult.none && 
        result != ConnectivityResult.bluetooth
      );

      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
        });

        if (isOnline) {
          _loadInitialRecordings();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Load initial recordings
  Future<void> _loadInitialRecordings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return; // fb-3: finally still resets _isLoading

      // Get total count
      _totalCount = await _firebaseService.getUserReadingsCount(userId);

      // Load first page
      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
      );

      if (mounted) {
        setState(() {
          _recordings = snapshot.docs;
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
          _isOffline = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load history', e);
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    } finally {
      // fb-3: ALWAYS reset — every path, including the userId-null early
      // return. Otherwise _isLoading is stuck true and every retry no-ops.
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load more recordings (infinite scroll)
  Future<void> _loadMoreRecordings() async {
    if (_isLoading || !_hasMore || _isOffline) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return; // fb-3: finally still resets _isLoading

      if (_lastDocument == null) return; // finally resets _isLoading

      final snapshot = await _firebaseService.getUserReadingsPaginated(
        userId: userId,
        limit: _pageSize,
        startAfter: _lastDocument,
      );

      if (mounted) {
        setState(() {
          _recordings.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _hasMore = snapshot.docs.length == _pageSize;
        });
      }
    } catch (e) {
      // Don't show a user-facing error for load-more; log and stop loading.
      AppLogger.error('Failed to load more history', e);
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Scroll listener for infinite scroll
  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when within 200px of the end
      _loadMoreRecordings();
    }
  }

  // Pull to refresh
  Future<void> _onRefresh() async {
    await _checkConnectivityAndLoad();
  }

  // Show offline UI
  Widget _buildOfflineUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 80,
            color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: TextStyle(
              color: ThemeHelper.getTextColor(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please turn on internet to view history',
            style: TextStyle(
              color: ThemeHelper.getSecondaryTextColor(context),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _checkConnectivityAndLoad,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeHelper.getPrimaryColor(context),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Export data to CSV — current user's readings only (fb-4/uiux-3), fetched
  // page-by-page through the composite index (userId ASC, timestamp DESC),
  // CSV assembled on a background isolate (perf-5).
  Future<void> _exportDataToCSV(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to export your data')),
        );
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing export...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Fetch ONLY this user's readings, page by page.
      // userId isEqualTo + orderBy timestamp desc == the one composite index.
      const int exportPageSize = 500;
      final rows = <Map<String, Object?>>[];
      DocumentSnapshot? cursor;
      while (true) {
        final snapshot = await _firebaseService.getUserReadingsPaginated(
          userId: userId,
          limit: exportPageSize,
          startAfter: cursor,
        );

        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Readers handle both server timestamp and client createdAt.
          final createdAtRaw = data['createdAt'];
          final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ??
              (createdAtRaw is Timestamp ? createdAtRaw.toDate() : null);

          final confidence = data['confidence'];
          rows.add({
            'timestamp': timestamp != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)
                : 'N/A',
            'location': data['locationName'] as String? ?? 'Unknown',
            'latitude': data['latitude'] ?? 0.0,
            'longitude': data['longitude'] ?? 0.0,
            'decibelLevel': data['decibelLevel'] ?? 0.0,
            'soundClass': data['soundClass'] as String? ?? 'N/A',
            'soundType': data['soundType'] as String? ?? 'N/A',
            'confidence': confidence is num
                ? (confidence * 100).toStringAsFixed(1)
                : 'N/A',
            'device': data['deviceInfo'] as String? ?? 'N/A',
          });
        }

        if (snapshot.docs.length < exportPageSize) break;
        cursor = snapshot.docs.last;
      }

      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data to export')),
          );
        }
        return;
      }

      // Build the CSV off the UI thread (perf-5)
      final csv = await compute(buildNoiseCsv, rows);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'noise_pollution_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csv);

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
                  'Exported ${rows.length} recordings',
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
        leading: widget.isInAppShell
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          // Export button
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _exportDataToCSV(context),
            tooltip: 'Export Data to CSV',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            // Show count indicator (only when online and has data)
            if (_totalCount > 0 && !_isOffline)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Showing ${_recordings.length} of $_totalCount recordings',
                  style: TextStyle(
                    color: ThemeHelper.getSecondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ),
            // List view
            Expanded(
              child: _isOffline
                  ? _buildOfflineUI()
                  : _recordings.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha: 0.3),
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
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _recordings.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _recordings.length) {
                          // Loading indicator at the bottom
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: ThemeHelper.getPrimaryColor(context),
                              ),
                            ),
                          );
                        }

                        final doc = _recordings[index];
                        final data = doc.data() as Map<String, dynamic>;
                        // social-2/uiux-7: docs from older app versions or
                        // manual reports may lack decibelLevel — never hard-cast.
                        final db =
                            ((data['decibelLevel'] as num?) ?? 0).toDouble();
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
                            doc.id,
                            soundClass: soundClass,
                            soundType: soundType,
                            confidence: confidence?.toDouble(),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
      case 'domestic':
        return Icons.home;
      case 'alarm':
        return Icons.alarm;
      case 'body sounds':
        return Icons.favorite_border;
      case 'transport':
        return Icons.train;
      case 'sports':
        return Icons.sports_soccer;
      case 'weather':
        return Icons.cloud;
      case 'office':
        return Icons.business_center;
      default:
        return Icons.volume_up;
    }
  }

  // Delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ThemeHelper.getCardColor(context),
        title: Text('Delete Recording', style: TextStyle(color: ThemeHelper.getTextColor(context))),
        content: Text(
          'Are you sure you want to delete this recording?',
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close dialog first
              _deleteRecording(docId); // then delete + update the list
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.highNoise)),
          ),
        ],
      ),
    );
  }

  // social-3/uiux-2/flow3-3: delete with immediate local-list update,
  // undo support, and an error path.
  Future<void> _deleteRecording(String docId) async {
    final index = _recordings.indexWhere((d) => d.id == docId);
    if (index == -1) return;
    final removedData = _recordings[index].data() as Map<String, dynamic>;

    try {
      await _firebaseService.deleteNoiseReading(docId);
    } catch (e) {
      AppLogger.error('Failed to delete recording $docId', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete recording. Please try again.'),
            backgroundColor: AppTheme.highNoise,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _recordings.removeAt(index);
      if (_totalCount > 0) _totalCount--;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Recording deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoDelete(docId, removedData, index),
        ),
      ),
    );
  }

  Future<void> _undoDelete(
      String docId, Map<String, dynamic> data, int index) async {
    try {
      await _firebaseService.restoreNoiseReading(docId, data);
      // Re-fetch so the local list holds a real DocumentSnapshot again.
      final restored = await FirebaseFirestore.instance
          .collection('noise_readings')
          .doc(docId)
          .get();
      if (!mounted || !restored.exists) return;
      setState(() {
        _recordings.insert(index.clamp(0, _recordings.length), restored);
        _totalCount++;
      });
    } catch (e) {
      AppLogger.error('Failed to restore recording $docId', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not restore recording.'),
            backgroundColor: AppTheme.highNoise,
          ),
        );
      }
    }
  }

}
