class RouteModel {
  final int id;
  final String number;
  final String name;
  final String busType;
  final String startPoint;
  final String endPoint;
  final Map<String, dynamic>? startCoordinates;  // ← сделал nullable
  final Map<String, dynamic>? endCoordinates;    // ← сделал nullable
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
    this.startCoordinates,      // ← nullable
    this.endCoordinates,        // ← nullable
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
      // Безопасная обработка координат
      startCoordinates: json['start_coordinates'] as Map<String, dynamic>?,
      endCoordinates: json['end_coordinates'] as Map<String, dynamic>?,
      // Безопасная обработка path - если null, возвращаем пустой массив
      path: json['path'] != null
          ? List<Map<String, dynamic>>.from(json['path'])
          : [],
      workingHours: json['working_hours'],
      isActive: json['is_active'],
    );
  }
}