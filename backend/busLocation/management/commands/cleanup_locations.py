from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta

class Command(BaseCommand):
    def handle(self, *args, **options):
        # Удаляем координаты старше 7 дней
        cutoff = timezone.now() - timedelta(days=7)
        deleted = BusLocation.objects.filter(
            timestamp__lt=cutoff
        ).delete()
        self.stdout.write(f"Deleted {deleted[0]} old locations")