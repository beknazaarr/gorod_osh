// lib/services/auth_service.dart

import 'package:dio/dio.dart';
import '../core/constants.dart';

class AuthService {
  final Dio _dio = Dio();

  String? _accessToken;
  String? _refreshToken;

  // Логин
  Future<bool> login(String username, String password) async {
    try {
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

        // Сохраняем токены (в реальном проекте используй secure_storage)
        print('✅ Успешная авторизация');
        print('Access Token: $_accessToken');

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка авторизации: $e');
      return false;
    }
  }

  // Проверить есть ли активная смена
  Future<bool> hasActiveShift() async {
    try {
      if (_accessToken == null) return false;

      final response = await _dio.get(
        '${ApiConstants.baseUrl}/shifts/my-active/',
        options: Options(
          headers: {'Authorization': 'Bearer $_accessToken'},
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Получить токен
  String? get accessToken => _accessToken;

  // Проверка авторизации
  bool isAuthenticated() => _accessToken != null;

  // Выход
  void logout() {
    _accessToken = null;
    _refreshToken = null;
  }
}