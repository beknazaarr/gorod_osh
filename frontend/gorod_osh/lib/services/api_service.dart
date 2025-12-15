import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/route.dart';
import '../models/bus_location.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  )..interceptors.add(
    LogInterceptor(
      request: true,
      requestHeader: true,
      requestBody: true,
      responseHeader: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print('🔥 DIO LOG: $obj'),
    ),
  );

  // Получить все активные маршруты
  Future<List<RouteModel>> getActiveRoutes() async {
    try {
      print('📍 Отправка запроса на: ${ApiConstants.routes}');
      final response = await _dio.get(ApiConstants.routes);
      print('✅ Ответ получен: ${response.statusCode}');
      final List<dynamic> data = response.data;
      return data
          .map((json) => RouteModel.fromJson(json))
          .where((route) => route.isActive)
          .toList();
    } catch (e) {
      print('❌ Ошибка загрузки маршрутов: $e');
      rethrow;
    }
  }

  // Получить путь конкретного маршрута
  Future<RouteModel> getRoutePath(int routeId) async {
    try {
      final response = await _dio.get('${ApiConstants.routes}$routeId/');
      return RouteModel.fromJson(response.data);
    } catch (e) {
      print('❌ Ошибка загрузки пути маршрута: $e');
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

      print('📍 Отправка запроса на: ${ApiConstants.latestLocations}');
      final response = await _dio.get(
        ApiConstants.latestLocations,
        queryParameters: queryParams,
      );

      print('✅ Координаты получены: ${response.statusCode}');
      final List<dynamic> data = response.data;
      return data.map((json) => BusLocationModel.fromJson(json)).toList();
    } catch (e) {
      print('❌ Ошибка загрузки координат автобусов: $e');
      rethrow;
    }
  }
}