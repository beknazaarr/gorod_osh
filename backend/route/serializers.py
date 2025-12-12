from rest_framework import serializers
from .models import Route


class RouteSerializer(serializers.ModelSerializer):
    """
    Полный сериализатор маршрута.
    Включает все данные включая path (путь на карте).
    """
    bus_type_display = serializers.CharField(source='get_bus_type_display', read_only=True)
    active_buses_count = serializers.IntegerField(read_only=True)
    
    class Meta:
        model = Route
        fields = [
            'id', 'number', 'name', 'bus_type', 'bus_type_display',
            'start_point', 'end_point', 'start_coordinates', 'end_coordinates',
            'path', 'working_hours', 'is_active', 'active_buses_count',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'active_buses_count']


class RouteListSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для списка маршрутов.
    Без path (чтобы уменьшить объём данных).
    """
    bus_type_display = serializers.CharField(source='get_bus_type_display', read_only=True)
    active_buses_count = serializers.IntegerField(read_only=True)
    
    class Meta:
        model = Route
        fields = [
            'id', 'number', 'name', 'bus_type', 'bus_type_display',
            'start_point', 'end_point', 'working_hours', 'is_active',
            'active_buses_count'
        ]


class RouteCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Сериализатор для создания и обновления маршрута.
    """
    class Meta:
        model = Route
        fields = [
            'number', 'name', 'bus_type', 'start_point', 'end_point',
            'start_coordinates', 'end_coordinates', 'path',
            'working_hours', 'is_active'
        ]
    
    def validate_start_coordinates(self, value):
        """
        Валидация координат начальной точки.
        """
        if not isinstance(value, dict):
            raise serializers.ValidationError("Должен быть объект")
        if 'lat' not in value or 'lng' not in value:
            raise serializers.ValidationError("Должен содержать lat и lng")
        return value
    
    def validate_end_coordinates(self, value):
        """
        Валидация координат конечной точки.
        """
        if not isinstance(value, dict):
            raise serializers.ValidationError("Должен быть объект")
        if 'lat' not in value or 'lng' not in value:
            raise serializers.ValidationError("Должен содержать lat и lng")
        return value
    
    def validate_path(self, value):
        """
        Валидация пути маршрута.
        """
        if not isinstance(value, list):
            raise serializers.ValidationError("Должен быть массивом")
        if len(value) < 2:
            raise serializers.ValidationError("Должен содержать минимум 2 точки")
        
        for i, point in enumerate(value):
            if not isinstance(point, dict):
                raise serializers.ValidationError(f"Точка {i} должна быть объектом")
            if 'lat' not in point or 'lng' not in point:
                raise serializers.ValidationError(f"Точка {i} должна содержать lat и lng")
        
        return value