from django.db import models
from django.conf import settings
from django.core.exceptions import ValidationError
from django.utils import timezone


class Shift(models.Model):
    """
    Модель рабочей смены водителя.
    Фиксирует когда водитель начал и закончил работу на автобусе.
    Координаты GPS привязываются к смене, а не напрямую к водителю.
    """
    
    STATUS_CHOICES = (
        ('active', 'Активна'),
        ('completed', 'Завершена'),
    )
    
    driver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        limit_choices_to={'role': 'driver'},
        related_name='shifts',
        verbose_name='Водитель'
    )
    
    bus = models.ForeignKey(
        'bus.Bus',
        on_delete=models.CASCADE,
        related_name='shifts',
        verbose_name='Автобус'
    )
    
    start_time = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Время начала смены',
        help_text='Заполняется автоматически при создании'
    )
    
    end_time = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Время окончания смены',
        help_text='Заполняется когда водитель завершает смену'
    )
    
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='active',
        verbose_name='Статус смены'
    )
    
    class Meta:
        verbose_name = 'Смена'
        verbose_name_plural = 'Смены'
        ordering = ['-start_time']
        indexes = [
            models.Index(fields=['driver', 'status']),
            models.Index(fields=['bus', 'status']),
            models.Index(fields=['status', '-start_time']),
        ]
        constraints = [
            # Один автобус - одна активная смена
            models.UniqueConstraint(
                fields=['bus'],
                condition=models.Q(status='active'),
                name='unique_active_shift_per_bus',
                violation_error_message='На этом автобусе уже есть активная смена'
            ),
            # Один водитель - одна активная смена
            models.UniqueConstraint(
                fields=['driver'],
                condition=models.Q(status='active'),
                name='unique_active_shift_per_driver',
                violation_error_message='У водителя уже есть активная смена'
            ),
        ]
    
    def __str__(self):
        return f"Смена #{self.id}: {self.driver.username} на {self.bus.registration_number}"
    
    def clean(self):
        """
        Валидация данных перед сохранением.
        """
        # Проверка роли
        if self.driver.role != 'driver':
            raise ValidationError({
                'driver': 'Пользователь должен быть водителем'
            })
        
        # Проверка блокировки
        if self.driver.is_blocked:
            raise ValidationError({
                'driver': f'Водитель {self.driver.username} заблокирован и не может начать смену'
            })
        
        # Проверка активности автобуса
        if not self.bus.is_active:
            raise ValidationError({
                'bus': f'Автобус {self.bus.registration_number} не активен'
            })
        
        # Проверка времени окончания
        if self.end_time and self.start_time and self.end_time < self.start_time:
            raise ValidationError({
                'end_time': 'Время окончания не может быть раньше времени начала'
            })
        
        # Проверка логики статуса
        if self.status == 'completed' and not self.end_time:
            raise ValidationError({
                'status': 'Завершённая смена должна иметь время окончания'
            })
        
        if self.status == 'active' and self.end_time:
            raise ValidationError({
                'status': 'Активная смена не может иметь время окончания'
            })
    
    def save(self, *args, **kwargs):
        """
        Переопределяем save для вызова валидации.
        """
        # Вызываем clean для валидации
        self.full_clean()
        super().save(*args, **kwargs)
    
    def complete(self):
        """
        Метод для завершения смены.
        Устанавливает end_time и меняет статус на 'completed'.
        """
        if self.status == 'completed':
            raise ValidationError('Смена уже завершена')
        
        self.end_time = timezone.now()
        self.status = 'completed'
        self.save()
        
        return self
    
    @property
    def duration(self):
        """
        Возвращает продолжительность смены как timedelta.
        """
        if self.end_time:
            return self.end_time - self.start_time
        else:
            return timezone.now() - self.start_time
    
    @property
    def duration_hours(self):
        """
        Возвращает продолжительность смены в часах (float).
        """
        duration = self.duration
        return round(duration.total_seconds() / 3600, 2)
    
    @property
    def duration_minutes(self):
        """
        Возвращает продолжительность смены в минутах (int).
        """
        duration = self.duration
        return int(duration.total_seconds() / 60)
    
    @property
    def is_active(self):
        """
        Проверяет активна ли смена.
        """
        return self.status == 'active'
    
    @property
    def last_location(self):
        """
        Возвращает последнюю координату этой смены.
        Используется кеширование для оптимизации.
        """
        if not hasattr(self, '_cached_last_location'):
            from busLocation.models import BusLocation
            
            self._cached_last_location = BusLocation.objects.filter(
                shift=self
            ).order_by('-timestamp').first()
        
        return self._cached_last_location
    
    @property
    def total_locations(self):
        """
        Возвращает количество записанных координат за смену.
        """
        from busLocation.models import BusLocation
        
        return BusLocation.objects.filter(shift=self).count()
    
    @property
    def average_speed(self):
        """
        Возвращает среднюю скорость за смену (км/ч).
        """
        from busLocation.models import BusLocation
        from django.db.models import Avg
        
        result = BusLocation.objects.filter(
            shift=self,
            speed__isnull=False
        ).aggregate(avg_speed=Avg('speed'))
        
        avg = result.get('avg_speed')
        return round(avg, 2) if avg else None
    
    def get_route_info(self):
        """
        Возвращает информацию о маршруте.
        """
        if self.bus.route:
            return {
                'id': self.bus.route.id,
                'number': self.bus.route.number,
                'name': self.bus.route.name
            }
        return None
    
    def can_be_deleted(self):
        """
        Проверяет можно ли удалить смену.
        Активные смены удалять нельзя.
        """
        return self.status == 'completed'
    
    @classmethod
    def get_active_shifts_count(cls):
        """
        Возвращает количество активных смен в системе.
        """
        return cls.objects.filter(status='active').count()
    
    @classmethod
    def get_driver_active_shift(cls, driver):
        """
        Возвращает активную смену водителя или None.
        """
        try:
            return cls.objects.select_related('bus', 'bus__route').get(
                driver=driver,
                status='active'
            )
        except cls.DoesNotExist:
            return None
    
    @classmethod
    def get_bus_active_shift(cls, bus):
        """
        Возвращает активную смену автобуса или None.
        """
        try:
            return cls.objects.select_related('driver').get(
                bus=bus,
                status='active'
            )
        except cls.DoesNotExist:
            return None