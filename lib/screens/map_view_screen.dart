import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/yamnet_class_mapping.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
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
  final MapController _mapController = MapController();
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _mapSearchController = TextEditingController();

  LatLng _currentLocation = const LatLng(6.9271, 79.8612); // Colombo, Sri Lanka (default)
  bool _isLoadingLocation = true;
  LatLng? _searchedLocation;

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
      _getCurrentLocation();
    }
  }

  @override
  void dispose() {
    _mapSearchController.dispose();
    super.dispose();
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

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move map to current location
      _mapController.move(_currentLocation, 13.0);
    } catch (e) {
      AppLogger.error('Error getting location', e);
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Check if user location overlaps with any noise marker
  bool _isUserLocationNearMarker(List<Marker> markers) {
    const double overlapThreshold = 100.0; // 100 meters

    for (final marker in markers) {
      final distance = Geolocator.distanceBetween(
        _currentLocation.latitude,
        _currentLocation.longitude,
        marker.point.latitude,
        marker.point.longitude,
      );

      // If any marker is within 100 meters, consider it overlapping
      if (distance <= overlapThreshold) {
        return true;
      }
    }
    return false;
  }

  // Search for location on map using geocoding
  Future<void> _searchLocationOnMap(String query) async {
    if (query.trim().isEmpty || query.trim().length < 3) {
      return;
    }

    // Capture context-dependent values before async gap
    final messenger = ScaffoldMessenger.of(context);
    final primaryColor = ThemeHelper.getPrimaryColor(context);

    try {
      AppLogger.info('Searching map for: $query');
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty && mounted) {
        Location? selectedLocation;
        if (locations.length > 1) {
          selectedLocation = await _showLocationPicker(locations);
          if (selectedLocation == null) return;
        } else {
          selectedLocation = locations.first;
        }
        final location = selectedLocation;
        final newLocation = LatLng(location.latitude, location.longitude);

        setState(() {
          _searchedLocation = newLocation;
        });

        // Animate map to searched location
        _mapController.move(newLocation, 13.0);

        AppLogger.info('Found and moved to: ${location.latitude}, ${location.longitude}');

        // Show snackbar with location info
        messenger.showSnackBar(
          SnackBar(
            content: Text('Found: $query'),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Map search failed', e);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Location not found'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Show picker when search returns multiple locations
  Future<Location?> _showLocationPicker(List<Location> locations) async {
    return showModalBottomSheet<Location>(
      context: context,
      backgroundColor: ThemeHelper.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeHelper.getTextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            ...locations.take(5).map(
              (loc) => ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: ThemeHelper.getPrimaryColor(context),
                ),
                title: Text(
                  '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
                  style: TextStyle(color: ThemeHelper.getTextColor(context)),
                ),
                subtitle: Text(
                  'Result ${locations.indexOf(loc) + 1}',
                  style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                ),
                onTap: () => Navigator.pop(context, loc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.getNoiseReadings(),
        builder: (context, snapshot) {
          // Build markers from Firebase data
          List<Marker> noiseMarkers = [];

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            noiseMarkers = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final lat = data['latitude'] as double;
              final lng = data['longitude'] as double;
              final db = (data['decibelLevel'] as num).toDouble();
              final location = data['locationName'] as String? ?? 'Unknown';

              // Handle classification fields (check for both null and empty strings)
              final soundClassRaw = data['soundClass'] as String?;
              final soundTypeRaw = data['soundType'] as String?;
              final soundClass = (soundClassRaw != null && soundClassRaw.isNotEmpty) ? soundClassRaw : null;
              final soundType = (soundTypeRaw != null && soundTypeRaw.isNotEmpty) ? soundTypeRaw : null;
              final confidence = data['confidence'] as double?;

              // Debug: Log if classification is missing (helps identify old recordings)
              if (soundClass == null) {
                AppLogger.debug('Marker at $location has no classification data (likely old recording)');
              }

              return Marker(
                point: LatLng(lat, lng),
                width: 60,
                height: 70,
                child: GestureDetector(
                  onTap: () => _showMarkerDetailsFromData(
                    location, db, lat, lng,
                    soundClass: soundClass,
                    soundType: soundType,
                    confidence: confidence,
                  ),
                  child: _buildNoiseMarker(db, location, soundClass: soundClass),
                ),
              );
            }).toList();
          }

          return Stack(
            children: [
              // Map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentLocation,
                  initialZoom: 11.0,
                  minZoom: 5.0,
                  maxZoom: 18.0,
                  onPositionChanged: (position, hasGesture) {
                    // Save position when user pans/zooms
                    if (hasGesture) {
                      _saveMapPosition(position.center, position.zoom);
                    }
                  },
                ),
                children: [
                  // Map tiles
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.noisemapper.noise_pollution_mapper',
                  ),

                  // Noise markers from Firebase
                  if (noiseMarkers.isNotEmpty)
                    MarkerLayer(markers: noiseMarkers),

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
                      point: _searchedLocation!,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.searchedLocationName ?? _mapSearchController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Search bar at top
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? ThemeHelper.getCardColor(context) : AppTheme.lightCardBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: isDark ? AppTheme.textGray : AppTheme.textLightGray),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _mapSearchController,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(
                              color: isDark ? ThemeHelper.getTextColor(context) : AppTheme.textDark,
                              fontSize: 16,
                              height: 1.2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search location on map...',
                              hintStyle: TextStyle(
                                color: isDark ? AppTheme.textGray : AppTheme.textLightGray,
                                height: 1.2,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              suffixIcon: _mapSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: isDark ? AppTheme.textGray : AppTheme.textLightGray),
                                      onPressed: () {
                                        _mapSearchController.clear();
                                        setState(() {
                                          _searchedLocation = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (value) {
                              _searchLocationOnMap(value);
                            },
                            onChanged: (value) {
                              setState(() {}); // To show/hide clear button
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SearchListScreen(),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.history,
                            color: isDark ? AppTheme.textGray : AppTheme.textLightGray,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Current location button (moves higher if overlapping with noise marker)
          Positioned(
            bottom: _isUserLocationNearMarker(noiseMarkers) ? 180 : 100,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: ThemeHelper.getPrimaryColor(context),
              onPressed: () {
                _mapController.move(_currentLocation, 13.0);
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
            ],
          );
        },
      ),
      bottomNavigationBar: null,
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
                ? Color(YAMNetClassMapping.getCategoryColor(soundClass))
                    .withValues(alpha: 0.9)
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
                style: const TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 12,
                ),
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
                style: const TextStyle(
                  color: AppTheme.textGray,
                  fontSize: 16,
                ),
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
