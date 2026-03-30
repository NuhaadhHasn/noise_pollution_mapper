import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math show pi, cos, sin, asin, sqrt;
import 'dart:ui' as ui show Paint, Path, Offset, MaskFilter, BlurStyle, PaintingStyle, Size, Rect;
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/yamnet_class_mapping.dart';
import '../services/heatmap_service.dart';
import '../models/heatmap_point.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/heatmap_fab.dart';
import 'search_list_screen.dart';

class MapViewScreen extends StatefulWidget {
  final LatLng? initialLocation;
  final String? searchedLocationName;
  final bool isInAppShell;

  const MapViewScreen({
    super.key,
    this.initialLocation,
    this.searchedLocationName,
    this.isInAppShell = false,
  });

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  // ── Change this one value to control how many readings markers + heatmap load ──
  static const int _kMapReadingLimit = 100;

  final MapController _mapController = MapController();
  final FirebaseService _firebaseService = FirebaseService();
  final HeatmapService _heatmapService = HeatmapService();
  final TextEditingController _mapSearchController = TextEditingController();

  LatLng _currentLocation = const LatLng(
    6.9271,
    79.8612,
  ); // Colombo, Sri Lanka (default)
  bool _isLoadingLocation = true;
  LatLng? _searchedLocation;

  // Search results with names (from )
  List<Map<String, dynamic>> _searchResults = [];

  // FIXED: Cache for markers to avoid rebuilding on every frame
  List<Marker> _cachedMarkers = [];
  bool _isLoadingMarkers = false;

  // Store noise levels for cluster coloring
  final Map<String, double> _markerNoiseLevels = {};

  // Heatmap state variables
  bool _showHeatmap = false;
  List<HeatmapPoint> _heatmapPoints = [];
  final double _heatmapOpacity = 0.7;

  // Incremented on bare-map tap to collapse any open cluster spiderfy
  int _clusterRebuildKey = 0;

