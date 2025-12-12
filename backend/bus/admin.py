from django.contrib import admin
from .models import Bus


@admin.register(Bus)
class BusAdmin(admin.ModelAdmin):
    list_display = ('registration_number', 'bus_type', 'route', 'assigned_driver', 'is_active', 'is_on_route')
    list_filter = ('bus_type', 'is_active')
    search_fields = ('registration_number', 'model')
    readonly_fields = ('created_at', 'updated_at', 'is_on_route', 'current_location')
    
    fieldsets = (
        ('Основная информация', {
            'fields': ('registration_number', 'bus_type', 'model', 'capacity', 'is_active')
        }),
        ('Назначение', {
            'fields': ('route', 'assigned_driver')
        }),
        ('Статус', {
            'fields': ('is_on_route', 'current_location', 'created_at', 'updated_at')
        }),
    )