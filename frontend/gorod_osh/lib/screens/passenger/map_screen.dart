import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../models/route.dart';
import '../../models/bus_location.dart';
import 'dart:async';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  List<RouteModel> _routes = [];
  List<BusLocationModel> _busLocations = [];
  bool _isLoading = true;
  String? _error;
  Timer? _locationTimer;

  // Центр Оша
  final LatLng _oshCenter = const LatLng(40.5283, 72.7985);

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routes = await _apiService.getActiveRoutes();
      final locations = await _apiService.getLatestBusLocations();

      setState(() {
        _routes = routes;
        _busLocations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки данных: $e';
        _isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateBusLocations();
    });
  }

  Future<void> _updateBusLocations() async {
    try {
      final locations = await _apiService.getLatestBusLocations();
      setState(() {
        _busLocations = locations;
      });
    } catch (e) {
      print('Ошибка обновления координат: $e');
    }
  }

  Color _getBusTypeColor(String busType) {
    switch (busType) {
      case 'bus':
        return const Color(0xFF2196F3); // Синий как у 2GIS
      case 'trolleybus':
        return const Color(0xFF4CAF50); // Зеленый
      case 'electric_bus':
        return const Color(0xFFFF9800); // Оранжевый
      case 'minibus':
        return const Color(0xFFF44336); // Красный
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ========== КАРТА ==========
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _oshCenter,
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Тайлы OSM с высоким качеством
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gorod_osh',
                tileSize: 256,
                maxZoom: 19,
                keepBuffer: 5, // Предзагрузка тайлов для плавности
              ),

              // Линии маршрутов (тоньше, как у 2GIS)
              PolylineLayer(
                polylines: _routes
                    .where((route) => route.path.isNotEmpty)
                    .map((route) {
                  List<LatLng> points = route.path.map((point) {
                    return LatLng(
                      point['lat'].toDouble(),
                      point['lng'].toDouble(),
                    );
                  }).toList();

                  return Polyline(
                    points: points,
                    strokeWidth: 3.5,
                    color: _getBusTypeColor(route.busType).withOpacity(0.7),
                  );
                }).toList(),
              ),

              // Маркеры автобусов в стиле 2GIS
              MarkerLayer(
                markers: _busLocations.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitude, bus.longitude),
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () => _showBusInfo(bus),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _getBusTypeColor(bus.busType),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              bus.routeNumber ?? '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // ========== ВЕРХНЯЯ ПАНЕЛЬ ==========
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Кнопка меню
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Поисковая строка
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[400]),
                              const SizedBox(width: 8),
                              Text(
                                'Поиск маршрута',
                                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ========== КНОПКИ СПРАВА (как у 2GIS) ==========
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                // Кнопка +
                _buildMapButton(
                  icon: Icons.add,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Кнопка -
                _buildMapButton(
                  icon: Icons.remove,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Кнопка компас/геолокация
                _buildMapButton(
                  icon: Icons.my_location,
                  onPressed: () {
                    _mapController.move(_oshCenter, 13.0);
                  },
                ),
                const SizedBox(height: 12),
                // Кнопка слои
                _buildMapButton(
                  icon: Icons.layers,
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // ========== НИЖНЯЯ ПАНЕЛЬ (как у 2GIS) ==========
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Индикатор
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Навигационные кнопки
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavButton(Icons.home, 'Главная', false),
                          _buildNavButton(Icons.directions_bus, 'Транспорт', true),
                          _buildNavButton(Icons.chat_bubble_outline, 'Обращение', false),
                          _buildNavButton(Icons.apps, 'Сервисы', false),
                          _buildNavButton(Icons.person_outline, 'Кабинет', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ========== КНОПКИ НАД НИЖНЕЙ ПАНЕЛЬЮ ==========
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: Row(
              children: [
                // Кнопка поиска
                _buildActionButton(
                  icon: Icons.search,
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                // Кнопка избранное
                _buildActionButton(
                  icon: Icons.favorite_border,
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                // Кнопка маршруты (главная)
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showRoutesList(),
                        borderRadius: BorderRadius.circular(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.route, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              'Маршруты',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_busLocations.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_busLocations.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Кнопка карты (справа)
  Widget _buildMapButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 24),
        onPressed: onPressed,
        color: Colors.black87,
      ),
    );
  }

  // Кнопка действия (над нижней панелью)
  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 26),
        onPressed: onPressed,
        color: Colors.black87,
      ),
    );
  }

  // Кнопка навигации (нижняя панель)
  Widget _buildNavButton(IconData icon, String label, bool isActive) {
    return InkWell(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF2196F3) : Colors.grey[600],
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF2196F3) : Colors.grey[600],
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Показать информацию об автобусе
  void _showBusInfo(BusLocationModel bus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getBusTypeColor(bus.busType),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        bus.routeNumber ?? '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Маршрут ${bus.routeNumber ?? "—"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bus.busNumber,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (bus.speed != null)
                _buildInfoTile(
                  Icons.speed,
                  'Скорость',
                  '${bus.speed!.toStringAsFixed(0)} км/ч',
                ),
              const SizedBox(height: 12),
              _buildInfoTile(
                Icons.access_time,
                'Обновлено',
                _formatTime(bus.timestamp),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2196F3)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Показать список маршрутов
  void _showRoutesList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Text(
                          'Маршруты',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_busLocations.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'На линии: ${_busLocations.length}',
                              style: const TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        final busCount = _busLocations
                            .where((b) => b.routeNumber == route.number)
                            .length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _getBusTypeColor(route.busType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  route.number,
                                  style: TextStyle(
                                    color: _getBusTypeColor(route.busType),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              route.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${route.startPoint} → ${route.endPoint}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                if (route.workingHours != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text(
                                        route.workingHours!,
                                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: busCount > 0
                                ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getBusTypeColor(route.busType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$busCount',
                                style: TextStyle(
                                  color: _getBusTypeColor(route.busType),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            )
                                : const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(context);
                              _focusOnRoute(route);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _focusOnRoute(RouteModel route) {
    if (route.path.isNotEmpty) {
      final firstPoint = route.path.first;
      _mapController.move(
        LatLng(firstPoint['lat'].toDouble(), firstPoint['lng'].toDouble()),
        15.0,
      );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'только что';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} мин назад';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}