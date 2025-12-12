from django.contrib import admin
from .models import Shift


@admin.register(Shift)
class ShiftAdmin(admin.ModelAdmin):
    list_display = ('id', 'driver', 'bus', 'start_time', 'end_time', 'status', 'duration_hours')
    list_filter = ('status', 'start_time')
    search_fields = ('driver__username', 'bus__registration_number')
    readonly_fields = ('start_time', 'duration', 'duration_hours', 'last_location')
    
    fieldsets = (
        ('Информация о смене', {
            'fields': ('driver', 'bus', 'status')
        }),
        ('Время', {
            'fields': ('start_time', 'end_time', 'duration', 'duration_hours')
        }),
        ('Последнее местоположение', {
            'fields': ('last_location',)
        }),
    )
    
    def duration_hours(self, obj):
        return f"{obj.duration_hours:.2f} ч"
    duration_hours.short_description = 'Продолжительность'