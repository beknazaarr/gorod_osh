from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.db.models import Q
from .models import Bus
from .serializers import (
    BusSerializer, BusListSerializer, BusCreateUpdateSerializer,
    BusLocationInfoSerializer
)


class BusViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления автобусами.
    
    Endpoints:
    - GET    /api/buses/              - Список всех автобусов
    - POST   /api/buses/              - Создать автобус
    - GET    /api/buses/{id}/         - Получить автобус
    - PUT    /api/buses/{id}/         - Обновить автобус
    - DELETE /api/buses/{id}/         - Удалить автобус
    - GET    /api/buses/active/       - Активные автобусы
    - GET    /api/buses/available/    - Доступные автобусы (без активной смены)
    - GET    /api/buses/on-route/     - Автобусы на маршруте (с активной сменой)
    - GET    /api/buses/by-route/{route_id}/ - Автобусы конкретного маршрута
    """
    queryset = Bus.objects.select_related('route', 'assigned_driver').all()
    
    def get_serializer_class(self):
        """
        Возвращает нужный сериализатор в зависимости от действия.
        """
        if self.action == 'list':
            return BusListSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return BusCreateUpdateSerializer
        elif self.action in ['on_route', 'by_route']:
            return BusLocationInfoSerializer
        return BusSerializer
    
    def get_permissions(self):
        """
        Публичный доступ для GET запросов (пассажиры смотрят автобусы).
        Только админы могут создавать/редактировать/удалять.
        """
        if self.action in ['list', 'retrieve', 'active', 'on_route', 'by_route']:
            return [AllowAny()]
        return [IsAuthenticated()]
    
    @action(detail=False, methods=['get'])
    def active(self, request):
        """
        Получить список активных автобусов.
        GET /api/buses/active/
        """
        active_buses = self.queryset.filter(is_active=True)
        serializer = BusListSerializer(active_buses, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def available(self, request):
        """
        Получить список доступных автобусов (без активной смены).
        Используется водителями при выборе автобуса.
        GET /api/buses/available/
        """
        from shift.models import Shift
        
        # Получаем ID автобусов с активными сменами
        busy_bus_ids = Shift.objects.filter(
            status='active'
        ).values_list('bus_id', flat=True)
        
        # Исключаем занятые автобусы
        available_buses = self.queryset.filter(
            is_active=True
        ).exclude(id__in=busy_bus_ids)
        
        serializer = BusListSerializer(available_buses, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='on-route')
    def on_route(self, request):
        """
        Получить автобусы которые сейчас на маршруте (с активной сменой).
        Используется пассажирами для просмотра транспорта на карте.
        GET /api/buses/on-route/
        
        Query params:
        - route: ID маршрута (опционально)
        - bus_type: тип транспорта (опционально)
        """
        from shift.models import Shift
        
        # Получаем ID автобусов с активными сменами
        active_bus_ids = Shift.objects.filter(
            status='active'
        ).values_list('bus_id', flat=True)
        
        buses = self.queryset.filter(
            id__in=active_bus_ids,
            is_active=True
        )
        
        # Фильтр по маршруту
        route_id = request.query_params.get('route')
        if route_id:
            buses = buses.filter(route_id=route_id)
        
        # Фильтр по типу транспорта
        bus_type = request.query_params.get('bus_type')
        if bus_type:
            buses = buses.filter(bus_type=bus_type)
        
        serializer = self.get_serializer(buses, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='by-route/(?P<route_id>[^/.]+)')
    def by_route(self, request, route_id=None):
        """
        Получить автобусы конкретного маршрута которые сейчас на линии.
        GET /api/buses/by-route/{route_id}/
        """
        from shift.models import Shift
        
        # Получаем ID автобусов с активными сменами на этом маршруте
        active_bus_ids = Shift.objects.filter(
            status='active',
            bus__route_id=route_id
        ).values_list('bus_id', flat=True)
        
        buses = self.queryset.filter(
            id__in=active_bus_ids,
            route_id=route_id,
            is_active=True
        )
        
        serializer = self.get_serializer(buses, many=True)
        return Response(serializer.data)
    
    def destroy(self, request, *args, **kwargs):
        """
        Вместо удаления деактивируем автобус.
        """
        bus = self.get_object()
        
        # Проверяем нет ли активной смены
        if bus.is_on_route:
            return Response(
                {'detail': 'Нельзя удалить автобус с активной сменой'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        bus.is_active = False
        bus.save()
        return Response({'detail': f'Автобус {bus.registration_number} деактивирован'})