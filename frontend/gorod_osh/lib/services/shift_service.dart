// lib/services/shift_service.dart

import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'auth_service.dart';

class ShiftService {
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  // Начать смену
  Future<bool> startShift(int busId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        print('❌ Нет токена авторизации');
        return false;
      }

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/shifts/start/',
        data: {'bus': busId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201) {
        print('✅ Смена начата');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка начала смены: $e');
      return false;
    }
  }

  // Завершить смену
  Future<bool> completeShift() async {
    try {
      final token = _authService.accessToken;
      if (token == null) return false;

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/shifts/complete/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        print('✅ Смена завершена');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка завершения смены: $e');
      return false;
    }
  }

  // Отправить координаты
  Future<bool> sendLocation(double lat, double lng, {double? speed, double? heading}) async {
    try {
      final token = _authService.accessToken;
      if (token == null) return false;

      await _dio.post(
        '${ApiConstants.baseUrl}/locations/send/',
        data: {
          'latitude': lat,
          'longitude': lng,
          'speed': speed,
          'heading': heading,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      return true;
    } catch (e) {
      print('❌ Ошибка отправки координат: $e');
      return false;
    }
  }
}