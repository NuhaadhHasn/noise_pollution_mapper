/// Builds the lookup key linking a marker's coordinates to its noise level.
///
/// The marker writer (_buildMarkersFromSnapshot) and the cluster-color reader
/// (MarkerClusterLayerOptions.builder) in map_view_screen.dart MUST both use
/// this function. Audit finding map-1/uiux-4: the two sides previously built
/// keys with different string interpolations ('${lat}_$lng' vs the broken
/// '$point.latitude_...') so the lookup never matched and every cluster
/// rendered orange.
String markerNoiseKey(double latitude, double longitude) =>
    '${latitude}_$longitude';
