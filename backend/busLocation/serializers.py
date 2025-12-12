from rest_framework import serializers
from .models import BusLocation


class BusLocationSerializer(serializers.ModelSerializer):
    """
    Полный сериализатор местоположения автобуса.
    """
    bus_number = serializers.CharField(source='bus.registration_number', read_only=True)
    driver_name = serializers.SerializerMethodField()
    
    class Meta:
        model = BusLocation
        fields = [
            'id', 'bus', 'bus_number', 'shift', 'driver_name',
            'latitude', 'longitude', 'speed', 'heading',
            'accuracy', 'timestamp'
        ]
        read_only_fields = ['id', 'timestamp']
    
    def get_driver_name(self, obj):
        driver = obj.shift.driver
        return f"{driver.first_name} {driver.last_name}".strip() or driver.username


class BusLocationCreateSerializer(serializers.ModelSerializer):
    """
    Сериализатор для создания записи местоположения.
    Используется водителями для отправки координат.
    """
    class Meta:
        model = BusLocation
        fields = [
            'latitude', 'longitude', 'speed', 'heading', 'accuracy'
        ]
    
    def validate_latitude(self, value):
        """
        Валидация широты.
        """
        if not -90 <= float(value) <= 90:
            raise serializers.ValidationError("Широта должна быть от -90 до 90")
        return value
    
    def validate_longitude(self, value):
        """
        Валидация долготы.
        """
        if not -180 <= float(value) <= 180:
            raise serializers.ValidationError("Долгота должна быть от -180 до 180")
        return value
    
    def validate_speed(self, value):
        """
        Валидация скорости.
        """
        if value is not None and value < 0:
            raise serializers.ValidationError("Скорость не может быть отрицательной")
        return value
    
    def validate_heading(self, value):
        """
        Валидация направления.
        """
        if value is not None and not 0 <= value <= 360:
            raise serializers.ValidationError("Направление должно быть от 0 до 360")
        return value
    
    def create(self, validated_data):
        """
        Автоматически добавляем bus и shift из контекста.
        """
        shift = self.context.get('shift')
        if not shift:
            raise serializers.ValidationError("Нет активной смены")
        
        validated_data['bus'] = shift.bus
        validated_data['shift'] = shift
        return super().create(validated_data)


class BusLocationListSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для списка координат.
    """
    class Meta:
        model = BusLocation
        fields = [
            'id', 'latitude', 'longitude', 'speed',
            'heading', 'accuracy', 'timestamp'
        ]


class BusLocationTrackSerializer(serializers.ModelSerializer):
    """
    Сериализатор для отображения трека автобуса (истории координат).
    """
    class Meta:
        model = BusLocation
        fields = [
            'latitude', 'longitude', 'speed', 'timestamp'
        ]