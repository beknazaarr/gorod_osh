import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _key = 'favorite_routes';
  Set<int> _favoriteRouteIds = {};

  // Инициализация (вызвать при запуске приложения)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_key);
    if (saved != null) {
      _favoriteRouteIds = saved.map((e) => int.parse(e)).toSet();
      print('📌 Загружено избранных маршрутов: ${_favoriteRouteIds.length}');
    }
  }

  // Сохранить в SharedPreferences
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _favoriteRouteIds.map((e) => e.toString()).toList(),
    );
  }

  // Добавить в избранное
  Future<void> addFavorite(int routeId) async {
    _favoriteRouteIds.add(routeId);
    await _save();
    print('❤️ Маршрут $routeId добавлен в избранное');
  }

  // Убрать из избранного
  Future<void> removeFavorite(int routeId) async {
    _favoriteRouteIds.remove(routeId);
    await _save();
    print('💔 Маршрут $routeId удалён из избранного');
  }

  // Переключить статус (добавить/убрать)
  Future<void> toggleFavorite(int routeId) async {
    if (_favoriteRouteIds.contains(routeId)) {
      await removeFavorite(routeId);
    } else {
      await addFavorite(routeId);
    }
  }

  // Проверить, в избранном ли маршрут
  bool isFavorite(int routeId) {
    return _favoriteRouteIds.contains(routeId);
  }

  // Получить список ID избранных маршрутов
  List<int> getFavoriteIds() {
    return _favoriteRouteIds.toList();
  }

  // Очистить все избранные
  Future<void> clearAll() async {
    _favoriteRouteIds.clear();
    await _save();
    print('🗑️ Все избранные маршруты очищены');
  }
}