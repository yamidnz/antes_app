class Quake {
  final String id;
  final double mag;
  final String place;
  final DateTime time;
  final double lat;
  final double lon;
  final double depthKm;
  final String source;

  Quake({
    required this.id,
    required this.mag,
    required this.place,
    required this.time,
    required this.lat,
    required this.lon,
    required this.depthKm,
    this.source = 'USGS',
  });
}
