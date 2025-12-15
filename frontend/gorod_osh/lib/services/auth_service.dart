// lib/services/auth_service.dart

import 'package:dio/dio.dart';
import '../core/constants.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Dio _dio = Dio();

  String? _accessToken;
  String? _refreshToken;

  // Логин
  Future<bool> login(String username, String password) async {
    try {
      print('🔐 Попытка входа: $username');

      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/login/',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['access'];
        _refreshToken = response.data['refresh'];

        print('✅ Успешная авторизация');
        print('🎫 Access Token: ${_accessToken?.substring(0, 20)}...');

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка авторизации: $e');
      if (e is DioException) {
        print('📝 Детали ошибки: ${e.response?.data}');
      }
      return false;
    }
  }

  // Проверить есть ли активная смена
  Future<bool> hasActiveShift() async {
    try {
      if (_accessToken == null) {
        print('⚠️ Нет токена для проверки смены');
        return false;
      }

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/shifts/my-active/',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
          validateStatus: (status) => status! < 500, // Не считать 404 ошибкой
        ),
      );

      if (response.statusCode == 200) {
        print('✅ Есть активная смена');
        return true;
      } else if (response.statusCode == 404) {
        print('ℹ️ Нет активной смены');
        return false;
      }

      return false;
    } catch (e) {
      print('❌ Ошибка проверки смены: $e');
      return false;
    }
  }

  // Получить токен
  String? get accessToken => _accessToken;

  // Проверка авторизации
  bool isAuthenticated() {
    final isAuth = _accessToken != null;
    print('🔍 Проверка авторизации: $isAuth');
    return isAuth;
  }

  // Выход
  void logout() {
    print('👋 Выход из системы');
    _accessToken = null;
    _refreshToken = null;
  }

  // Обновить токен (опционально)
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/refresh/',
        data: {'refresh': _refreshToken},
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['access'];
        print('✅ Токен обновлён');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка обновления токена: $e');
      return false;
    }
  }
}