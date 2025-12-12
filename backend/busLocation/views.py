from django.shortcuts import render

# Create your views here.
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from datetime import timedelta
from .models import BusLocation
from shift.models import Shift
from .serializers import (
    BusLocationSerializer, BusLocationCreateSerializer,
    BusLocationListSerializer, BusLocationTrackSerializer
)


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
        return [IsAuthenticated()]
    
    def create(self, request, *args, **kwargs):
        """
        Создать запись координаты.
        Доступно только водителям с активной сменой.
        """
        # Проверяем что пользователь - водитель
        if request.user.role != 'driver':
            return Response(
                {'detail': 'Только водители могут отправлять координаты'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Получаем активную смену
        try:
            shift = Shift.objects.get(driver=request.user, status='active')
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
        GET /api/locations/latest/
        
        Query params:
        - route: ID маршрута (опционально)
        - bus_type: тип транспорта (опционально)
        """
        # Получаем активные смены
        active_shifts = Shift.objects.filter(status='active')
        
        # Фильтр по маршруту
        route_id = request.query_params.get('route')
        if route_id:
            active_shifts = active_shifts.filter(bus__route_id=route_id)
        
        # Фильтр по типу транспорта
        bus_type = request.query_params.get('bus_type')
        if bus_type:
            active_shifts = active_shifts.filter(bus__bus_type=bus_type)
        
        # Получаем последнюю координату для каждой смены
        locations = []
        for shift in active_shifts:
            last_location = BusLocation.objects.filter(
                shift=shift
            ).order_by('-timestamp').first()
            
            if last_location:
                locations.append({
                    'bus_id': shift.bus.id,
                    'bus_number': shift.bus.registration_number,
                    'bus_type': shift.bus.bus_type,
                    'route_number': shift.bus.route.number if shift.bus.route else None,
                    'latitude': float(last_location.latitude),
                    'longitude': float(last_location.longitude),
                    'speed': last_location.speed,
                    'heading': last_location.heading,
                    'accuracy': last_location.accuracy,
                    'timestamp': last_location.timestamp
                })
        
        return Response(locations)
    
    @action(detail=False, methods=['get'], url_path='bus/(?P<bus_id>[^/.]+)')
    def bus_history(self, request, bus_id=None):
        """
        Получить историю координат автобуса.
        GET /api/locations/bus/{bus_id}/
        
        Query params:
        - hours: количество часов назад (по умолчанию 1)
        - limit: максимум записей (по умолчанию 100)
        """
        hours = int(request.query_params.get('hours', 1))
        limit = int(request.query_params.get('limit', 100))
        
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
        - limit: максимум записей (по умолчанию 500)
        """
        limit = int(request.query_params.get('limit', 500))
        
        locations = BusLocation.objects.filter(
            shift_id=shift_id
        ).order_by('-timestamp')[:limit]
        
        serializer = self.get_serializer(locations, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def track(self, request):
        """
        Получить трек текущей смены водителя.
        GET /api/locations/track/
        
        Query params:
        - limit: максимум записей (по умолчанию 200)
        """
        # Получаем активную смену водителя
        try:
            shift = Shift.objects.get(driver=request.user, status='active')
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        limit = int(request.query_params.get('limit', 200))
        
        locations = BusLocation.objects.filter(
            shift=shift
        ).order_by('timestamp')[:limit]  # По возрастанию для построения трека
        
        serializer = self.get_serializer(locations, many=True)
        return Response({
            'shift_id': shift.id,
            'bus_number': shift.bus.registration_number,
            'route_number': shift.bus.route.number if shift.bus.route else None,
            'start_time': shift.start_time,
            'track': serializer.data
        })
    
    def destroy(self, request, *args, **kwargs):
        """
        Запрещаем удаление координат.
        """
        return Response(
            {'detail': 'Удаление координат запрещено'},
            status=status.HTTP_405_METHOD_NOT_ALLOWED
        )