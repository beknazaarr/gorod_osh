from django.contrib import admin
from .models import BusLocation


@admin.register(BusLocation)
class BusLocationAdmin(admin.ModelAdmin):
    list_display = ('bus', 'shift', 'latitude', 'longitude', 'speed', 'timestamp')
    list_filter = ('timestamp', 'bus')
    search_fields = ('bus__registration_number', 'shift__driver__username')
    readonly_fields = ('timestamp',)
    
    fieldsets = (
        ('Основная информация', {
            'fields': ('bus', 'shift', 'timestamp')
        }),
        ('Координаты', {
            'fields': ('latitude', 'longitude', 'accuracy')
        }),
        ('Движение', {
            'fields': ('speed', 'heading')
        }),
    )