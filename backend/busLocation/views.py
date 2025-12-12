from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from django.db.models import OuterRef, Subquery
from datetime import timedelta
from .models import BusLocation
from shift.models import Shift
from .serializers import (
    BusLocationSerializer, BusLocationCreateSerializer,
    BusLocationListSerializer, BusLocationTrackSerializer
)
from user.permissions import IsDriver


class BusLocationViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления местоположениями автобусов.
    
    Endpoints:
    - GET    /api/locations/              - Список координат
    - POST   /api/locations/              - Добавить координату (водитель)
    - GET    /api/locations/{id}/         - Получить координату
    - POST   /api/locations/send/         - Отправить координату (упрощённый endpoint)
    - GET    /api/locations/latest/       - Последние координаты всех автобусов
    - GET    /api/locations/bus/{bus_id}/ - История координат автобуса
    - GET    /api/locations/shift/{shift_id}/ - Координаты конкретной смены
    - GET    /api/locations/track/        - Трек текущей смены водителя
    """
    queryset = BusLocation.objects.select_related('bus', 'shift', 'shift__driver').all()
    
    def get_serializer_class(self):
        """
        Возвращает нужный сериализатор в зависимости от действия.
        """
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
        """
        # Получаем активную смену
        try:
            shift = Shift.objects.select_related('bus', 'bus__route').get(
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
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    
    @action(detail=False, methods=['post'])
    def send(self, request):
        """
        Упрощённый endpoint для отправки координаты.
        POST /api/locations/send/
        Body: {
            "latitude": 42.874635,
            "longitude": 74.569812,
            "speed": 45.5,
            "heading": 180,
            "accuracy": 10
        }
        """
        return self.create(request)
    
    @action(detail=False, methods=['get'])
    def latest(self, request):
        """
        Получить последние координаты всех активных автобусов.
        Оптимизирован: один запрос вместо N+1.
        GET /api/locations/latest/
        
        Query params:
        - route: ID маршрута (опционально)
        - bus_type: тип транспорта (опционально)
        """
        # Подзапрос для получения последней координаты каждой смены
        latest_location_subquery = BusLocation.objects.filter(
            shift=OuterRef('pk')
        ).order_by('-timestamp').values('id')[:1]
        
        # Получаем активные смены с аннотацией ID последней координаты
        active_shifts = Shift.objects.filter(
            status='active'
        ).select_related(
            'bus',
            'bus__route'
        ).annotate(
            latest_location_id=Subquery(latest_location_subquery)
        )
        
        # Фильтр по маршруту
        route_id = request.query_params.get('route')
        if route_id:
            active_shifts = active_shifts.filter(bus__route_id=route_id)
        
        # Фильтр по типу транспорта
        bus_type = request.query_params.get('bus_type')
        if bus_type:
            active_shifts = active_shifts.filter(bus__bus_type=bus_type)
        
        # Получаем ID всех последних координат
        location_ids = [
            shift.latest_location_id 
            for shift in active_shifts 
            if shift.latest_location_id
        ]
        
        # Получаем все координаты одним запросом
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
        limit = min(int(request.query_params.get('limit', 100)), 1000)  # Ограничение
        
        start_time = timezone.now() - timedelta(hours=hours)
        
        locations = BusLocation.objects.filter(
            bus_id=bus_id,
            timestamp__gte=start_time
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
        limit = min(int(request.query_params.get('limit', 500)), 2000)  # Ограничение
        
        # Проверяем существование смены
        try:
            shift = Shift.objects.get(id=shift_id)
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'Смена не найдена'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        locations = BusLocation.objects.filter(
            shift_id=shift_id
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
            shift = Shift.objects.select_related('bus', 'bus__route').get(
                driver=request.user, 
                status='active'
            )
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        limit = min(int(request.query_params.get('limit', 200)), 1000)  # Ограничение
        
        # Координаты по возрастанию времени для построения трека
        locations = BusLocation.objects.filter(
            shift=shift
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
        
        # Ограничиваем последними 100 записями по умолчанию
        queryset = queryset.order_by('-timestamp')[:100]
        
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    
    def update(self, request, *args, **kwargs):
        """
        Запрещаем обновление координат.
        """
        return Response(
            {'detail': 'Обновление координат запрещено'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )
    
    def partial_update(self, request, *args, **kwargs):
        """
        Запрещаем частичное обновление координат.
        """
        return Response(
            {'detail': 'Обновление координат запрещено'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )
    
    def destroy(self, request, *args, **kwargs):
        """
        Запрещаем удаление координат.
        Координаты - это логи, их нельзя удалять вручную.
        """
        return Response(
            {'detail': 'Удаление координат запрещено. Используйте автоматическую очистку старых данных.'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )