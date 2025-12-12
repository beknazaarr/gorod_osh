from django.db import models
from django.core.validators import MinLengthValidator
from django.core.exceptions import ValidationError


class Route(models.Model):
    """
    Модель маршрута общественного транспорта.
    Хранит информацию о маршруте, его пути и времени работы.
    """
    
    BUS_TYPE_CHOICES = (
        ('bus', 'Автобус'),
        ('trolleybus', 'Троллейбус'),
        ('electric_bus', 'Электробус'),
        ('minibus', 'Маршрутка'),
    )
    
    number = models.CharField(
        max_length=10,
        unique=True,
        validators=[MinLengthValidator(1)],
        verbose_name='Номер маршрута',
        help_text='Например: 1, 5, 12А, 7Т'
    )
    
    name = models.CharField(
        max_length=200,
        verbose_name='Название маршрута',
        help_text='Например: Центр - Восток'
    )
    
    bus_type = models.CharField(
        max_length=20,
        choices=BUS_TYPE_CHOICES,
        verbose_name='Тип транспорта'
    )
    
    start_point = models.CharField(
        max_length=200,
        verbose_name='Начальная точка',
        help_text='Название начальной остановки'
    )
    
    end_point = models.CharField(
        max_length=200,
        verbose_name='Конечная точка',
        help_text='Название конечной остановки'
    )
    
    start_coordinates = models.JSONField(
        verbose_name='Координаты начальной точки',
        help_text='Формат: {"lat": 42.8746, "lng": 74.5698}'
    )
    
    end_coordinates = models.JSONField(
        verbose_name='Координаты конечной точки',
        help_text='Формат: {"lat": 42.8900, "lng": 74.6100}'
    )
    
    path = models.JSONField(
        verbose_name='Путь маршрута',
        help_text='Массив координат: [{"lat": 42.8746, "lng": 74.5698}, ...]'
    )
    
    working_hours = models.CharField(
        max_length=50,
        blank=True,
        null=True,
        verbose_name='Время работы',
        help_text='Например: 05:52 - 22:11'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен',
        help_text='Если False, маршрут не показывается пассажирам'
    )
    
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания'
    )
    
    updated_at = models.DateTimeField(
        auto_now=True,
        verbose_name='Дата обновления'
    )
    
    class Meta:
        verbose_name = 'Маршрут'
        verbose_name_plural = 'Маршруты'
        ordering = ['number']
        indexes = [
            models.Index(fields=['number']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f"Маршрут {self.number}: {self.name}"
    
    def clean(self):
        """
        Валидация данных перед сохранением.
        """
        if not isinstance(self.start_coordinates, dict):
            raise ValidationError('start_coordinates должен быть словарём')
        
        if 'lat' not in self.start_coordinates or 'lng' not in self.start_coordinates:
            raise ValidationError('start_coordinates должен содержать lat и lng')
        
        if not isinstance(self.end_coordinates, dict):
            raise ValidationError('end_coordinates должен быть словарём')
        
        if 'lat' not in self.end_coordinates or 'lng' not in self.end_coordinates:
            raise ValidationError('end_coordinates должен содержать lat и lng')
        
        if not isinstance(self.path, list):
            raise ValidationError('path должен быть списком координат')
        
        if len(self.path) < 2:
            raise ValidationError('path должен содержать минимум 2 точки')
        
        for point in self.path:
            if not isinstance(point, dict) or 'lat' not in point or 'lng' not in point:
                raise ValidationError('Каждая точка в path должна содержать lat и lng')
    
    def save(self, *args, **kwargs):
        """
        Переопределяем save для вызова валидации.
        """
        self.clean()
        super().save(*args, **kwargs)
    
    @property
    def active_buses_count(self):
        """
        Возвращает количество активных автобусов на этом маршруте.
        """
        from shift.models import Shift
        
        active_shifts = Shift.objects.filter(
            status='active',
            bus__route=self
        ).count()
        
        return active_shifts