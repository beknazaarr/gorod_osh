from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from .models import Route
from .serializers import (
    RouteSerializer, RouteListSerializer, RouteCreateUpdateSerializer
)


class RouteViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления маршрутами.
    
    Endpoints:
    - GET    /api/routes/         - Список всех маршрутов (без path)
    - POST   /api/routes/         - Создать маршрут
    - GET    /api/routes/{id}/    - Получить маршрут (с path)
    - PUT    /api/routes/{id}/    - Обновить маршрут
    - DELETE /api/routes/{id}/    - Удалить маршрут
    - GET    /api/routes/active/  - Активные маршруты
    - GET    /api/routes/{id}/path/ - Только путь маршрута
    """
    queryset = Route.objects.all()
    pagination_class = None
    
    def get_serializer_class(self):
        # ← ИЗМЕНИ ЭТУ ФУНКЦИЮ
        if self.action == 'list':
            return RouteSerializer  # ← вместо RouteListSerializer
        elif self.action in ['create', 'update', 'partial_update']:
            return RouteCreateUpdateSerializer
        return RouteSerializer
    
    def get_permissions(self):
        """
        Публичный доступ для GET запросов.
        Только админы могут создавать/редактировать/удалять.
        """
        if self.action in ['list', 'retrieve', 'active', 'path']:
            return [AllowAny()]
        return [IsAuthenticated()]
    
    @action(detail=False, methods=['get'])
    def active(self, request):
        """
        Получить список активных маршрутов.
        GET /api/routes/active/
        """
        active_routes = Route.objects.filter(is_active=True)
        serializer = RouteListSerializer(active_routes, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def path(self, request, pk=None):
        """
        Получить только путь маршрута (для рисования на карте).
        GET /api/routes/{id}/path/
        """
        route = self.get_object()
        return Response({
            'id': route.id,
            'number': route.number,
            'path': route.path,
            'start_coordinates': route.start_coordinates,
            'end_coordinates': route.end_coordinates
        })