class RouteModel {
  final int id;
  final String number;
  final String name;
  final String busType;
  final String startPoint;
  final String endPoint;
  final Map<String, dynamic> startCoordinates;
  final Map<String, dynamic> endCoordinates;
  final List<Map<String, dynamic>> path;
  final String? workingHours;
  final bool isActive;

  RouteModel({
    required this.id,
    required this.number,
    required this.name,
    required this.busType,
    required this.startPoint,
    required this.endPoint,
    required this.startCoordinates,
    required this.endCoordinates,
    required this.path,
    this.workingHours,
    required this.isActive,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'],
      number: json['number'],
      name: json['name'],
      busType: json['bus_type'],
      startPoint: json['start_point'],
      endPoint: json['end_point'],
      startCoordinates: json['start_coordinates'],
      endCoordinates: json['end_coordinates'],
      path: List<Map<String, dynamic>>.from(json['path']),
      workingHours: json['working_hours'],
      isActive: json['is_active'],
    );
  }
}