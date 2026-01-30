# backend/route/views.py

from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.views.decorators.cache import cache_page
from django.utils.decorators import method_decorator
from django.core.cache import cache
from .models import Route
from .serializers import (
    RouteSerializer, RouteListSerializer, RouteCreateUpdateSerializer
)


class RouteViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления маршрутами.
    ОПТИМИЗИРОВАНО: добавлено кэширование для статических данных.
    """
    queryset = Route.objects.all()
    pagination_class = None
    
    def get_serializer_class(self):
        if self.action == 'list':
            return RouteSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return RouteCreateUpdateSerializer
        return RouteSerializer
    
    def get_permissions(self):
        """Публичный доступ для GET запросов."""
        if self.action in ['list', 'retrieve', 'active', 'path']:
            return [AllowAny()]
        return [IsAuthenticated()]
    
    @method_decorator(cache_page(60 * 15))  # Кэш на 15 минут
    def list(self, request, *args, **kwargs):
        """
        Список всех маршрутов.
        ОПТИМИЗИРОВАНО: результат кэшируется на 15 минут.
        """
        return super().list(request, *args, **kwargs)
    
    @method_decorator(cache_page(60 * 15))  # Кэш на 15 минут
    def retrieve(self, request, *args, **kwargs):
        """
        Получить конкретный маршрут.
        ОПТИМИЗИРОВАНО: результат кэшируется на 15 минут.
        """
        return super().retrieve(request, *args, **kwargs)
    
    @action(detail=False, methods=['get'])
    def active(self, request):
        """
        Получить список активных маршрутов.
        ОПТИМИЗИРОВАНО: результат кэшируется на 15 минут.
        """
        cache_key = 'active_routes'
        cached_data = cache.get(cache_key)
        
        if cached_data:
            return Response(cached_data)
        
        active_routes = Route.objects.filter(is_active=True)
        serializer = RouteListSerializer(active_routes, many=True)
        
        # Кэшируем на 15 минут
        cache.set(cache_key, serializer.data, 60 * 15)
        
        return Response(serializer.data)
    
    @method_decorator(cache_page(60 * 30))  # Кэш на 30 минут
    @action(detail=True, methods=['get'])
    def path(self, request, pk=None):
        """
        Получить только путь маршрута (для рисования на карте).
        ОПТИМИЗИРОВАНО: результат кэшируется на 30 минут.
        """
        route = self.get_object()
        return Response({
            'id': route.id,
            'number': route.number,
            'path': route.path,
            'start_coordinates': route.start_coordinates,
            'end_coordinates': route.end_coordinates
        })
    
    def perform_create(self, serializer):
        """При создании маршрута инвалидируем кэш."""
        serializer.save()
        cache.delete('active_routes')
    
    def perform_update(self, serializer):
        """При обновлении маршрута инвалидируем кэш."""
        serializer.save()
        cache.delete('active_routes')
        cache.delete_pattern('route_*')  # Удаляем все кэши маршрутов
    
    def perform_destroy(self, instance):
        """При удалении маршрута инвалидируем кэш."""
        instance.delete()
        cache.delete('active_routes')