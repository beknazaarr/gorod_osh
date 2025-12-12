from django.contrib import admin
from .models import Route


@admin.register(Route)
class RouteAdmin(admin.ModelAdmin):
    list_display = ('number', 'name', 'bus_type', 'is_active', 'working_hours', 'created_at')
    list_filter = ('bus_type', 'is_active')
    search_fields = ('number', 'name', 'start_point', 'end_point')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        ('Основная информация', {
            'fields': ('number', 'name', 'bus_type', 'is_active')
        }),
        ('Маршрут', {
            'fields': ('start_point', 'end_point', 'start_coordinates', 'end_coordinates', 'path')
        }),
        ('Дополнительно', {
            'fields': ('working_hours', 'created_at', 'updated_at')
        }),
    )