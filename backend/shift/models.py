# models.py

from django.db import models
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
    
    # Водитель
    driver = models.ForeignKey(
        'user.User',
        on_delete=models.CASCADE,
        limit_choices_to={'role': 'driver'},
        related_name='shifts',
        verbose_name='Водитель'
    )
    
    # Автобус
    bus = models.ForeignKey(
        'bus.Bus',
        on_delete=models.CASCADE,
        related_name='shifts',
        verbose_name='Автобус'
    )
    
    # Время начала смены
    start_time = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Время начала смены',
        help_text='Заполняется автоматически при создании'
    )
    
    # Время окончания смены
    end_time = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name='Время окончания смены',
        help_text='Заполняется когда водитель завершает смену'
    )
    
    # Статус смены
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
    
    def __str__(self):
        return f"Смена #{self.id}: {self.driver.username} на {self.bus.registration_number}"
    
    def clean(self):
        """
        Валидация данных перед сохранением.
        """
        # Проверка что driver действительно водитель
        if self.driver.role != 'driver':
            raise ValidationError('Пользователь должен быть водителем')
        
        # Проверка что водитель не заблокирован
        if self.driver.is_blocked:
            raise ValidationError('Заблокированный водитель не может начать смену')
        
        # Проверка что автобус активен
        if not self.bus.is_active:
            raise ValidationError('Автобус не активен')
        
        # Проверка что end_time больше start_time
        if self.end_time and self.end_time < self.start_time:
            raise ValidationError('Время окончания не может быть раньше времени начала')
        
        # Проверка что у водителя нет другой активной смены
        if self.status == 'active' and self.pk is None:  # Только при создании
            active_shift = Shift.objects.filter(
                driver=self.driver,
                status='active'
            ).exists()
            
            if active_shift:
                raise ValidationError(
                    f'У водителя {self.driver.username} уже есть активная смена'
                )
    
    def save(self, *args, **kwargs):
        """
        Переопределяем save для вызова валидации.
        """
        self.clean()
        super().save(*args, **kwargs)
    
    def complete(self):
        """
        Метод для завершения смены.
        Устанавливает end_time и меняет статус на 'completed'.
        """
        self.end_time = timezone.now()
        self.status = 'completed'
        self.save()
    
    @property
    def duration(self):
        """
        Возвращает продолжительность смены.
        """
        if self.end_time:
            return self.end_time - self.start_time
        else:
            return timezone.now() - self.start_time
    
    @property
    def duration_hours(self):
        """
        Возвращает продолжительность смены в часах.
        """
        duration = self.duration
        return duration.total_seconds() / 3600
    
    @property
    def last_location(self):
        """
        Возвращает последнюю координату этой смены.
        """
        from busLocation.models import BusLocation
        
        return BusLocation.objects.filter(
            shift=self
        ).order_by('-timestamp').first()