// lib/screens/driver/active_shift_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/shift_service.dart';
import 'dart:async';

class ActiveShiftScreen extends StatefulWidget {
  const ActiveShiftScreen({super.key});

  @override
  State<ActiveShiftScreen> createState() => _ActiveShiftScreenState();
}

class _ActiveShiftScreenState extends State<ActiveShiftScreen> {
  final _shiftService = ShiftService();

  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  Position? _lastPosition;
  DateTime? _shiftStartTime;
  int _locationsSent = 0;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _shiftStartTime = DateTime.now();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    try {
      // Проверка разрешений
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Разрешите доступ к геолокации в настройках');
        return;
      }

      // Получаем текущую позицию
      _lastPosition = await Geolocator.getCurrentPosition();

      // Запускаем таймер отправки каждые 5 секунд
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendCurrentLocation();
      });

      // Слушаем изменения позиции
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        setState(() {
          _lastPosition = position;
        });
      });

      print('✅ Отслеживание геолокации запущено');
    } catch (e) {
      print('❌ Ошибка запуска отслеживания: $e');
      _showError('Ошибка доступа к GPS');
    }
  }

  Future<void> _sendCurrentLocation() async {
    if (_lastPosition == null || _isSending) return;

    setState(() => _isSending = true);

    try {
      // ВАЖНО: Округляем координаты до 6 знаков после запятой
      final latitude = double.parse(_lastPosition!.latitude.toStringAsFixed(6));
      final longitude = double.parse(_lastPosition!.longitude.toStringAsFixed(6));
      final speed = double.parse((_lastPosition!.speed * 3.6).toStringAsFixed(2)); // м/с -> км/ч
      final heading = double.parse(_lastPosition!.heading.toStringAsFixed(2));

      print('📍 Отправка координат:');
      print('   lat: $latitude');
      print('   lng: $longitude');
      print('   speed: $speed км/ч');

      final success = await _shiftService.sendLocation(
        latitude,
        longitude,
        speed: speed,
        heading: heading,
      );

      if (success) {
        setState(() {
          _locationsSent++;
          _isSending = false;
        });
        print('✅ Координаты отправлены: $_locationsSent');
      } else {
        setState(() => _isSending = false);
        print('⚠️ Не удалось отправить координаты');
      }
    } catch (e) {
      print('❌ Ошибка отправки координат: $e');
      setState(() => _isSending = false);
    }
  }

  Future<void> _completeShift() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить смену?'),
        content: const Text('Вы уверены, что хотите завершить смену?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    final success = await _shiftService.completeShift();

    if (!mounted) return;

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else {
      _showError('Ошибка завершения смены');
      setState(() => _isSending = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}ч ${minutes}мин';
  }

  @override
  Widget build(BuildContext context) {
    final duration = _shiftStartTime != null
        ? DateTime.now().difference(_shiftStartTime!)
        : Duration.zero;

    return Scaffold(
      backgroundColor: const Color(0xFF0D2F5B),
      body: SafeArea(
        child: Column(
          children: [
            // Шапка
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_bus,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Смена активна',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Карточки статистики
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    // GPS статус
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _lastPosition != null
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _lastPosition != null
                              ? Colors.green
                              : Colors.orange,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastPosition != null
                                ? Icons.gps_fixed
                                : Icons.gps_not_fixed,
                            color: _lastPosition != null
                                ? Colors.green
                                : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastPosition != null
                                      ? 'GPS активен'
                                      : 'Ожидание GPS...',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_lastPosition != null)
                                  Text(
                                    'Скорость: ${(_lastPosition!.speed * 3.6).toStringAsFixed(0)} км/ч',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_isSending)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Статистика
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Отправлено',
                            '$_locationsSent',
                            Icons.cloud_upload,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Частота',
                            '5 сек',
                            Icons.timer,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Кнопка завершения смены
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _completeShift,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Завершить смену',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}