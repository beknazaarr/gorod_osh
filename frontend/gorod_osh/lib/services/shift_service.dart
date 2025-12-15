// lib/services/shift_service.dart

import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'auth_service.dart';

class ShiftService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Используем singleton AuthService
  final AuthService _authService = AuthService();

  // Начать смену
  Future<bool> startShift(int busId) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        print('❌ Нет токена авторизации');
        return false;
      }

      print('🚀 Начало смены на автобусе ID: $busId');

      final response = await _dio.post(
        '${ApiConstants.shifts}start/',
        data: {'bus': busId},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201) {
        print('✅ Смена начата успешно');
        print('📋 Данные смены: ${response.data}');
        return true;
      }

      print('⚠️ Неожиданный статус: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Ошибка начала смены: $e');
      if (e is DioException) {
        print('📝 Детали ошибки: ${e.response?.data}');
      }
      return false;
    }
  }

  // Завершить смену
  Future<bool> completeShift() async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        print('❌ Нет токена авторизации');
        return false;
      }

      print('🛑 Завершение смены...');

      final response = await _dio.post(
        '${ApiConstants.shifts}complete/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        print('✅ Смена завершена');
        return true;
      }

      print('⚠️ Неожиданный статус: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Ошибка завершения смены: $e');
      if (e is DioException) {
        print('📝 Детали ошибки: ${e.response?.data}');
      }
      return false;
    }
  }

  // Отправить координаты
  Future<bool> sendLocation(
      double lat,
      double lng, {
        double? speed,
        double? heading,
        double? accuracy,
      }) async {
    try {
      final token = _authService.accessToken;
      if (token == null) {
        print('❌ Нет токена для отправки координат');
        return false;
      }

      final data = {
        'latitude': lat,
        'longitude': lng,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
      };

      final response = await _dio.post(
        '${ApiConstants.locations}send/',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 201) {
        // Успех, но не логируем каждый раз (слишком много)
        return true;
      }

      print('⚠️ Неожиданный статус при отправке координат: ${response.statusCode}');
      return false;
    } catch (e) {
      // Не логируем каждую ошибку отправки координат (чтобы не засорять консоль)
      // Только критичные ошибки
      if (e is DioException && e.response?.statusCode == 401) {
        print('❌ Ошибка авторизации при отправке координат');
      }
      return false;
    }
  }

  // Получить активную смену водителя
  Future<Map<String, dynamic>?> getMyActiveShift() async {
    try {
      final token = _authService.accessToken;
      if (token == null) return null;

      final response = await _dio.get(
        '${ApiConstants.shifts}my-active/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('❌ Ошибка получения активной смены: $e');
      return null;
    }
  }
}