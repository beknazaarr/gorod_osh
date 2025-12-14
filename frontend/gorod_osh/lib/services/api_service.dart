import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/route.dart';
import '../models/bus_location.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // Получить все активные маршруты
  Future<List<RouteModel>> getActiveRoutes() async {
    try {
      final response = await _dio.get(ApiConstants.routes + 'active/');
      final List<dynamic> data = response.data;
      return data.map((json) => RouteModel.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка загрузки маршрутов: $e');
      rethrow;
    }
  }

  // Получить путь конкретного маршрута
  Future<RouteModel> getRoutePath(int routeId) async {
    try {
      final response = await _dio.get('${ApiConstants.routes}$routeId/');
      return RouteModel.fromJson(response.data);
    } catch (e) {
      print('Ошибка загрузки пути маршрута: $e');
      rethrow;
    }
  }

  // Получить последние координаты всех автобусов
  Future<List<BusLocationModel>> getLatestBusLocations({
    int? routeId,
    String? busType,
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      if (routeId != null) queryParams['route'] = routeId;
      if (busType != null) queryParams['bus_type'] = busType;

      final response = await _dio.get(
        ApiConstants.latestLocations,
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data;
      return data.map((json) => BusLocationModel.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка загрузки координат автобусов: $e');
      rethrow;
    }
  }
}