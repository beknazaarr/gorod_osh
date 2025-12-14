class BusLocationModel {
  final int busId;
  final String busNumber;
  final String busType;
  final String? routeNumber;
  final double latitude;
  final double longitude;
  final double? speed;
  final double? heading;
  final DateTime timestamp;

  BusLocationModel({
    required this.busId,
    required this.busNumber,
    required this.busType,
    this.routeNumber,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    required this.timestamp,
  });

  factory BusLocationModel.fromJson(Map<String, dynamic> json) {
    return BusLocationModel(
      busId: json['bus_id'],
      busNumber: json['bus_number'],
      busType: json['bus_type'],
      routeNumber: json['route_number'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}