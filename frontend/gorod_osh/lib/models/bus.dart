// lib/models/bus.dart

class BusModel {
  final int id;
  final String registrationNumber;
  final String busType;
  final String? model;
  final int? capacity;
  final String? routeNumber;
  final bool isActive;

  BusModel({
    required this.id,
    required this.registrationNumber,
    required this.busType,
    this.model,
    this.capacity,
    this.routeNumber,
    required this.isActive,
  });

  factory BusModel.fromJson(Map<String, dynamic> json) {
    return BusModel(
      id: json['id'],
      registrationNumber: json['registration_number'],
      busType: json['bus_type'],
      model: json['model'],
      capacity: json['capacity'],
      routeNumber: json['route_number'],
      isActive: json['is_active'] ?? true,
    );
  }
}