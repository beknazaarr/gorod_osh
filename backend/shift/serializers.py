from rest_framework import serializers
from .models import Shift
from user.serializers import DriverSerializer
from bus.serializers import BusListSerializer


class ShiftSerializer(serializers.ModelSerializer):
    """
    Полный сериализатор смены.
    """
    driver_info = DriverSerializer(source='driver', read_only=True)
    bus_info = BusListSerializer(source='bus', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    duration_hours = serializers.FloatField(read_only=True)
    last_location = serializers.SerializerMethodField()
    
    class Meta:
        model = Shift
        fields = [
            'id', 'driver', 'driver_info', 'bus', 'bus_info',
            'start_time', 'end_time', 'status', 'status_display',
            'duration_hours', 'last_location'
        ]
        read_only_fields = ['id', 'start_time', 'duration_hours']
    
    def get_last_location(self, obj):
        """
        Возвращает последнюю координату смены.
        """
        location = obj.last_location
        if location:
            return {
                'latitude': float(location.latitude),
                'longitude': float(location.longitude),
                'speed': location.speed,
                'heading': location.heading,
                'timestamp': location.timestamp
            }
        return None


class ShiftListSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для списка смен.
    """
    driver_name = serializers.SerializerMethodField()
    bus_number = serializers.CharField(source='bus.registration_number', read_only=True)
    route_number = serializers.CharField(source='bus.route.number', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    duration_hours = serializers.FloatField(read_only=True)
    
    class Meta:
        model = Shift
        fields = [
            'id', 'driver', 'driver_name', 'bus', 'bus_number',
            'route_number', 'start_time', 'end_time',
            'status', 'status_display', 'duration_hours'
        ]
    
    def get_driver_name(self, obj):
        return f"{obj.driver.first_name} {obj.driver.last_name}".strip() or obj.driver.username


class ShiftStartSerializer(serializers.ModelSerializer):
    """
    Сериализатор для начала смены.
    """
    class Meta:
        model = Shift
        fields = ['bus']
    
    def validate_bus(self, value):
        """
        Валидация автобуса при начале смены.
        """
        if not value.is_active:
            raise serializers.ValidationError("Автобус не активен")
        
        # Проверяем нет ли активной смены на этом автобусе
        active_shift = Shift.objects.filter(
            bus=value,
            status='active'
        ).exists()
        
        if active_shift:
            raise serializers.ValidationError(
                f"Автобус {value.registration_number} уже занят другим водителем"
            )
        
        return value
    
    def create(self, validated_data):
        """
        Создаём смену с текущим пользователем как водителем.
        """
        driver = self.context['request'].user
        
        if driver.role != 'driver':
            raise serializers.ValidationError("Только водители могут начать смену")
        
        if driver.is_blocked:
            raise serializers.ValidationError("Заблокированный водитель не может начать смену")
        
        # Проверяем нет ли активной смены у водителя
        active_shift = Shift.objects.filter(
            driver=driver,
            status='active'
        ).exists()
        
        if active_shift:
            raise serializers.ValidationError("У вас уже есть активная смена")
        
        validated_data['driver'] = driver
        return super().create(validated_data)


class ShiftHistorySerializer(serializers.ModelSerializer):
    """
    Сериализатор для истории смен (только завершённые).
    """
    driver_name = serializers.SerializerMethodField()
    bus_number = serializers.CharField(source='bus.registration_number', read_only=True)
    route_number = serializers.CharField(source='bus.route.number', read_only=True)
    duration_hours = serializers.FloatField(read_only=True)
    
    class Meta:
        model = Shift
        fields = [
            'id', 'driver_name', 'bus_number', 'route_number',
            'start_time', 'end_time', 'duration_hours'
        ]
    
    def get_driver_name(self, obj):
        return f"{obj.driver.first_name} {obj.driver.last_name}".strip() or obj.driver.username