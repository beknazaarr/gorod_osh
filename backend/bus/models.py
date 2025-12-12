from django.db import models
from django.conf import settings
from django.core.validators import MinLengthValidator
from django.core.exceptions import ValidationError


class Bus(models.Model):
    """
    Модель автобуса/троллейбуса/маршрутки.
    Представляет физическое транспортное средство.
    """
    
    BUS_TYPE_CHOICES = (
        ('bus', 'Автобус'),
        ('trolleybus', 'Троллейбус'),
        ('electric_bus', 'Электробус'),
        ('minibus', 'Маршрутка'),
    )
    
    registration_number = models.CharField(
        max_length=20,
        unique=True,
        validators=[MinLengthValidator(3)],
        verbose_name='Гос. номер',
        help_text='Например: 01ABC123, KG 123 BCD'
    )
    
    bus_type = models.CharField(
        max_length=20,
        choices=BUS_TYPE_CHOICES,
        verbose_name='Тип транспорта'
    )
    
    model = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='Модель',
        help_text='Например: Mercedes-Benz Sprinter, ПАЗ-32054'
    )
    
    capacity = models.IntegerField(
        blank=True,
        null=True,
        verbose_name='Вместимость',
        help_text='Количество пассажиров'
    )
    
    route = models.ForeignKey(
        'route.Route',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='buses',
        verbose_name='Маршрут',
        help_text='Маршрут, на котором работает автобус'
    )
    
    assigned_driver = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'role': 'driver'},
        related_name='assigned_buses',
        verbose_name='Назначенный водитель',
        help_text='Водитель, закреплённый за этим автобусом'
    )
    
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен',
        help_text='Если False, автобус на ремонте или списан'
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
        verbose_name = 'Автобус'
        verbose_name_plural = 'Автобусы'
        ordering = ['registration_number']
        indexes = [
            models.Index(fields=['registration_number']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        route_info = f" (Маршрут {self.route.number})" if self.route else ""
        return f"{self.registration_number}{route_info}"
    
    def clean(self):
        """
        Валидация данных.
        """
        if self.capacity is not None and self.capacity <= 0:
            raise ValidationError('Вместимость должна быть положительным числом')
        
        if self.assigned_driver and self.assigned_driver.role != 'driver':
            raise ValidationError('Назначенный пользователь должен быть водителем')
    
    def save(self, *args, **kwargs):
        """
        Переопределяем save для вызова валидации.
        """
        self.clean()
        super().save(*args, **kwargs)
    
    @property
    def is_on_route(self):
        """
        Проверяет, находится ли автобус сейчас на маршруте (есть ли активная смена).
        """
        from shift.models import Shift
        
        return Shift.objects.filter(
            bus=self,
            status='active'
        ).exists()
    
    @property
    def current_location(self):
        """
        Возвращает последнюю координату ТОЛЬКО если есть активная смена.
        """
        from shift.models import Shift
        from busLocation.models import BusLocation
    
        # Проверяем есть ли активная смена
        active_shift = Shift.objects.filter(
            bus=self,
            status='active'
        ).first()
    
        if not active_shift:
            return None
    
        return BusLocation.objects.filter(
        shift=active_shift
        ).order_by('-timestamp').first()