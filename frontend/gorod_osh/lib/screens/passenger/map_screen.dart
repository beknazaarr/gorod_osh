import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

  // ========== ВЫБРАННЫЕ МАРШРУТЫ ==========
  Set<int> _selectedRouteIds = {};
  List<RouteModel> _selectedRoutes = [];

  bool _isLoading = true;
  String? _error;
  Timer? _locationTimer;

  // Геолокация пользователя
  LatLng? _userLocation;
  bool _isLoadingLocation = false;
  StreamSubscription<Position>? _positionStream;

  // Центр Оша
  final LatLng _oshCenter = const LatLng(40.5283, 72.7985);

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLocationUpdates();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  // ========== ГЕОЛОКАЦИЯ ==========

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Включите GPS на устройстве');
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationError('Разрешение на геолокацию отклонено');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationError('Разрешение на геолокацию запрещено навсегда.\nВключите в настройках приложения.');
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController.move(_userLocation!, 15.0);
      _startTrackingLocation();

    } catch (e) {
      print('Ошибка получения геолокации: $e');
      _showLocationError('Не удалось получить местоположение');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _startTrackingLocation() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    });
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Настройки',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.0);
    } else {
      _requestLocationPermission();
    }
  }

  // ========== ЗАГРУЗКА ДАННЫХ ==========

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

  // ========== РАБОТА С ВЫБРАННЫМИ МАРШРУТАМИ ==========

  void _toggleRouteSelection(RouteModel route) {
    setState(() {
      if (_selectedRouteIds.contains(route.id)) {
        _selectedRouteIds.remove(route.id);
        _selectedRoutes.removeWhere((r) => r.id == route.id);
      } else {
        _selectedRouteIds.add(route.id);
        _selectedRoutes.add(route);
      }
    });
  }

  void _clearAllSelections() {
    setState(() {
      _selectedRouteIds.clear();
      _selectedRoutes.clear();
    });
  }

  List<BusLocationModel> _getFilteredBusLocations() {
    if (_selectedRouteIds.isEmpty) {
      return _busLocations;
    }

    // Фильтруем автобусы только по выбранным маршрутам
    return _busLocations.where((bus) {
      final route = _routes.firstWhere(
            (r) => r.number == bus.routeNumber,
        orElse: () => _routes.first,
      );
      return _selectedRouteIds.contains(route.id);
    }).toList();
  }

  Color _getBusTypeColor(String busType) {
    switch (busType) {
      case 'bus':
        return const Color(0xFF2196F3);
      case 'trolleybus':
        return const Color(0xFF4CAF50);
      case 'electric_bus':
        return const Color(0xFFFF9800);
      case 'minibus':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _getBusTypeLabel(String busType) {
    switch (busType) {
      case 'bus':
        return 'Автобус';
      case 'trolleybus':
        return 'Троллейбус';
      case 'electric_bus':
        return 'Электробус';
      case 'minibus':
        return 'Маршрутка';
      default:
        return 'Транспорт';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

    final filteredBuses = _getFilteredBusLocations();

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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.gorod_osh',
                tileSize: 256,
                maxZoom: 19,
                keepBuffer: 5,
              ),

              // Линии ТОЛЬКО ВЫБРАННЫХ маршрутов
              PolylineLayer(
                polylines: (_selectedRoutes.isEmpty ? _routes : _selectedRoutes)
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
                    strokeWidth: _selectedRouteIds.contains(route.id) ? 6.0 : 4.0,
                    color: _getBusTypeColor(route.busType).withOpacity(
                      _selectedRouteIds.contains(route.id) ? 0.9 : 0.5,
                    ),
                  );
                }).toList(),
              ),

              // Маркеры автобусов (отфильтрованные)
              MarkerLayer(
                markers: filteredBuses.map((bus) {
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

              // Маркер пользователя
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      Expanded(
                        child: GestureDetector(
                          onTap: _showSearchBottomSheet,
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
                                  _selectedRouteIds.isEmpty
                                      ? 'Поиск маршрута'
                                      : 'Выбрано: ${_selectedRouteIds.length}',
                                  style: TextStyle(
                                    color: _selectedRouteIds.isEmpty
                                        ? Colors.grey[400]
                                        : const Color(0xFF2196F3),
                                    fontSize: 16,
                                    fontWeight: _selectedRouteIds.isEmpty
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ========== КНОПКИ СПРАВА ==========
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
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
                _buildMapButton(
                  icon: _userLocation != null ? Icons.my_location : Icons.location_searching,
                  onPressed: _centerOnUser,
                  color: _userLocation != null ? Colors.blue : null,
                ),
                const SizedBox(height: 12),
                _buildMapButton(
                  icon: Icons.layers,
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // ========== КНОПКИ НАД НИЖНЕЙ ПАНЕЛЬЮ ==========
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.search,
                  onPressed: _showSearchBottomSheet,
                  badge: _selectedRouteIds.isNotEmpty ? _selectedRouteIds.length : null,
                ),
                const SizedBox(width: 12),
                _buildActionButton(
                  icon: Icons.favorite_border,
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
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
                            if (filteredBuses.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${filteredBuses.length}',
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

          // ========== НИЖНЯЯ ПАНЕЛЬ ==========
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

          // Индикатор загрузки геолокации
          if (_isLoadingLocation)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Получение геолокации...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? color,
  }) {
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
        color: color ?? Colors.black87,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    int? badge,
  }) {
    return Stack(
      children: [
        Container(
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
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

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

  // ========== ПОИСК И ВЫБОР МАРШРУТОВ ==========

  void _showSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
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

                    // Заголовок
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Text(
                            'Выбор маршрутов',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedRouteIds.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _clearAllSelections());
                                setModalState(() {});
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Очистить'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Список маршрутов с чекбоксами
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          final route = _routes[index];
                          final isSelected = _selectedRouteIds.contains(route.id);
                          final busCount = _busLocations
                              .where((b) => b.routeNumber == route.number)
                              .length;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _getBusTypeColor(route.busType).withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? _getBusTypeColor(route.busType)
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _getBusTypeColor(route.busType).withOpacity(0.15),
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
                                    _getBusTypeLabel(route.busType),
                                    style: TextStyle(
                                      color: _getBusTypeColor(route.busType),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${route.startPoint} → ${route.endPoint}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  if (busCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_bus,
                                          size: 14,
                                          color: _getBusTypeColor(route.busType),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'На линии: $busCount',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: _getBusTypeColor(route.busType),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() => _toggleRouteSelection(route));
                                  setModalState(() {});
                                },
                                activeColor: _getBusTypeColor(route.busType),
                              ),
                              onTap: () {
                                setState(() => _toggleRouteSelection(route));
                                setModalState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Кнопка применения
                    if (_selectedRouteIds.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _focusOnSelectedRoutes();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Показать выбранные (${_selectedRouteIds.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _focusOnSelectedRoutes() {
    if (_selectedRoutes.isEmpty) return;

    // Собираем все точки выбранных маршрутов
    List<LatLng> allPoints = [];
    for (var route in _selectedRoutes) {
      for (var point in route.path) {
        allPoints.add(LatLng(
          point['lat'].toDouble(),
          point['lng'].toDouble(),
        ));
      }
    }

    if (allPoints.isEmpty) return;

    // Находим границы
    double minLat = allPoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = allPoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    // Центр
    LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Приближаем карту
    _mapController.move(center, 14.0);
  }

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
                        const SizedBox(height: 2),
                        Text(
                          _getBusTypeLabel(bus.busType),
                          style: TextStyle(
                            color: _getBusTypeColor(bus.busType),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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