  @override
  void initState() {
    super.initState();
    // If initial location provided (from search), use it
    if (widget.initialLocation != null) {
      setState(() {
        _currentLocation = widget.initialLocation!;
        _isLoadingLocation = false;
        _searchedLocation = widget.initialLocation!;
      });
      // Set the search text if provided
      if (widget.searchedLocationName != null) {
        _mapSearchController.text = widget.searchedLocationName!;
      }
      // Move map to searched location after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.initialLocation!, 13.0);
      });
    } else {
      _loadSavedMapPosition(); // Load last map position
      // DON'T auto-request location here - Dashboard already requested permission on app startup
      // User can tap location FAB button to get current location if needed
      setState(() {
        _isLoadingLocation = false;
      });
    }
    // Load markers once on startup (heatmap reuses the same snapshot)
    _loadNoiseMarkers();
  }

  @override
  void dispose() {
    _mapSearchController.dispose();
    super.dispose();
  }

  // Public method to navigate to a location (called from MainAppShell)
  void navigateToLocation(LatLng location, String locationName) {
    AppLogger.info('Navigating to location: $locationName');
    setState(() {
      _currentLocation = location;
      _searchedLocation = location;
    });
    _mapController.move(location, 13.0);
    _mapSearchController.text = locationName;
  }

  // Load markers AND heatmap points from the same single Firestore query.
  // Both always show identical data. To change the limit, update _kMapReadingLimit above.
  Future<void> _loadNoiseMarkers() async {
    if (_isLoadingMarkers) return;

    setState(() {
      _isLoadingMarkers = true;
    });

    try {
      final snapshot = await _firebaseService.getNoiseReadingsOnce(
        limit: _kMapReadingLimit,
      );
      final markers = _buildMarkersFromSnapshot(snapshot);
      final heatmapPoints = _heatmapService.convertToHeatmapPoints(snapshot);

      if (mounted) {
        setState(() {
          _cachedMarkers = markers;
          _heatmapPoints = heatmapPoints;
          _isLoadingMarkers = false;
        });
        AppLogger.info(
          '[Map] Loaded ${markers.length} markers + ${heatmapPoints.length} '
          'heatmap points (limit: $_kMapReadingLimit)',
        );
      }
    } catch (e) {
      AppLogger.error('Error loading map data', e);
      if (mounted) {
        setState(() {
          _isLoadingMarkers = false;
        });
      }
    }
  }

  // Refresh both markers and heatmap (single query, for pull-to-refresh)
  Future<void> _refreshAllData() async {
    await _loadNoiseMarkers();
  }

  // FIXED: Build markers from cached snapshot (extracted for reusability)
  List<Marker> _buildMarkersFromSnapshot(QuerySnapshot? snapshot) {
    List<Marker> markers = [];

    // Clear previous noise levels
    _markerNoiseLevels.clear();

    if (snapshot == null || snapshot.docs.isEmpty) {
      return markers;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'] as double;
      final lng = data['longitude'] as double;
      final db = (data['decibelLevel'] as num).toDouble();
      final location = data['locationName'] as String? ?? 'Unknown';

      // Handle classification fields (check for both null and empty strings)
      final soundClassRaw = data['soundClass'] as String?;
      final soundTypeRaw = data['soundType'] as String?;
      final soundClass = (soundClassRaw != null && soundClassRaw.isNotEmpty)
          ? soundClassRaw
          : null;
      final soundType = (soundTypeRaw != null && soundTypeRaw.isNotEmpty)
          ? soundTypeRaw
          : null;
      final confidence = data['confidence'] as double?;

      // Debug: Log if classification is missing (helps identify old recordings)
      if (soundClass == null) {
        AppLogger.debug(
          'Marker at $location has no classification data (likely old recording)',
        );
      }

      // Store noise level for cluster coloring
      final markerKey = '${lat}_$lng';
      _markerNoiseLevels[markerKey] = db;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 60,
          height: 70,
          child: GestureDetector(
            onTap: () => _showMarkerDetailsFromData(
              location,
              db,
              lat,
              lng,
              soundClass: soundClass,
              soundType: soundType,
              confidence: confidence,
            ),
            child: _buildNoiseMarker(db, location, soundClass: soundClass),
          ),
        ),
      );
    }

    return markers;
  }

  // Load saved map position from cache
  Future<void> _loadSavedMapPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLat = prefs.getDouble('map_last_lat');
      final savedLng = prefs.getDouble('map_last_lng');
      final savedZoom = prefs.getDouble('map_last_zoom');

      if (savedLat != null && savedLng != null) {
        setState(() {
          _currentLocation = LatLng(savedLat, savedLng);
        });
        // Move map to saved position
        if (savedZoom != null) {
          _mapController.move(_currentLocation, savedZoom);
        }
      }
    } catch (e) {
      AppLogger.error('Error loading map position', e);
    }
  }

  // Save current map position
  Future<void> _saveMapPosition(LatLng position, double zoom) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('map_last_lat', position.latitude);
      await prefs.setDouble('map_last_lng', position.longitude);
      await prefs.setDouble('map_last_zoom', zoom);
    } catch (e) {
      AppLogger.error('Error saving map position', e);
    }
  }

  // Location request debouncing to prevent duplicate dialogs
  bool _isGettingLocation = false;
  DateTime? _lastLocationRequestTime;
  static const Duration _locationRequestDebounce = Duration(seconds: 30);

  Future<void> _getCurrentLocation({bool forceRefresh = false}) async {
    // Prevent concurrent location requests (unless force refresh)
    if (!forceRefresh && _isGettingLocation) {
      AppLogger.debug('Map: Location request already in progress, skipping');
      return;
    }

    // Debounce rapid requests (except for force refresh)
    if (!forceRefresh) {
      final now = DateTime.now();
      if (_lastLocationRequestTime != null &&
          now.difference(_lastLocationRequestTime!) <
              _locationRequestDebounce) {
        AppLogger.debug('Map: Location request debounced (too soon)');
        return;
      }
    }

    _isGettingLocation = true;
    _lastLocationRequestTime = DateTime.now();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
          });
        }
        _isGettingLocation = false;
        // Show native Android location settings dialog
        _showNativeLocationDialog();
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Move map to current location
        _mapController.move(_currentLocation, 13.0);
      }
    } catch (e) {
      AppLogger.error('Map: Error getting location', e);
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } finally {
      _isGettingLocation = false;
    }
  }

  // Show native Android location settings dialog
  Future<void> _showNativeLocationDialog() async {
    if (!mounted) return;

    AppLogger.info('Map: 🔵 Showing native location dialog...');

    try {
      // This shows the native Android location settings dialog
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      await Geolocator.getCurrentPosition(locationSettings: locationSettings);

      // If user enabled location and we got position, refresh location
      if (mounted) {
        AppLogger.info('Map: ✅ User enabled location, refreshing...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _getCurrentLocation(forceRefresh: true);
      }
    } catch (e) {
      // User declined or dialog closed without enabling
      AppLogger.debug('Map: User declined to enable location services');
    }
  }

  // Nominatim (OpenStreetMap) API search - returns proper location names
  Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    try {
      // FIXED: Increased limit to 50 to get more results for partial queries
      // Use viewbox to bias results towards Sri Lanka area
      // Sri Lanka bounds: lat 5.9-9.9, lon 79.5-82.0
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=50&addressdetails=1&viewbox=79.5,5.9,82.0,9.9&bounded=0',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NoiseMapper/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        AppLogger.info(
          'Nominatim search "$query": found ${data.length} results',
        );
        AppLogger.info(
          'Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}',
        );

        final results = data
            .map(
              (item) => {
                'name': item['display_name'] ?? 'Unknown',
                'lat': double.parse(item['lat']),
                'lon': double.parse(item['lon']),
                'country': (item['address']?['country'] ?? '')
                    .toString()
                    .toLowerCase(),
              },
            )
            .toList();

        // Prioritize Sri Lanka results (keep them at top)
        final sriLankaResults = results
            .where(
              (r) => r['country'] == 'sri lanka' || r['country'] == 'srilanka',
            )
            .toList();

        final otherResults = results
            .where(
              (r) => r['country'] != 'sri lanka' && r['country'] != 'srilanka',
            )
            .toList();

        // Sort Sri Lanka results by distance from current location (nearest first)
        sriLankaResults.sort((a, b) {
          final latA = a['lat'] as double;
          final lonA = a['lon'] as double;
          final latB = b['lat'] as double;
          final lonB = b['lon'] as double;

          final distA = _calculateDistance(
            _currentLocation.latitude,
            _currentLocation.longitude,
            latA,
            lonA,
          );
          final distB = _calculateDistance(
            _currentLocation.latitude,
            _currentLocation.longitude,
            latB,
            lonB,
          );

          return distA.compareTo(distB);
        });

        // Sort other results by distance too
        otherResults.sort((a, b) {
          final latA = a['lat'] as double;
          final lonA = a['lon'] as double;
          final latB = b['lat'] as double;
          final lonB = b['lon'] as double;

          final distA = _calculateDistance(
            _currentLocation.latitude,
            _currentLocation.longitude,
            latA,
            lonA,
          );
          final distB = _calculateDistance(
            _currentLocation.latitude,
            _currentLocation.longitude,
            latB,
            lonB,
          );

          return distA.compareTo(distB);
        });

        // Log top results for debugging
        final allResults = [...sriLankaResults, ...otherResults];
        for (var i = 0; i < allResults.length && i < 5; i++) {
          AppLogger.info(
            'Result #${i + 1}: ${allResults[i]['name']} (${allResults[i]['country']})',
          );
        }

        // Return Sri Lanka results first (sorted by distance), then others
        return allResults;
      }
    } catch (e) {
      AppLogger.error('Nominatim search failed', e);
    }
    return [];
  }

  // Calculate distance between two coordinates (in kilometers)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  // Autocomplete search - called as user types (USES NOMINATIM API)
  Future<void> _autocompleteSearch(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      // Search using Nominatim API (returns proper location names)
      final results = await _searchNominatim(query);

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      AppLogger.error('Autocomplete search failed', e);
      setState(() {
        _searchResults = [];
      });
    }
  }

  // Search for location on map using Nominatim
  Future<void> _searchLocationOnMap(String query) async {
    if (query.trim().isEmpty || query.trim().length < 3) {
      return;
    }

    // Capture context-dependent values before async gap
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = ThemeHelper.getPrimaryColor(context);

    try {
      AppLogger.info('Searching map for: $query');

      // Search using Nominatim API
      final results = await _searchNominatim(query);

      if (results.isNotEmpty && mounted) {
        // Use first result
        final location = results.first;
        final newLocation = LatLng(
          location['lat'] as double,
          location['lon'] as double,
        );

        setState(() {
          _searchedLocation = newLocation;
        });

        // Animate map to searched location
        _mapController.move(newLocation, 13.0);

        AppLogger.info('Found and moved to: ${location['name']}');

        // Show snackbar with location name
        messenger.showSnackBar(
          SnackBar(
            content: Text('Found: ${location['name']}'),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // No results found
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Location not found. Try a different search term.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Map search failed', e);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location not found.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    // Status bar color: Match navbar (dark purple in dark mode, primary color in light mode)
    final statusBarColor = isDark
        ? AppTheme.darkPurple
        : ThemeHelper.getPrimaryColor(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: Brightness.light, // White icons for both modes
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: ThemeHelper.getBackgroundColor(context),
        // FIXED: Pull-to-refresh instead of continuous StreamBuilder listening
        body: RefreshIndicator(
          onRefresh: () async {
            AppLogger.info('Pull-to-refresh: Reloading markers and heatmap...');
            await _refreshAllData();
          },
          child: Stack(
            children: [
              // Sync status indicator (top-right corner)
              Positioned(
                top: 40,
                right: 10,
                child: const SyncStatusIndicator(),
              ),

              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 11.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                  onTap: (tapPosition, latLng) {
                    // Collapse any open cluster spiderfy when user taps bare map
                    setState(() {
                      _clusterRebuildKey++;
                    });
                  },
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      _saveMapPosition(position.center, position.zoom);
                    }
                  },
                ),
                children: [
                  // 1) Map tiles (bottom)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.noisemapper.noise_pollution_mapper',
                  ),

                  // 2) Heatmap layer — above tiles, below markers
                  //    Uses MapCamera.of(context) for pixel-perfect alignment
                  if (_showHeatmap && _heatmapPoints.isNotEmpty)
                    HeatmapLayer(
                      heatmapPoints: _heatmapPoints,
                      opacity: _heatmapOpacity,
                    ),

                  // 3) Noise markers with clustering (on top of heatmap)
                  if (_cachedMarkers.isNotEmpty)
                    MarkerClusterLayerWidget(
                      key: ValueKey(_clusterRebuildKey),
                      options: MarkerClusterLayerOptions(
                        // Cluster appearance
                        maxClusterRadius: 50,
                        // Cluster markers within 50 pixels
                        size: const Size(40, 40),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(50),

                        // Clustering behavior
                        maxZoom: 17,
                        // Allow clustering up to zoom 17 (street level!)
                        disableClusteringAtZoom: 18,
                        // Show individual markers only at zoom 18+

                        // Spiderfy spacing (when cluster is clicked)
                        spiderfyCircleRadius: 75,
                        // Try 65px - more than 55 (too close) but less than 80 (too far)
                        spiderfySpiralDistanceMultiplier: 1,
                        // Keep at 1 (int only, can't use decimals)
                        circleSpiralSwitchover: 7,
                        // Switch to spiral at 7+ markers (was 9)

                        // Simple cluster builder
                        builder: (context, markers) {
                          // Extract noise levels for this cluster
                          final clusterNoiseLevels = markers.map((marker) {
                            final point = marker.point;
                            final key = _markerNoiseLevels.keys.firstWhere(
                              (k) => k.startsWith(
                                '$point.latitude_$point.longitude',
                              ),
                              orElse: () => '',
                            );
                            return key.isNotEmpty
                                ? _markerNoiseLevels[key]!
                                : 50.0;
                          }).toList();

                          // Calculate average noise level for cluster color
                          final avgNoise = clusterNoiseLevels.isEmpty
                              ? 50.0
                              : clusterNoiseLevels.reduce((a, b) => a + b) /
                                    clusterNoiseLevels.length;

                          // Determine cluster color based on average noise
                          Color clusterColor;
                          if (avgNoise < 50) {
                            clusterColor = AppTheme.lowNoise; // Green
                          } else if (avgNoise < 70) {
                            clusterColor = AppTheme.moderateNoise; // Orange
                          } else {
                            clusterColor = AppTheme.highNoise; // Red
                          }

                          // Make cluster visually distinct from individual markers
                          // Use a pin/marker shape instead of circle
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pin shape
                              CustomPaint(
                                painter: ClusterPinPainter(clusterColor),
                                size: const Size(50, 60),
                              ),
                              // Number centered in white circle
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  markers.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },

                        // Markers to cluster
                        markers: _cachedMarkers,
                      ),
                    ),

                  // Current location marker
                  if (!_isLoadingLocation)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThemeHelper.getPrimaryColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Searched location marker
                  if (_searchedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThemeHelper.getPrimaryColor(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Searched location marker
                  if (_searchedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _searchedLocation!,
                          width: 60,
                          height: 70,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.searchedLocationName ??
                                      _mapSearchController.text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  // Loading indicator for markers
                  if (_isLoadingMarkers)
                    Center(
                      child: CircularProgressIndicator(
                        color: ThemeHelper.getPrimaryColor(context),
                      ),
                    ),
                ],
              ),

              // Search bar at top with autocomplete dropdown
              SafeArea(
                top: true,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      return Column(
                        children: [
                          // Search bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ThemeHelper.getCardColor(context)
                                  : AppTheme.lightCardBackground,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.3 : 0.1,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: isDark
                                      ? AppTheme.textGray
                                      : AppTheme.textLightGray,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _mapSearchController,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? ThemeHelper.getTextColor(context)
                                          : AppTheme.textDark,
                                      fontSize: 16,
                                      height: 1.2,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search location on map...',
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? AppTheme.textGray
                                            : AppTheme.textLightGray,
                                        height: 1.2,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                      suffixIcon:
                                          _mapSearchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: isDark
                                                    ? AppTheme.textGray
                                                    : AppTheme.textLightGray,
                                              ),
                                              onPressed: () {
                                                _mapSearchController.clear();
                                                setState(() {
                                                  _searchedLocation = null;
                                                  _searchResults = [];
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                    onSubmitted: (value) {
                                      _searchLocationOnMap(value);
                                    },
                                    onChanged: (value) {
                                      _autocompleteSearch(value);
                                    },
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SearchListScreen(),
                                      ),
                                    );

                                    // If location was selected, navigate to it
                                    if (result != null &&
                                        result is Map<String, dynamic>) {
                                      final lat = result['lat'] as double;
                                      final lon = result['lon'] as double;
                                      final name = result['name'] as String;
                                      navigateToLocation(
                                        LatLng(lat, lon),
                                        name,
                                      );
                                    }
                                  },
                                  child: Icon(
                                    Icons.history,
                                    color: isDark
                                        ? AppTheme.textGray
                                        : AppTheme.textLightGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Autocomplete dropdown results
                          if (_searchResults.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ThemeHelper.getCardColor(context)
                                    : AppTheme.lightCardBackground,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxHeight: 250),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final location = _searchResults[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.location_on,
                                      color: ThemeHelper.getPrimaryColor(
                                        context,
                                      ),
                                    ),
                                    title: Text(
                                      location['name'] as String,
                                      style: TextStyle(
                                        color: ThemeHelper.getTextColor(
                                          context,
                                        ),
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${(location['lat'] as double).toStringAsFixed(4)}, ${(location['lon'] as double).toStringAsFixed(4)}',
                                      style: TextStyle(
                                        color:
                                            ThemeHelper.getSecondaryTextColor(
                                              context,
                                            ),
                                        fontSize: 12,
                                      ),
                                    ),
                                    onTap: () {
                                      final newLocation = LatLng(
                                        location['lat'] as double,
                                        location['lon'] as double,
                                      );
                                      setState(() {
                                        _searchedLocation = newLocation;
                                        _searchResults = [];
                                        _mapSearchController.clear();
                                      });
                                      _mapController.move(newLocation, 13.0);
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Current location button (positioned just above navbar)
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heatmap FAB (toggles heatmap on/off)
                    HeatmapFab(
                      showHeatmap: _showHeatmap,
                      onTap: () {
                        setState(() {
                          _showHeatmap = !_showHeatmap;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Location button
                    FloatingActionButton(
                      heroTag: 'map_location_btn',
                      backgroundColor: ThemeHelper.getPrimaryColor(context),
                      onPressed: () async {
                        await _getCurrentLocation(forceRefresh: true);
                        _mapController.move(_currentLocation, 13.0);
                      },
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: null,
      ),
    );
  }

  // Build noise marker with color coding and sound type badge
  Widget _buildNoiseMarker(double db, String city, {String? soundClass}) {
    Color markerColor;
    if (db < 50) {
      markerColor = AppTheme.lowNoise; // Green
    } else if (db < 70) {
      markerColor = AppTheme.moderateNoise; // Orange
    } else {
      markerColor = AppTheme.highNoise; // Red
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: markerColor.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${db.toInt()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // ALWAYS show classification badge - use default icon if no classification
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: soundClass != null
                ? Color(
                    YAMNetClassMapping.getCategoryColor(soundClass),
                  ).withValues(alpha: 0.9)
                : Colors.grey.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            soundClass != null
                ? YAMNetClassMapping.getCategoryIcon(soundClass)
                : '🔊', // Default sound icon for unclassified recordings
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Show marker details from Firebase data
  void _showMarkerDetailsFromData(
    String location,
    double db,
    double lat,
    double lng, {
    String? soundClass,
    String? soundType,
    double? confidence,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeHelper.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                location,
                style: TextStyle(
                  color: ThemeHelper.getTextColor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                style: const TextStyle(color: AppTheme.textGray, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(
                '${db.toStringAsFixed(0)} dB',
                style: TextStyle(
                  color: _getNoiseColor(db),
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getNoiseLevel(db),
                style: const TextStyle(color: AppTheme.textGray, fontSize: 16),
              ),
              // ALWAYS show sound classification section (with N/A for missing data)
              const SizedBox(height: 16),
              const Divider(color: AppTheme.textGray),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    soundClass != null
                        ? YAMNetClassMapping.getCategoryIcon(soundClass)
                        : '🔊', // Default icon for unclassified
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soundClass ?? 'Unclassified',
                        style: TextStyle(
                          color: ThemeHelper.getTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: soundType == null
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : soundType == 'Pollution'
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: soundType == null
                                    ? Colors.grey
                                    : soundType == 'Pollution'
                                    ? Colors.red
                                    : Colors.green,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              soundType ?? 'N/A',
                              style: TextStyle(
                                color: soundType == null
                                    ? Colors.grey
                                    : soundType == 'Pollution'
                                    ? Colors.red
                                    : Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            confidence != null
                                ? '${(confidence * 100).toStringAsFixed(1)}%'
                                : 'N/A',
                            style: const TextStyle(
                              color: AppTheme.textGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getNoiseColor(double db) {
    if (db < 50) return AppTheme.lowNoise;
    if (db < 70) return AppTheme.moderateNoise;
    return AppTheme.highNoise;
  }

  String _getNoiseLevel(double db) {
    if (db < 50) return 'Low Noise - Safe';
    if (db < 70) return 'Moderate Noise';
    return 'High Noise - Dangerous!';
  }
}

// Custom painter for cluster pin/marker shape
class ClusterPinPainter extends CustomPainter {
  final Color color;

  ClusterPinPainter(this.color);

  @override
  void paint(Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill;

    final borderPaint = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw teardrop/pin shape
    final path = ui.Path();
    final width = size.width;
    final height = size.height;

    // Center point
    final centerX = width / 2;
    final centerY = height * 0.35; // Center of the bulb
    final bulbRadius = width * 0.42;

    // Draw the bulb (top circle)
    path.addOval(
      ui.Rect.fromCircle(
        center: ui.Offset(centerX, centerY),
        radius: bulbRadius,
      ),
    );

    // Draw the pointed bottom
    path.moveTo(centerX - bulbRadius * 0.3, centerY + bulbRadius * 0.5);
    path.cubicTo(
      centerX - bulbRadius * 0.5, centerY + bulbRadius * 0.8,
      centerX - bulbRadius * 0.2, height,
      centerX, height,
    );
    path.cubicTo(
      centerX + bulbRadius * 0.2, height,
      centerX + bulbRadius * 0.5, centerY + bulbRadius * 0.8,
      centerX + bulbRadius * 0.3, centerY + bulbRadius * 0.5,
    );

    // Draw shadow
    final shadowPaint = ui.Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = ui.PaintingStyle.fill
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3);
    
    final shadowPath = ui.Path()..addPath(path, const ui.Offset(0, 2));
    canvas.drawPath(shadowPath, shadowPaint);

    // Draw pin
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Draw white circle in center for number background
    final centerCircle = ui.Paint()
      ..color = Colors.white
      ..style = ui.PaintingStyle.fill;
    
    canvas.drawCircle(
      ui.Offset(centerX, centerY),
      bulbRadius * 0.65,
      centerCircle,
    );
  }

  @override
  bool shouldRepaint(covariant ClusterPinPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Flutter-map layer widget that uses MapCamera.of(context) for pixel-perfect
/// heatmap alignment — the same camera and projection that TileLayer uses.
class HeatmapLayer extends StatelessWidget {
  final List<HeatmapPoint> heatmapPoints;
  final double opacity;

  const HeatmapLayer({
    super.key,
    required this.heatmapPoints,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    // camera.nonRotatedSize is the actual pixel dimensions of the map viewport.
    // We compute absolute screen positions here (from top-left = 0,0) so the
    // painter never needs to know about the canvas size.
    final centerWorld = camera.project(camera.center);
    final halfW = camera.nonRotatedSize.x / 2;
    final halfH = camera.nonRotatedSize.y / 2;

    final screenPoints = <(Offset, double)>[];
    for (final point in heatmapPoints) {
      final worldPt = camera.project(LatLng(point.latitude, point.longitude));
      screenPoints.add((
        Offset(
          halfW + (worldPt.x - centerWorld.x),
          halfH + (worldPt.y - centerWorld.y),
        ),
        point.intensity,
      ));
    }

    // SizedBox.expand() is required — without it, CustomPaint gets Size.zero
    // from the FlutterMap Stack's loose constraints, misplacing all blobs.
    return SizedBox.expand(
      child: CustomPaint(
        painter: HeatmapPainter(screenPoints: screenPoints, opacity: opacity),
      ),
    );
  }
}

/// Draws pre-projected heatmap points onto the canvas.
/// screenPoints are ABSOLUTE pixel positions from the viewport top-left (0, 0).
class HeatmapPainter extends CustomPainter {
  final List<(Offset, double)> screenPoints; // (absolute screen pos, intensity)
  final double opacity;

  const HeatmapPainter({required this.screenPoints, required this.opacity});

  static final _gradientColors = <double, Color>{
    0.0: const Color(0xFF4CAF50), // Green  — quiet   (<50 dB)
    0.4: const Color(0xFFFFEB3B), // Yellow — moderate (~50–70 dB)
    0.6: const Color(0xFFFF9800), // Orange — loud     (~70–85 dB)
    1.0: const Color(0xFFF44336), // Red    — very loud (>85 dB)
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final (screenPos, intensity) in screenPoints) {
      // Skip points outside the visible area (with a small margin for blur)
      if (screenPos.dx < -60 || screenPos.dx > size.width + 60 ||
          screenPos.dy < -60 || screenPos.dy > size.height + 60) {
        continue;
      }

      final color = _colorForIntensity(intensity);
      final paint = Paint()
        ..color = color.withValues(
            alpha: (opacity * (0.35 + 0.55 * intensity)).clamp(0.0, 0.9))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

      canvas.drawCircle(screenPos, 30.0 * (0.5 + intensity), paint);
    }
  }

  Color _colorForIntensity(double intensity) {
    final keys = _gradientColors.keys.toList()..sort();
    for (int i = 0; i < keys.length - 1; i++) {
      if (intensity >= keys[i] && intensity <= keys[i + 1]) {
        final t = (intensity - keys[i]) / (keys[i + 1] - keys[i]);
        return Color.lerp(_gradientColors[keys[i]]!, _gradientColors[keys[i + 1]]!, t)!;
      }
    }
    if (intensity < keys.first) {
      return _gradientColors[keys.first]!;
    }
    return _gradientColors[keys.last]!;
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter old) =>
      old.opacity != opacity || old.screenPoints.length != screenPoints.length;
}
