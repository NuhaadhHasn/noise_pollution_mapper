import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import '../services/firebase_service.dart';
import '../utils/app_logger.dart';

class SearchListScreen extends StatefulWidget {
  const SearchListScreen({super.key});

  @override
  State<SearchListScreen> createState() => _SearchListScreenState();
}

class _SearchListScreenState extends State<SearchListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _sortBy = 'noise'; // 'noise' or 'name'

  // Nominatim API search results
  List<Map<String, dynamic>> _nominatimResults = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search using Nominatim API (OpenStreetMap)
  Future<void> _searchWithNominatim(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      setState(() {
        _nominatimResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      AppLogger.info('Nominatim search for: $query');
      
      // Use Nominatim API with 50 results limit
      // Bias towards Sri Lanka but include worldwide results
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=50&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NoiseMapper/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (mounted) {
          setState(() {
            _nominatimResults = data
                .map(
                  (item) => {
                    'name': item['display_name'] ?? 'Unknown',
                    'lat': double.parse(item['lat']),
                    'lon': double.parse(item['lon']),
                    'type': item['type'] ?? 'place',
                    'importance': item['importance'] ?? 0.5,
                  },
                )
                .toList();
            _isSearching = false;
          });
          AppLogger.info('Found ${_nominatimResults.length} results for: $query');
        }
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Nominatim search failed', e);
      if (mounted) {
        setState(() {
          _nominatimResults = [];
          _isSearching = false;
          _searchError = 'Search failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: Text('Search Cities'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
        actions: [
          // Sort menu - white icon to match AppBar
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: AppTheme.textWhite),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'noise',
                child: Text('Sort by Noise Level'),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Text('Sort by Name'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (fixed height)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: ThemeHelper.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'Enter cities...',
                hintStyle: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                prefixIcon: Icon(Icons.search, color: ThemeHelper.getSecondaryTextColor(context)),
                filled: true,
                fillColor: ThemeHelper.getCardColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
                // Trigger search after user stops typing (debounce)
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (value == _searchQuery) {
                    _searchWithNominatim(value);
                  }
                });
              },
              onSubmitted: (value) {
                // Immediate search on submit
                _searchWithNominatim(value);
              },
            ),
          ),

          // Global Search Results Section (scrollable, constrained height)
          if (_searchQuery.isNotEmpty && _searchQuery.length >= 3)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4, // Max 40% of screen
              ),
              child: _buildGlobalSearchSection(),
            ),

          // Section Header (fixed height)
          if (_searchQuery.isNotEmpty && _searchQuery.length >= 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Cities with Recordings',
                style: TextStyle(
                  color: ThemeHelper.getTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // City grid (takes remaining space)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.getNoiseReadings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: ThemeHelper.getPrimaryColor(context)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context)),
                    ),
                  );
                }

                // Group readings by city and calculate averages
                final cityData = _processCityData(snapshot.data!.docs);

                // Filter by search query (improved partial matching)
                final filteredCities = cityData.entries.where((entry) {
                  final cityName = entry.key.toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  // Match if city name contains query or query contains city name
                  return cityName.contains(query) || query.contains(cityName);
                }).toList();

                // Show helpful message if no cities found
                if (filteredCities.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty ? Icons.location_off : Icons.search_off,
                          size: 64,
                          color: ThemeHelper.getSecondaryTextColor(context).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No cities with valid data'
                              : 'No cities match "$_searchQuery"',
                          style: TextStyle(
                            color: ThemeHelper.getTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Start recording in different locations\nto build city data'
                              : 'Try a different search term',
                          style: TextStyle(
                            color: ThemeHelper.getSecondaryTextColor(context),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Sort
                if (_sortBy == 'noise') {
                  filteredCities.sort((a, b) => b.value['avgDb'].compareTo(a.value['avgDb']));
                } else {
                  filteredCities.sort((a, b) => a.key.compareTo(b.key));
                }

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final cityName = filteredCities[index].key;
                    final data = filteredCities[index].value;

                    return _buildCityCard(
                      cityName,
                      data['avgDb'],
                      data['count'],
                      data['maxDb'],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build global search results section
  Widget _buildGlobalSearchSection() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ThemeHelper.getPrimaryColor(context),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching worldwide...',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchError != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _searchError!,
                style: TextStyle(color: Colors.orange[300], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (_nominatimResults.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Results (Tap to view on map)',
              style: TextStyle(
                color: ThemeHelper.getTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: _nominatimResults.length,
                itemBuilder: (context, index) {
                  final result = _nominatimResults[index];
                  return _buildGlobalSearchResultCard(result, index);
                },
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Build individual global search result card
  Widget _buildGlobalSearchResultCard(Map<String, dynamic> result, int index) {
    final name = result['name'] as String;
    final lat = result['lat'] as double;
    final lon = result['lon'] as double;
    final type = result['type'] as String;
    
    // Get icon based on place type
    IconData typeIcon = Icons.location_on;
    if (type == 'city' || type == 'town' || type == 'village') {
      typeIcon = Icons.location_city;
    } else if (type == 'road' || type == 'street') {
      typeIcon = Icons.route;
    } else if (type == 'park' || type == 'forest') {
      typeIcon = Icons.park;
    } else if (type == 'water' || type == 'river' || type == 'lake') {
      typeIcon = Icons.water;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            typeIcon,
            color: ThemeHelper.getPrimaryColor(context),
            size: 24,
          ),
        ),
        title: Text(
          name.split(',').take(2).join(', '), // Show first 2 parts of name
          style: TextStyle(
            color: ThemeHelper.getTextColor(context),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}',
          style: TextStyle(
            color: ThemeHelper.getSecondaryTextColor(context),
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: ThemeHelper.getPrimaryColor(context),
          size: 16,
        ),
        onTap: () {
          // Return the selected location to the Map screen
          Navigator.pop(context, {
            'lat': lat,
            'lon': lon,
            'name': name.split(',').first,
          });
        },
      ),
    );
  }

  // Process city data - group by location and calculate averages
  // Improved with filtering and normalization
  Map<String, Map<String, dynamic>> _processCityData(List<QueryDocumentSnapshot> docs) {
    final Map<String, List<double>> cityReadings = {};

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      var city = data['locationName'] as String? ?? '';

      // Skip invalid location names
      if (city.isEmpty ||
          city.toLowerCase() == 'unknown' ||
          city.toLowerCase() == 'unknown location' ||
          city.toLowerCase().startsWith('fetching') ||
          city.toLowerCase().contains('permission denied')) {
        continue;
      }

      // Normalize city name
      city = _normalizeCityName(city);

      final db = (data['decibelLevel'] as num).toDouble();

      // Validate decibel reading
      if (db.isFinite && db >= 0 && db <= 120) {
        cityReadings.putIfAbsent(city, () => []);
        cityReadings[city]!.add(db);
      }
    }

    // Calculate averages and filter out cities with too few readings
    final Map<String, Map<String, dynamic>> result = {};

    cityReadings.forEach((city, readings) {
      // Only include cities with at least 2 readings to avoid outliers
      if (readings.length >= 2) {
        final avg = readings.reduce((a, b) => a + b) / readings.length;
        final max = readings.reduce((a, b) => a > b ? a : b);

        result[city] = {
          'avgDb': avg,
          'maxDb': max,
          'count': readings.length,
        };
      }
    });

    return result;
  }

  // Normalize city name for better grouping
  String _normalizeCityName(String city) {
    // Trim whitespace
    city = city.trim();

    // Handle coordinate-based names (e.g., "6.9271, 79.8612")
    if (city.contains(',') && city.split(',').length == 2) {
      try {
        final parts = city.split(',');
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          // Keep coordinates but format consistently
          return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }
      } catch (e) {
        // Not coordinates, continue with normal processing
      }
    }

    // Capitalize first letter of each word for consistency
    return city.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // City card widget
  Widget _buildCityCard(String cityName, double avgDb, int count, double maxDb) {
    Color cardColor;
    IconData icon;

    if (avgDb < 50) {
      cardColor = AppTheme.lowNoise;
      icon = Icons.volume_down;
    } else if (avgDb < 70) {
      cardColor = AppTheme.moderateNoise;
      icon = Icons.volume_up;
    } else {
      cardColor = AppTheme.highNoise;
      icon = Icons.warning;
    }

    return GestureDetector(
      onTap: () => _showCityDetails(cityName, avgDb, count, maxDb),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardColor.withValues(alpha:0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cardColor, size: 32),
            const SizedBox(height: 8),
            Text(
              cityName,
              style: TextStyle(
                color: ThemeHelper.getTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${avgDb.toStringAsFixed(0)} dB',
              style: TextStyle(
                color: cardColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count readings',
              style: TextStyle(
                color: ThemeHelper.getSecondaryTextColor(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show city details dialog
  void _showCityDetails(String city, double avgDb, int count, double maxDb) {
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
              Row(
                children: [
                  Icon(Icons.location_on, color: ThemeHelper.getPrimaryColor(context)),
                  const SizedBox(width: 8),
                  Text(
                    city,
                    style: TextStyle(
                      color: ThemeHelper.getTextColor(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Average', '${avgDb.toStringAsFixed(0)} dB'),
                  _buildStatItem('Max Level', '${maxDb.toStringAsFixed(0)} dB'),
                  _buildStatItem('Readings', '$count'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: ThemeHelper.getPrimaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: ThemeHelper.getSecondaryTextColor(context),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
