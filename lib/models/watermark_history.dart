import 'dart:convert';

class WatermarkHistory {
  final String imagePath;
  final String watermarkText;
  final DateTime timestamp;

  WatermarkHistory({
    required this.imagePath,
    required this.watermarkText,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'watermarkText': watermarkText,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory WatermarkHistory.fromMap(Map<String, dynamic> map) {
    return WatermarkHistory(
      imagePath: map['imagePath'] ?? '',
      watermarkText: map['watermarkText'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }

  String toJson() => json.encode(toMap());

  factory WatermarkHistory.fromJson(String source) =>
      WatermarkHistory.fromMap(json.decode(source));
}