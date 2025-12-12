from rest_framework import serializers
from .models import Bus
from user.serializers import DriverSerializer
from route.serializers import RouteListSerializer


class BusSerializer(serializers.ModelSerializer):
    """
    Полный сериализатор автобуса.
    Включает информацию о маршруте и водителе.
    """
    bus_type_display = serializers.CharField(source='get_bus_type_display', read_only=True)
    route_info = RouteListSerializer(source='route', read_only=True)
    driver_info = DriverSerializer(source='assigned_driver', read_only=True)
    is_on_route = serializers.BooleanField(read_only=True)
    current_location = serializers.SerializerMethodField()
    
    class Meta:
        model = Bus
        fields = [
            'id', 'registration_number', 'bus_type', 'bus_type_display',
            'model', 'capacity', 'route', 'route_info', 
            'assigned_driver', 'driver_info', 'is_active',
            'is_on_route', 'current_location',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_on_route']
    
    def get_current_location(self, obj):
        """
        Возвращает последнюю координату если есть активная смена.
        """
        location = obj.current_location
        if location:
            return {
                'latitude': float(location.latitude),
                'longitude': float(location.longitude),
                'speed': location.speed,
                'heading': location.heading,
                'timestamp': location.timestamp
            }
        return None


class BusListSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для списка автобусов.
    """
    bus_type_display = serializers.CharField(source='get_bus_type_display', read_only=True)
    route_number = serializers.CharField(source='route.number', read_only=True)
    driver_name = serializers.SerializerMethodField()
    is_on_route = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Bus
        fields = [
            'id', 'registration_number', 'bus_type', 'bus_type_display',
            'model', 'route', 'route_number', 'assigned_driver', 'driver_name',
            'is_active', 'is_on_route'
        ]
    
    def get_driver_name(self, obj):
        if obj.assigned_driver:
            return f"{obj.assigned_driver.first_name} {obj.assigned_driver.last_name}".strip() or obj.assigned_driver.username
        return None


class BusCreateUpdateSerializer(serializers.ModelSerializer):
    """
    Сериализатор для создания и обновления автобуса.
    """
    class Meta:
        model = Bus
        fields = [
            'registration_number', 'bus_type', 'model', 'capacity',
            'route', 'assigned_driver', 'is_active'
        ]
    
    def validate_registration_number(self, value):
        """
        Валидация гос. номера.
        """
        if len(value) < 3:
            raise serializers.ValidationError("Гос. номер должен быть минимум 3 символа")
        return value.upper()
    
    def validate_capacity(self, value):
        """
        Валидация вместимости.
        """
        if value is not None and value <= 0:
            raise serializers.ValidationError("Вместимость должна быть положительным числом")
        return value
    
    def validate_assigned_driver(self, value):
        """
        Валидация водителя.
        """
        if value and value.role != 'driver':
            raise serializers.ValidationError("Назначенный пользователь должен быть водителем")
        if value and value.is_blocked:
            raise serializers.ValidationError("Нельзя назначить заблокированного водителя")
        return value


class BusLocationInfoSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для отображения автобуса на карте.
    Используется пассажирами для просмотра транспорта.
    """
    route_number = serializers.CharField(source='route.number', read_only=True)
    bus_type_display = serializers.CharField(source='get_bus_type_display', read_only=True)
    current_location = serializers.SerializerMethodField()
    
    class Meta:
        model = Bus
        fields = [
            'id', 'registration_number', 'bus_type', 'bus_type_display',
            'route_number', 'current_location'
        ]
    
    def get_current_location(self, obj):
        location = obj.current_location
        if location:
            return {
                'latitude': float(location.latitude),
                'longitude': float(location.longitude),
                'speed': location.speed,
                'heading': location.heading,
                'accuracy': location.accuracy,
                'timestamp': location.timestamp
            }
        return None