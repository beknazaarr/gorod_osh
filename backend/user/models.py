# models.py

from django.contrib.auth.models import AbstractUser
from django.db import models


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
    
    # Роль пользователя (водитель или администратор)
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        verbose_name='Роль',
        help_text='Роль пользователя в системе'
    )
    
    # Номер телефона для связи
    phone_number = models.CharField(
        max_length=20,
        blank=True,
        null=True,
        verbose_name='Номер телефона',
        help_text='Формат: +996XXXXXXXXX'
    )
    
    # Флаг блокировки пользователя
    is_blocked = models.BooleanField(
        default=False,
        verbose_name='Заблокирован',
        help_text='Если True, пользователь не может войти в систему'
    )
    
    # Дата создания аккаунта
    created_at = models.DateTimeField(
        auto_now_add=True,
        verbose_name='Дата создания'
    )
    
    # Дата последнего обновления
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
    
    def save(self, *args, **kwargs):
        """
        Переопределяем метод save для дополнительных проверок.
        Заблокированный пользователь не может быть активным.
        """
        if self.is_blocked:
            self.is_active = False
        super().save(*args, **kwargs)