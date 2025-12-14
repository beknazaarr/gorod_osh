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

  // Центр Оша (примерные координаты)
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

  // Загрузка начальных данных
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

  // Обновление координат автобусов каждые 5 секунд
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

  // Цвета для разных типов транспорта
  Color _getBusTypeColor(String busType) {
    switch (busType) {
      case 'bus':
        return Colors.blue;
      case 'trolleybus':
        return Colors.green;
      case 'electric_bus':
        return Colors.orange;
      case 'minibus':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Транспорт Оша'),
          backgroundColor: const Color(0xFF0D2F5B),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Транспорт Оша'),
          backgroundColor: const Color(0xFF0D2F5B),
        ),
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
      appBar: AppBar(
        title: const Text('Транспорт Оша'),
        backgroundColor: const Color(0xFF0D2F5B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Карта
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _oshCenter,
              initialZoom: 13.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              // Тайлы карты (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gorod_osh',
              ),

              // Линии маршрутов
              PolylineLayer(
                polylines: _routes.map((route) {
                  List<LatLng> points = route.path.map((point) {
                    return LatLng(
                      point['lat'].toDouble(),
                      point['lng'].toDouble(),
                    );
                  }).toList();

                  return Polyline(
                    points: points,
                    strokeWidth: 3.0,
                    color: _getBusTypeColor(route.busType).withOpacity(0.7),
                  );
                }).toList(),
              ),

              // Маркеры автобусов
              MarkerLayer(
                markers: _busLocations.map((bus) {
                  return Marker(
                    point: LatLng(bus.latitude, bus.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showBusInfo(bus),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getBusTypeColor(bus.busType),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            bus.routeNumber ?? '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
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

          // Информация о количестве автобусов
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'На линии: ${_busLocations.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Кнопка списка маршрутов
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoutesList(),
        backgroundColor: const Color(0xFF0D2F5B),
        child: const Icon(Icons.list),
      ),
    );
  }

  // Показать информацию об автобусе
  void _showBusInfo(BusLocationModel bus) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                          'Маршрут ${bus.routeNumber ?? "Неизвестно"}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Автобус: ${bus.busNumber}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (bus.speed != null)
                Row(
                  children: [
                    const Icon(Icons.speed, size: 20),
                    const SizedBox(width: 8),
                    Text('Скорость: ${bus.speed!.toStringAsFixed(1)} км/ч'),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Text('Обновлено: ${_formatTime(bus.timestamp)}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Показать список маршрутов
  void _showRoutesList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Маршруты',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        final busCount = _busLocations
                            .where((b) => b.routeNumber == route.number)
                            .length;

                        return Card(
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getBusTypeColor(route.busType),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  route.number,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(route.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${route.startPoint} → ${route.endPoint}'),
                                if (route.workingHours != null)
                                  Text(
                                    'Работает: ${route.workingHours}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: busCount > 0
                                ? Chip(
                              label: Text('$busCount'),
                              backgroundColor:
                              _getBusTypeColor(route.busType)
                                  .withOpacity(0.2),
                            )
                                : null,
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

  // Сфокусироваться на маршруте
  void _focusOnRoute(RouteModel route) {
    if (route.path.isNotEmpty) {
      final firstPoint = route.path.first;
      _mapController.move(
        LatLng(firstPoint['lat'].toDouble(), firstPoint['lng'].toDouble()),
        14.0,
      );
    }
  }

  // Форматирование времени
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