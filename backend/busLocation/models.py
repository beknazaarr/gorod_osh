# models.py

from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.core.exceptions import ValidationError
from django.utils import timezone


class BusLocation(models.Model):
    """
    Модель для хранения GPS-координат автобуса.
    Каждые 5 секунд создаётся новая запись.
    ВНИМАНИЕ: Эта таблица растёт очень быстро!
    Необходимо регулярно удалять старые записи (старше 24-48 часов).
    """
    
    # Автобус
    bus = models.ForeignKey(
        'Bus',
        on_delete=models.CASCADE,
        related_name='locations',
        verbose_name='Автобус'
    )
    
    # Смена (к которой относится эта координата)
    shift = models.ForeignKey(
        'Shift',
        on_delete=models.CASCADE,
        related_name='locations',
        verbose_name='Смена'
    )
    
    # Широта (latitude)
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[
            MinValueValidator(-90),
            MaxValueValidator(90)
        ],
        verbose_name='Широта',
        help_text='Диапазон: -90 до +90'
    )
    
    # Долгота (longitude)
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=[
            MinValueValidator(-180),
            MaxValueValidator(180)
        ],
        verbose_name='Долгота',
        help_text='Диапазон: -180 до +180'
    )
    
    # Скорость в км/ч
    speed = models.FloatField(
        null=True,
        blank=True,
        validators=[MinValueValidator(0)],
        verbose_name='Скорость',
        help_text='Скорость в км/ч'
    )
    
    # Направление движения (0-360 градусов)
    heading = models.FloatField(
        null=True,
        blank=True,
        validators=[
            MinValueValidator(0),
            MaxValueValidator(360)
        ],
        verbose_name='Направление',
        help_text='0° = север, 90° = восток, 180° = юг, 270° = запад'
    )
    
    # Точность GPS в метрах
    accuracy = models.FloatField(
        null=True,
        blank=True,
        validators=[MinValueValidator(0)],
        verbose_name='Точность GPS',
        help_text='Точность в метрах'
    )
    
    # Время получения координаты
    timestamp = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Время',
        db_index=True
    )
    
    class Meta:
        verbose_name = 'Местоположение автобуса'
        verbose_name_plural = 'Местоположения автобусов'
        ordering = ['-timestamp']
        indexes = [
            # Индекс для быстрого поиска последней координаты автобуса
            models.Index(fields=['bus', '-timestamp']),
            # Индекс для истории смены
            models.Index(fields=['shift', '-timestamp']),
            # Индекс для удаления старых записей
            models.Index(fields=['timestamp']),
        ]
    
    def __str__(self):
        return f"{self.bus.registration_number} в {self.timestamp.strftime('%H:%M:%S')}"
    
    def clean(self):
        """
        Валидация данных.
        """
        # Проверка что координаты в допустимом диапазоне
        if not (-90 <= float(self.latitude) <= 90):
            raise ValidationError('Широта должна быть в диапазоне от -90 до +90')
        
        if not (-180 <= float(self.longitude) <= 180):
            raise ValidationError('Долгота должна быть в диапазоне от -180 до +180')
        
        # Проверка что смена активна
        if self.shift.status != 'active':
            raise ValidationError('Нельзя добавить координаты для завершённой смены')
        
        # Проверка что автобус в shift совпадает с bus
        if self.shift.bus != self.bus:
            raise ValidationError('Автобус не совпадает с автобусом в смене')
        
        # Проверка что timestamp не в будущем
        if hasattr(self, 'timestamp') and self.timestamp > timezone.now():
            raise ValidationError('Время не может быть в будущем')
    
    def save(self, *args, **kwargs):
        """
        Переопределяем save для вызова валидации.
        """
        self.clean()
        super().save(*args, **kwargs)
    
    @property
    def coordinates(self):
        """
        Возвращает координаты в виде словаря.
        """
        return {
            'lat': float(self.latitude),
            'lng': float(self.longitude)
        }
    
    @classmethod
    def get_latest_for_bus(cls, bus_id):
        """
        Возвращает последнюю координату для автобуса.
        """
        return cls.objects.filter(
            bus_id=bus_id
        ).order_by('-timestamp').first()
    
    @classmethod
    def cleanup_old_records(cls, days=2):
        """
        Удаляет записи старше указанного количества дней.
        Рекомендуется запускать как cron-задачу каждый день.
        """
        from datetime import timedelta
        
        cutoff_date = timezone.now() - timedelta(days=days)
        deleted_count = cls.objects.filter(
            timestamp__lt=cutoff_date
        ).delete()[0]
        
        return deleted_count