// lib/screens/driver/select_bus_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/shift_service.dart';
import '../../models/bus.dart';
import 'active_shift_screen.dart';

class SelectBusScreen extends StatefulWidget {
  const SelectBusScreen({super.key});

  @override
  State<SelectBusScreen> createState() => _SelectBusScreenState();
}

class _SelectBusScreenState extends State<SelectBusScreen> {
  final _apiService = ApiService();
  final _shiftService = ShiftService();

  List<BusModel> _buses = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedBusId;

  @override
  void initState() {
    super.initState();
    _checkActiveShiftAndLoadBuses();
  }

  Future<void> _checkActiveShiftAndLoadBuses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Проверяем есть ли активная смена
      final activeShift = await _shiftService.getMyActiveShift();

      if (activeShift != null && mounted) {
        // Если есть активная смена - спрашиваем что делать
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Активная смена'),
            content: Text(
                'У вас уже есть активная смена на автобусе ${activeShift['bus_info']?['bus_number'] ?? 'неизвестен'}.\n\nПродолжить смену или завершить?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Завершить'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (shouldContinue == true) {
          // Продолжаем активную смену
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ActiveShiftScreen()),
          );
          return;
        } else if (shouldContinue == false) {
          // Завершаем старую смену
          final completed = await _shiftService.completeShift();
          if (!completed) {
            setState(() {
              _error = 'Не удалось завершить смену';
              _isLoading = false;
            });
            return;
          }
        }
      }

      // Загружаем доступные автобусы
      await _loadAvailableBuses();
    } catch (e) {
      setState(() {
        _error = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableBuses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final buses = await _apiService.getAvailableBuses();
      setState(() {
        _buses = buses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startShift() async {
    if (_selectedBusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите автобус')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _shiftService.startShift(_selectedBusId!);

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ActiveShiftScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка начала смены')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
      setState(() => _isLoading = false);
    }
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Выбор автобуса'),
        backgroundColor: const Color(0xFF0D2F5B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkActiveShiftAndLoadBuses,
              child: const Text('Повторить'),
            ),
          ],
        ),
      )
          : _buses.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_filled,
                size: 64,
                color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Нет доступных автобусов',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Все автобусы заняты',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAvailableBuses,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Информационная панель
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0D2F5B),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выберите автобус',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Доступно автобусов: ${_buses.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Список автобусов
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _buses.length,
              itemBuilder: (context, index) {
                final bus = _buses[index];
                final isSelected = _selectedBusId == bus.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2196F3)
                          : Colors.grey[200]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedBusId = bus.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Иконка автобуса
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _getBusTypeColor(bus.busType)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                size: 32,
                                color: _getBusTypeColor(bus.busType),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Информация
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus.registrationNumber,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getBusTypeLabel(bus.busType),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _getBusTypeColor(bus.busType),
                                    ),
                                  ),
                                  if (bus.routeNumber != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.route,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Маршрут ${bus.routeNumber}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Галочка
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2196F3)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Кнопка начать смену
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedBusId == null ? null : _startShift,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Начать смену',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}