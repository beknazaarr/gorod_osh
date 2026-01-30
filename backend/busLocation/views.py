# backend/busLocation/views.py

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from django.db.models import OuterRef, Subquery, Prefetch
from django.core.cache import cache
from datetime import timedelta
from .models import BusLocation
from shift.models import Shift
from .serializers import (
    BusLocationSerializer, BusLocationCreateSerializer,
    BusLocationListSerializer, BusLocationTrackSerializer
)
from user.permissions import IsDriver
import json


class BusLocationViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления местоположениями автобусов.
    Оптимизирован для минимального количества запросов к БД.
    """
    queryset = BusLocation.objects.select_related('bus', 'shift', 'shift__driver').all()
    
    def get_serializer_class(self):
        """Возвращает нужный сериализатор в зависимости от действия."""
        if self.action in ['create', 'send']:
            return BusLocationCreateSerializer
        elif self.action in ['list', 'bus_history', 'shift_locations']:
            return BusLocationListSerializer
        elif self.action == 'track':
            return BusLocationTrackSerializer
        return BusLocationSerializer
    
    def get_permissions(self):
        """
        Публичный доступ для чтения (пассажиры смотрят где автобусы).
        Только водители могут отправлять координаты.
        """
        if self.action in ['list', 'retrieve', 'latest', 'bus_history', 'shift_locations']:
            return [AllowAny()]
        elif self.action in ['create', 'send']:
            return [IsDriver()]
        return [IsAuthenticated()]
    
    def create(self, request, *args, **kwargs):
        """
        Создать запись координаты.
        Доступно только водителям с активной сменой.
        Оптимизация: используем select_related для избежания N+1.
        """
        # Получаем активную смену с предзагрузкой связанных объектов
        try:
            shift = Shift.objects.select_related(
                'bus',
                'bus__route'
            ).get(
                driver=request.user, 
                status='active'
            )
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        serializer = self.get_serializer(
            data=request.data,
            context={'request': request, 'shift': shift}
        )
        
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        # Сохраняем координату
        location = serializer.save()
        
        # Инвалидируем кэш для этой смены
        cache_key = f'latest_location_shift_{shift.id}'
        cache.delete(cache_key)
        
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=False, methods=['post'])
    def send(self, request):
        """
        Упрощённый endpoint для отправки координаты.
        POST /api/locations/send/
        """
        return self.create(request)
    
    @action(detail=False, methods=['get'])
    def latest(self, request):
        """
        Получить последние координаты всех активных автобусов.
        ОПТИМИЗИРОВАНО: 2 запроса вместо N+1.
        
        GET /api/locations/latest/
        Query params:
        - route: ID маршрута (опционально)
        - bus_type: тип транспорта (опционально)
        """
        # Проверяем кэш (на 5 секунд)
        cache_key = 'latest_bus_locations'
        route_id = request.query_params.get('route')
        bus_type = request.query_params.get('bus_type')
        
        if route_id:
            cache_key += f'_route_{route_id}'
        if bus_type:
            cache_key += f'_type_{bus_type}'
        
        cached_data = cache.get(cache_key)
        if cached_data:
            return Response(cached_data)
        
        # Подзапрос для получения ID последней координаты каждой смены
        latest_location_subquery = BusLocation.objects.filter(
            shift=OuterRef('pk')
        ).order_by('-timestamp').values('id')[:1]
        
        # Получаем активные смены с аннотацией ID последней координаты
        # ОПТИМИЗАЦИЯ: select_related для избежания дополнительных запросов
        active_shifts = Shift.objects.filter(
            status='active'
        ).select_related(
            'bus',
            'bus__route',
            'driver'
        ).annotate(
            latest_location_id=Subquery(latest_location_subquery)
        )
        
        # Фильтры
        if route_id:
            active_shifts = active_shifts.filter(bus__route_id=route_id)
        if bus_type:
            active_shifts = active_shifts.filter(bus__bus_type=bus_type)
        
        # Получаем ID всех последних координат
        location_ids = [
            shift.latest_location_id 
            for shift in active_shifts 
            if shift.latest_location_id
        ]
        
        if not location_ids:
            return Response([])
        
        # ОПТИМИЗАЦИЯ: Получаем все координаты одним запросом
        # Создаём словарь для O(1) поиска по shift_id
        locations_dict = {
            loc.shift_id: loc 
            for loc in BusLocation.objects.filter(
                id__in=location_ids
            ).select_related('shift__bus', 'shift__bus__route')
        }
        
        # Формируем ответ
        locations = []
        for shift in active_shifts:
            location = locations_dict.get(shift.id)
            if location:
                locations.append({
                    'bus_id': shift.bus.id,
                    'bus_number': shift.bus.registration_number,
                    'bus_type': shift.bus.bus_type,
                    'route_number': shift.bus.route.number if shift.bus.route else None,
                    'latitude': float(location.latitude),
                    'longitude': float(location.longitude),
                    'speed': location.speed,
                    'heading': location.heading,
                    'accuracy': location.accuracy,
                    'timestamp': location.timestamp
                })
        
        # Кэшируем результат на 5 секунд
        cache.set(cache_key, locations, 5)
        
        return Response(locations)
    
    @action(detail=False, methods=['get'], url_path='bus/(?P<bus_id>[^/.]+)')
    def bus_history(self, request, bus_id=None):
        """
        Получить историю координат автобуса.
        GET /api/locations/bus/{bus_id}/
        
        Query params:
        - hours: количество часов назад (по умолчанию 1)
        - limit: максимум записей (по умолчанию 100, максимум 1000)
        """
        hours = int(request.query_params.get('hours', 1))
        limit = min(int(request.query_params.get('limit', 100)), 1000)
        
        start_time = timezone.now() - timedelta(hours=hours)
        
        # ОПТИМИЗАЦИЯ: используем only() для выбора только нужных полей
        locations = BusLocation.objects.filter(
            bus_id=bus_id,
            timestamp__gte=start_time
        ).only(
            'id', 'latitude', 'longitude', 'speed', 
            'heading', 'accuracy', 'timestamp'
        ).order_by('-timestamp')[:limit]
        
        serializer = self.get_serializer(locations, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='shift/(?P<shift_id>[^/.]+)')
    def shift_locations(self, request, shift_id=None):
        """
        Получить все координаты конкретной смены.
        GET /api/locations/shift/{shift_id}/
        
        Query params:
        - limit: максимум записей (по умолчанию 500, максимум 2000)
        """
        limit = min(int(request.query_params.get('limit', 500)), 2000)
        
        # Проверяем существование смены
        try:
            shift = Shift.objects.select_related(
                'bus', 
                'bus__route', 
                'driver'
            ).get(id=shift_id)
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'Смена не найдена'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # ОПТИМИЗАЦИЯ: используем only() для минимизации данных
        locations = BusLocation.objects.filter(
            shift_id=shift_id
        ).only(
            'id', 'latitude', 'longitude', 'speed', 
            'heading', 'accuracy', 'timestamp'
        ).order_by('-timestamp')[:limit]
        
        serializer = self.get_serializer(locations, many=True)
        
        return Response({
            'shift_id': shift.id,
            'bus_number': shift.bus.registration_number,
            'driver_name': f"{shift.driver.first_name} {shift.driver.last_name}".strip() or shift.driver.username,
            'start_time': shift.start_time,
            'end_time': shift.end_time,
            'status': shift.status,
            'total_locations': locations.count(),
            'locations': serializer.data
        })
    
    @action(detail=False, methods=['get'])
    def track(self, request):
        """
        Получить трек текущей смены водителя.
        GET /api/locations/track/
        
        Query params:
        - limit: максимум записей (по умолчанию 200, максимум 1000)
        """
        # Получаем активную смену водителя
        try:
            shift = Shift.objects.select_related(
                'bus', 
                'bus__route'
            ).get(
                driver=request.user, 
                status='active'
            )
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        limit = min(int(request.query_params.get('limit', 200)), 1000)
        
        # Координаты по возрастанию времени для построения трека
        locations = BusLocation.objects.filter(
            shift=shift
        ).only(
            'latitude', 'longitude', 'speed', 'timestamp'
        ).order_by('timestamp')[:limit]
        
        serializer = self.get_serializer(locations, many=True)
        
        return Response({
            'shift_id': shift.id,
            'bus_number': shift.bus.registration_number,
            'route_number': shift.bus.route.number if shift.bus.route else None,
            'start_time': shift.start_time,
            'duration_hours': shift.duration_hours,
            'total_points': locations.count(),
            'track': serializer.data
        })
    
    def list(self, request, *args, **kwargs):
        """
        Список координат с пагинацией.
        Обычно не используется, но доступен для отладки.
        """
        queryset = self.filter_queryset(self.get_queryset())
        queryset = queryset.order_by('-timestamp')[:100]
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    def update(self, request, *args, **kwargs):
        """Запрещаем обновление координат."""
        return Response(
            {'detail': 'Обновление координат запрещено'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )
    
    def partial_update(self, request, *args, **kwargs):
        """Запрещаем частичное обновление координат."""
        return Response(
            {'detail': 'Обновление координат запрещено'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )
    
    def destroy(self, request, *args, **kwargs):
        """Запрещаем удаление координат."""
        return Response(
            {'detail': 'Удаление координат запрещено. Используйте автоматическую очистку старых данных.'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )