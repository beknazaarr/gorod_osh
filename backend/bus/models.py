# models.py

from django.db import models
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
    
    # Государственный номер автобуса
    registration_number = models.CharField(
        max_length=20,
        unique=True,
        validators=[MinLengthValidator(3)],
        verbose_name='Гос. номер',
        help_text='Например: 01ABC123, KG 123 BCD'
    )
    
    # Тип транспорта
    bus_type = models.CharField(
        max_length=20,
        choices=BUS_TYPE_CHOICES,
        verbose_name='Тип транспорта'
    )
    
    # Модель автобуса
    model = models.CharField(
        max_length=100,
        blank=True,
        null=True,
        verbose_name='Модель',
        help_text='Например: Mercedes-Benz Sprinter, ПАЗ-32054'
    )
    
    # Вместимость (количество пассажиров)
    capacity = models.IntegerField(
        blank=True,
        null=True,
        verbose_name='Вместимость',
        help_text='Количество пассажиров'
    )
    
    # Маршрут, к которому привязан автобус
    route = models.ForeignKey(
        'Route',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='buses',
        verbose_name='Маршрут',
        help_text='Маршрут, на котором работает автобус'
    )
    
    # Водитель, назначенный на автобус
    assigned_driver = models.ForeignKey(
        'User',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        limit_choices_to={'role': 'driver'},
        related_name='assigned_buses',
        verbose_name='Назначенный водитель',
        help_text='Водитель, закреплённый за этим автобусом'
    )
    
    # Активен ли автобус
    is_active = models.BooleanField(
        default=True,
        verbose_name='Активен',
        help_text='Если False, автобус на ремонте или списан'
    )
    
    # Дата добавления в систему
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания'
    )
    
    # Дата обновления
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
            models.Index(fields=['route']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        route_info = f" (Маршрут {self.route.number})" if self.route else ""
        return f"{self.registration_number}{route_info}"
    
    def clean(self):
        """
        Валидация данных.
        """
        # Проверка что capacity положительное число
        if self.capacity is not None and self.capacity <= 0:
            raise ValidationError('Вместимость должна быть положительным числом')
        
        # Проверка что assigned_driver действительно водитель
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
        from .shift import Shift
        
        return Shift.objects.filter(
            bus=self,
            status='active'
        ).exists()
    
    @property
    def current_location(self):
        """
        Возвращает последнюю известную координату автобуса.
        """
        from .bus_location import BusLocation
        
        return BusLocation.objects.filter(
            bus=self
        ).order_by('-timestamp').first()