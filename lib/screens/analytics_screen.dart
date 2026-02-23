import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool isInAppShell;

  const AnalyticsScreen({super.key, this.isInAppShell = false});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  double _avgDb = 0;
  double _minDb = 0;
  double _maxDb = 0;
  double _totalHours = 0;
  bool _isLoading = true;

  // Sound type filter (All / Pollution / Ambient)
  String _selectedFilter = 'All';

  // Time-period filter (Daily / Weekly / Monthly)
  String _selectedPeriod = 'Weekly';

  // Sound classification analytics
  Map<String, int> _soundTypeCounts = {};
  int _pollutionCount = 0;
  int _ambientCount = 0;
  double _avgConfidence = 0.0;

  // Cached trend stream — only recreated when _selectedPeriod changes,
  // NOT on every setState (prevents Firestore re-subscription + chart flicker)
  Stream<QuerySnapshot>? _trendStream;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  DateTime _getPeriodStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Daily':
        return now.subtract(const Duration(hours: 24));
      case 'Monthly':
        return now.subtract(const Duration(days: 30));
      case 'Weekly':
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'Daily':
        return 'Last 24 Hours';
      case 'Monthly':
        return 'Last 30 Days';
      case 'Weekly':
      default:
        return 'Last 7 Days';
    }
  }

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadStatistics() async {
    // Capture period NOW — used at the end to detect if the user changed
    // period again while this async call was in flight (race condition guard).
    final capturedPeriod = _selectedPeriod;

    // Check userId FIRST, before any Firestore calls.
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final since = _getPeriodStartDate();

      // Create the stream and cache it immediately so the chart always has
      // a stream to listen to, even if the stats query below fails.
      final newStream =
          _firebaseService.getUserReadingsByPeriod(userId, since);
      if (mounted) setState(() => _trendStream = newStream);

      // Load stats and classification counts for the selected period.
      final stats = await _firebaseService.calculateStatsByPeriod(since);
      final snapshot = await newStream.first;

      final soundTypeCounts = <String, int>{};
      int pollutionCount = 0;
      int ambientCount = 0;
      double totalConfidence = 0.0;
      int confidenceCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final soundClass = data['soundClass'] as String?;
        final soundType = data['soundType'] as String?;
        final confidence = data['confidence'] as num?;

        if (soundClass != null && soundClass.isNotEmpty) {
          soundTypeCounts[soundClass] = (soundTypeCounts[soundClass] ?? 0) + 1;
        }

        if (soundType == 'Pollution') {
          pollutionCount++;
        } else if (soundType == 'Ambient') {
          ambientCount++;
        }

        if (confidence != null) {
          totalConfidence += confidence.toDouble();
          confidenceCount++;
        }
      }

      // Race condition guard: only apply results if the period the user sees
      // right now is still the same one this query was issued for.
      if (!mounted || _selectedPeriod != capturedPeriod) return;

      setState(() {
        _avgDb = stats['avg'] ?? 0;
        _minDb = stats['min'] ?? 0;
        _maxDb = stats['max'] ?? 0;
        _totalHours = (stats['count'] ?? 0) / 12;
        _soundTypeCounts = soundTypeCounts;
        _pollutionCount = pollutionCount;
        _ambientCount = ambientCount;
        _avgConfidence =
            confidenceCount > 0 ? totalConfidence / confidenceCount : 0.0;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error loading statistics', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Trend chart helpers ─────────────────────────────────────────────────────

  /// Aggregates raw Firestore docs into time-bucketed [FlSpot] list.
  /// Daily  → 24 buckets (0 = 23 h ago, 23 = current hour)
  /// Weekly → 7 buckets  (0 = 6 days ago, 6 = today)
  /// Monthly→ 30 buckets (0 = 29 days ago, 29 = today)
  List<FlSpot> _buildTimeAggregatedSpots(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final Map<int, List<double>> buckets = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final db = (data['decibelLevel'] as num?)?.toDouble();
      if (db == null || !db.isFinite || db < 0 || db > 120) continue;

      // Resolve timestamp
      DateTime? readingTime;
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        readingTime = ts.toDate();
      } else {
        final ca = data['createdAt'];
        if (ca is Timestamp) readingTime = ca.toDate();
      }
      if (readingTime == null) continue;

      final int bucket;
      if (_selectedPeriod == 'Daily') {
        final hoursAgo = now.difference(readingTime).inHours;
        if (hoursAgo > 23) continue;
        bucket = 23 - hoursAgo;
      } else {
        final daysAgo = now.difference(readingTime).inDays;
        final maxDays = _selectedPeriod == 'Monthly' ? 29 : 6;
        if (daysAgo > maxDays) continue;
        bucket = maxDays - daysAgo;
      }

      buckets[bucket] = (buckets[bucket] ?? [])..add(db);
    }

    return buckets.entries
        .map((e) {
          final avg = e.value.reduce((a, b) => a + b) / e.value.length;
          return FlSpot(e.key.toDouble(), avg);
        })
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  /// Returns the x-axis label widget for a given bucket value.
  /// interval: 1 ensures this is only called at integer x-values (0, 1, 2…)
  /// so no duplicate labels can appear.
  Widget _getXAxisWidget(double value, TitleMeta meta) {
    final now = DateTime.now();
    final bucketIdx = value.toInt();
    String label = '';

    if (_selectedPeriod == 'Daily') {
      // Labels at bucket positions 0, 6, 12, 18 (every 6 buckets)
      // Bucket 0 = 23h ago, bucket 23 = current hour
      if (bucketIdx % 6 == 0) {
        final hoursAgo = 23 - bucketIdx;
        final date = now.subtract(Duration(hours: hoursAgo));
        label = '${date.hour.toString().padLeft(2, '0')}h';
      }
    } else if (_selectedPeriod == 'Weekly') {
      // Labels at all 7 positions (0=6 days ago … 6=today)
      final daysAgo = 6 - bucketIdx;
      final date = now.subtract(Duration(days: daysAgo));
      const dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      label = dayAbbr[date.weekday - 1]; // weekday: 1=Mon … 7=Sun
    } else {
      // Monthly: labels at bucket positions 0, 7, 14, 21, 28 (every 7 buckets)
      // Bucket 0 = 29 days ago, bucket 29 = today
      if (bucketIdx % 7 == 0) {
        final daysAgo = 29 - bucketIdx;
        final date = now.subtract(Duration(days: daysAgo));
        label = DateFormat('MMM d').format(date); // e.g. "Jan 25", "Feb 1"
      }
    }

    if (label.isEmpty) return const SizedBox.shrink();

    return SideTitleWidget(
      meta: meta,
      child: Text(
        label,
        style: TextStyle(
          color: ThemeHelper.getSecondaryTextColor(context),
          fontSize: 10,
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Noise Stats',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        automaticallyImplyLeading: false,
        leading: widget.isInAppShell
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: ThemeHelper.getPrimaryColor(context)),
                  SizedBox(height: 16),
                  Text(
                    'Loading analytics...',
                    style: TextStyle(
                        color: ThemeHelper.getSecondaryTextColor(context)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time-period chips (Daily | Weekly | Monthly)
                  _buildPeriodFilterChips(),

                  const SizedBox(height: 12),

                  // Sound-type chips (All | Pollution | Ambient)
                  _buildFilterChips(),

                  const SizedBox(height: 24),

                  // Sound Type Distribution Pie Chart
                  if (_pollutionCount > 0 || _ambientCount > 0) ...[
                    _buildSoundTypePieChart(),
                    const SizedBox(height: 24),
                  ],

                  // Sound Category Breakdown
                  if (_soundTypeCounts.isNotEmpty) ...[
                    _buildSoundCategoryBreakdown(),
                    const SizedBox(height: 24),
                  ],

                  // Confidence Statistics
                  if (_avgConfidence > 0) ...[
                    _buildConfidenceCard(),
                    const SizedBox(height: 24),
                  ],

                  // Noise Trend Chart (time-period aware)
                  _buildTrendChart(),

                  const SizedBox(height: 32),

                  // Statistics grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                    children: [
                      _buildStatCard('Average', _avgDb, 'dB',
                          ThemeHelper.getPrimaryColor(context)),
                      _buildStatCard('Lowest', _minDb, 'dB', AppTheme.lowNoise),
                      _buildStatCard(
                          'Highest', _maxDb, 'dB', AppTheme.highNoise),
                      _buildStatCard(
                          'Duration', _totalHours, 'h', AppTheme.accentPurple),
                    ],
                  ),
                ],
              ),
            ),
      bottomNavigationBar: null,
    );
  }

  // ─── Period Filter Chips ─────────────────────────────────────────────────────

  Widget _buildPeriodFilterChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildPeriodChip('Daily'),
        _buildPeriodChip('Weekly'),
        _buildPeriodChip('Monthly'),
      ],
    );
  }

  Widget _buildPeriodChip(String label) {
    final isSelected = _selectedPeriod == label;
    final primaryColor = ThemeHelper.getPrimaryColor(context);
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod == label) return;
        setState(() {
          _selectedPeriod = label;
        });
        _loadStatistics();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : ThemeHelper.getSecondaryTextColor(context)
                    .withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? primaryColor
                : ThemeHelper.getSecondaryTextColor(context),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Sound Type Filter Chips ─────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildFilterChip('All'),
        _buildFilterChip('Pollution'),
        _buildFilterChip('Ambient'),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? ThemeHelper.getPrimaryColor(context)
              : ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? ThemeHelper.getPrimaryColor(context)
                : ThemeHelper.getSecondaryTextColor(context)
                    .withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : ThemeHelper.getSecondaryTextColor(context),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── Sound Type Pie Chart ────────────────────────────────────────────────────

  Widget _buildSoundTypePieChart() {
    int displayPollutionCount = _pollutionCount;
    int displayAmbientCount = _ambientCount;

    if (_selectedFilter == 'Pollution') {
      displayAmbientCount = 0;
    } else if (_selectedFilter == 'Ambient') {
      displayPollutionCount = 0;
    }

    final total = displayPollutionCount + displayAmbientCount;
    if (total == 0) return const SizedBox.shrink();

    final pollutionPercent =
        displayPollutionCount > 0 ? (displayPollutionCount / total * 100) : 0.0;
    final ambientPercent =
        displayAmbientCount > 0 ? (displayAmbientCount / total * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sound Type Distribution',
            style: TextStyle(
              color: ThemeHelper.getTextColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      if (displayPollutionCount > 0)
                        PieChartSectionData(
                          value: displayPollutionCount.toDouble(),
                          title: '${pollutionPercent.toStringAsFixed(0)}%',
                          color: AppTheme.highNoise,
                          radius: 45,
                          titleStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (displayAmbientCount > 0)
                        PieChartSectionData(
                          value: displayAmbientCount.toDouble(),
                          title: '${ambientPercent.toStringAsFixed(0)}%',
                          color: AppTheme.lowNoise,
                          radius: 45,
                          titleStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayPollutionCount > 0)
                      _buildLegendItem('Pollution', displayPollutionCount,
                          pollutionPercent, AppTheme.highNoise),
                    if (displayPollutionCount > 0 && displayAmbientCount > 0)
                      const SizedBox(height: 12),
                    if (displayAmbientCount > 0)
                      _buildLegendItem('Ambient', displayAmbientCount,
                          ambientPercent, AppTheme.lowNoise),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
      String label, int count, double percent, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: ThemeHelper.getTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$count readings (${percent.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: ThemeHelper.getSecondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Sound Category Breakdown ────────────────────────────────────────────────

  Widget _buildSoundCategoryBreakdown() {
    if (_soundTypeCounts.isEmpty) return const SizedBox.shrink();

    Map<String, int> filteredCounts = {};

    if (_selectedFilter == 'All') {
      filteredCounts = Map.from(_soundTypeCounts);
    } else {
      final pollutionCategories = [
        'Traffic',
        'Construction',
        'Industrial',
        'Tuk-tuk',
        'Speech-Pollution'
      ];
      final ambientCategories = [
        'Music',
        'Nature',
        'Speech-Ambient',
        'Religious',
        'Market'
      ];

      for (var entry in _soundTypeCounts.entries) {
        final category = entry.key;
        final count = entry.value;

        if (_selectedFilter == 'Pollution' &&
            pollutionCategories.any((c) => category.contains(c))) {
          filteredCounts[category] = count;
        } else if (_selectedFilter == 'Ambient' &&
            ambientCategories.any((c) => category.contains(c))) {
          filteredCounts[category] = count;
        }
      }
    }

    if (filteredCounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'No ${_selectedFilter.toLowerCase()} sounds in ${_getPeriodLabel().toLowerCase()}',
            style:
                TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
          ),
        ),
      );
    }

    final totalCount =
        filteredCounts.values.fold(0, (total, value) => total + value);
    final sortedEntries = filteredCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sound Categories',
            style: TextStyle(
              color: ThemeHelper.getTextColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedEntries.map((entry) {
            final category = entry.key;
            final count = entry.value;
            final percent = (count / totalCount * 100);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      category,
                      style: TextStyle(
                        color: ThemeHelper.getTextColor(context),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: ThemeHelper.isDark(context)
                                ? AppTheme.darkPurple
                                : ThemeHelper.getPrimaryColor(context)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent / 100,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: ThemeHelper.getPrimaryColor(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${percent.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ThemeHelper.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Confidence Card ─────────────────────────────────────────────────────────

  Widget _buildConfidenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified,
              color: ThemeHelper.getPrimaryColor(context),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classification Confidence',
                  style: TextStyle(
                    color: ThemeHelper.getSecondaryTextColor(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(_avgConfidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: ThemeHelper.getTextColor(context),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Trend Chart ─────────────────────────────────────────────────────────────

  Widget _buildTrendChart() {
    if (FirebaseAuth.instance.currentUser == null) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'Please log in to view trends',
            style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
          ),
        ),
      );
    }

    // Use the cached stream set by _loadStatistics().
    // If null (load failed or not yet ready), show an error state.
    final stream = _trendStream;
    if (stream == null) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'Unable to load trend data.',
            style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
          ),
        ),
      );
    }

    final maxX = _selectedPeriod == 'Daily'
        ? 23.0
        : _selectedPeriod == 'Weekly'
            ? 6.0
            : 29.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Noise Trend — ${_getPeriodLabel()}',
            style: TextStyle(
              color: ThemeHelper.getTextColor(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot>(
              stream: stream, // cached — not re-created on sound-filter taps
              builder: (context, snapshot) {
                // Show spinner while waiting for first data from Firestore.
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ThemeHelper.getPrimaryColor(context),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading chart data.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No data for ${_getPeriodLabel().toLowerCase()}.\nStart recording to see trends.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: ThemeHelper.getSecondaryTextColor(context)),
                    ),
                  );
                }

                final spots = _buildTimeAggregatedSpots(snapshot.data!.docs);

                if (spots.isEmpty) {
                  return Center(
                    child: Text(
                      'No data for ${_getPeriodLabel().toLowerCase()}.',
                      style: TextStyle(
                          color: ThemeHelper.getSecondaryTextColor(context)),
                    ),
                  );
                }

                // Dynamic maxY: 15 dB headroom above the highest reading,
                // clamped between 60 (minimum useful ceiling) and 140 dB.
                final dataMax =
                    spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                final chartMaxY = (dataMax + 15).clamp(60.0, 140.0);

                return LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1, // integer ticks only — no duplicate labels
                          getTitlesWidget: _getXAxisWidget,
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: maxX,
                    minY: 0,
                    maxY: chartMaxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: ThemeHelper.getPrimaryColor(context),
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: ThemeHelper.getPrimaryColor(context),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              ThemeHelper.getPrimaryColor(context)
                                  .withValues(alpha: 0.3),
                              ThemeHelper.getPrimaryColor(context)
                                  .withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Card ───────────────────────────────────────────────────────────────

  Widget _buildStatCard(
      String label, double value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeHelper.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${value.toStringAsFixed(0)} $unit',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: ThemeHelper.getSecondaryTextColor(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
