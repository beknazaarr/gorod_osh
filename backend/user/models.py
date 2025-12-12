from django.contrib.auth.models import AbstractUser
from django.db import models
from django.core.exceptions import ValidationError


class User(AbstractUser):
    """
    Модель пользователя системы.
    Расширяет стандартную модель Django User.
    Включает водителей и администраторов.
    Пассажиры не регистрируются в системе.
    """
    
    ROLE_CHOICES = (
        ('driver', 'Водитель'),
        ('admin', 'Администратор'),
    )
    
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        verbose_name='Роль',
        help_text='Роль пользователя в системе'
    )
    
    phone_number = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='Номер телефона',
        help_text='Формат: +996XXXXXXXXX'
    )
    
    is_blocked = models.BooleanField(
        default=False,
        verbose_name='Заблокирован',
        help_text='Если True, пользователь не может войти в систему'
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
        verbose_name = 'Пользователь'
        verbose_name_plural = 'Пользователи'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
    
    def clean(self):
        """
        Валидация данных.
        """
        if not self.role:
            raise ValidationError('Необходимо указать роль пользователя')
        
        if self.phone_number and not self.phone_number.startswith('+'):
            raise ValidationError('Номер телефона должен начинаться с +')
    
    def save(self, *args, **kwargs):
        """
        Переопределяем метод save для дополнительных проверок.
        Заблокированный пользователь не может быть активным.
        """
        if self.is_blocked:
            self.is_active = False
        super().save(*args, **kwargs)
    
    def block(self):
        """
        Метод для блокировки пользователя.
        """
        self.is_blocked = True
        self.is_active = False
        self.save()
    
    def unblock(self):
        """
        Метод для разблокировки пользователя.
        """
        self.is_blocked = False
        self.is_active = True
        self.save()