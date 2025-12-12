from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'role', 'phone_number', 'is_blocked', 'is_active', 'created_at')
    list_filter = ('role', 'is_blocked', 'is_active')
    search_fields = ('username', 'first_name', 'last_name', 'phone_number')
    
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Дополнительная информация', {
            'fields': ('role', 'phone_number', 'is_blocked')
        }),
    )
    
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Дополнительная информация', {
            'fields': ('role', 'phone_number')
        }),
    )