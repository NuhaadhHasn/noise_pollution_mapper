import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../utils/app_logger.dart';

/// Widget that displays sync status in app bar
/// Shows different icons based on online/offline state and pending uploads
class SyncStatusIndicator extends StatefulWidget {
  final VoidCallback? onTap;

  const SyncStatusIndicator({
    super.key,
    this.onTap,
  });

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final SyncService _syncService = SyncService();
  Map<String, dynamic> _syncStatus = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    // Refresh status every 2 seconds for faster updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateStatus();
    });
  }

  void _updateStatus() {
    try {
      if (mounted) {
        setState(() {
          _syncStatus = _syncService.getSyncStatus();
        });
      }
    } catch (e) {
      AppLogger.error('[SyncStatusIndicator] Error updating status', e);
      // Set default offline state on error
      if (mounted) {
        setState(() {
          _syncStatus = {
            'isOnline': false,
            'isSyncing': false,
            'pendingCount': 0,
            'lastSyncTime': null,
          };
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _syncStatus['isOnline'] as bool? ?? false;
    final isSyncing = _syncStatus['isSyncing'] as bool? ?? false;
    final pendingCount = _syncStatus['pendingCount'] as int? ?? 0;

    // Choose icon and color based on status
    IconData icon;
    Color iconColor;
    String tooltipText;

    if (isSyncing) {
      // Currently syncing
      icon = Icons.sync;
      iconColor = Theme.of(context).colorScheme.primary;
      tooltipText = 'Syncing $pendingCount recording(s)...';
    } else if (!isOnline) {
      // Offline
      icon = Icons.cloud_off_outlined;
      iconColor = Colors.orange;
      tooltipText = pendingCount > 0
          ? 'Offline - $pendingCount recording(s) queued'
          : 'Offline';
    } else if (pendingCount > 0) {
      // Online with pending uploads
      icon = Icons.cloud_upload_outlined;
      iconColor = Colors.orange;
      tooltipText = '$pendingCount recording(s) pending upload';
    } else {
      // All synced
      icon = Icons.cloud_done_outlined;
      iconColor = Colors.green;
      tooltipText = 'All recordings synced';
    }

    return Tooltip(
      message: tooltipText,
      child: GestureDetector(
        onTap: () {
          _showSyncStatusDialog(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            else
              Icon(
                icon,
                size: 18,
                color: iconColor,
              ),
            if (pendingCount > 0 && !isSyncing) ...[
              const SizedBox(width: 4),
              Text(
                '$pendingCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _showSyncStatusDialog(BuildContext context) {
    final isOnline = _syncStatus['isOnline'] as bool? ?? false;
    final isSyncing = _syncStatus['isSyncing'] as bool? ?? false;
    final pendingCount = _syncStatus['pendingCount'] as int? ?? 0;
    final lastSyncTime = _syncStatus['lastSyncTime'] as DateTime?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: isOnline ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            _buildStatusRow(
              'Connection:',
              isOnline ? 'Online' : 'Offline',
              isOnline ? Icons.wifi : Icons.wifi_off,
              isOnline ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            // Pending count
            _buildStatusRow(
              'Pending Uploads:',
              '$pendingCount recording(s)',
              pendingCount > 0 ? Icons.upload_file : Icons.check_circle,
              pendingCount > 0 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 12),
            // Sync status
            _buildStatusRow(
              'Sync Status:',
              isSyncing ? 'Syncing...' : (isOnline ? 'Ready' : 'Waiting for connection'),
              isSyncing ? Icons.sync : Icons.info,
              isSyncing ? Colors.blue : Colors.grey,
            ),
            if (lastSyncTime != null) ...[
              const SizedBox(height: 12),
              _buildStatusRow(
                'Last Sync:',
                _formatDateTime(lastSyncTime),
                Icons.access_time,
                Colors.blue,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (pendingCount > 0 && isOnline && !isSyncing)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _syncService.triggerManualSync();
                if (context.mounted) {
                  _showSyncResultSnackbar(context, pendingCount);
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync Now'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showSyncResultSnackbar(BuildContext context, int initialCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sync, color: Colors.white),
            const SizedBox(width: 12),
            Text('Synced $initialCount recording(s) successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
