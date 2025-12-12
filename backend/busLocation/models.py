from django.db import models
from django.core.exceptions import ValidationError


class BusLocation(models.Model):
    """
    Модель местоположения автобуса.
    Хранит GPS-координаты. Каждые 5 секунд создаётся новая запись.
    """
    
    bus = models.ForeignKey(
        'bus.Bus',
        on_delete=models.CASCADE,
        related_name='locations',
        verbose_name='Автобус'
    )
    
    shift = models.ForeignKey(
        'shift.Shift',
        on_delete=models.CASCADE,
        related_name='locations',
        verbose_name='Смена',
        help_text='Координаты привязаны к смене'
    )
    
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        verbose_name='Широта',
        help_text='Диапазон: -90 до +90'
    )
    
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        verbose_name='Долгота',
        help_text='Диапазон: -180 до +180'
    )
    
    speed = models.FloatField(
        null=True,
        blank=True,
        verbose_name='Скорость',
        help_text='Скорость в км/ч'
    )
    
    heading = models.FloatField(
        null=True,
        blank=True,
        verbose_name='Направление',
        help_text='Градусы: 0-360 (0=север, 90=восток)'
    )
    
    accuracy = models.FloatField(
        null=True,
        blank=True,
        verbose_name='Точность GPS',
        help_text='Точность в метрах'
    )
    
    timestamp = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Время получения координаты'
    )
    
    class Meta:
        verbose_name = 'Местоположение автобуса'
        verbose_name_plural = 'Местоположения автобусов'
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['bus', '-timestamp']),
            models.Index(fields=['shift', '-timestamp']),
            models.Index(fields=['-timestamp']),
        ]
    
    def __str__(self):
        return f"{self.bus.registration_number} - {self.timestamp.strftime('%H:%M:%S')}"
    
    def clean(self):
        """
        Валидация координат.
        """
        if not -90 <= self.latitude <= 90:
            raise ValidationError('Широта должна быть от -90 до 90')
        
        if not -180 <= self.longitude <= 180:
            raise ValidationError('Долгота должна быть от -180 до 180')
        
        if self.speed is not None and self.speed < 0:
            raise ValidationError('Скорость не может быть отрицательной')
        
        if self.heading is not None and not 0 <= self.heading <= 360:
            raise ValidationError('Направление должно быть от 0 до 360')
    
    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)