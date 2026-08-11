class QuakeReport {
  final String id;
  final int mmiLevel; // Escala de Mercalli Modificada, II a X
  final String label;
  final DateTime time;
  final double? lat;
  final double? lon;

  QuakeReport({
    required this.id,
    required this.mmiLevel,
    required this.label,
    required this.time,
    this.lat,
    this.lon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mmiLevel': mmiLevel,
        'label': label,
        'time': time.toIso8601String(),
        'lat': lat,
        'lon': lon,
      };

  factory QuakeReport.fromJson(Map<String, dynamic> json) => QuakeReport(
        id: json['id'] as String,
        mmiLevel: json['mmiLevel'] as int,
        label: json['label'] as String,
        time: DateTime.parse(json['time'] as String),
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );
}
