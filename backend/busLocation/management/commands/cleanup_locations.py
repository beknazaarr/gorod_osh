# backend/busLocation/management/commands/cleanup_locations.py

from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from busLocation.models import BusLocation


class Command(BaseCommand):
    help = 'Удаляет старые координаты автобусов (старше 7 дней)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--days',
            type=int,
            default=7,
            help='Количество дней для хранения координат (по умолчанию 7)'
        )
        parser.add_argument(
            '--batch-size',
            type=int,
            default=1000,
            help='Размер батча для удаления (по умолчанию 1000)'
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Показать что будет удалено без фактического удаления'
        )

    def handle(self, *args, **options):
        days = options['days']
        batch_size = options['batch_size']
        dry_run = options['dry_run']
        
        cutoff = timezone.now() - timedelta(days=days)
        
        self.stdout.write(f'Удаление координат старше {days} дней (до {cutoff})')
        
        # Подсчитываем сколько всего нужно удалить
        total_count = BusLocation.objects.filter(timestamp__lt=cutoff).count()
        
        if total_count == 0:
            self.stdout.write(self.style.SUCCESS('Нет координат для удаления'))
            return
        
        self.stdout.write(f'Найдено {total_count} записей для удаления')
        
        if dry_run:
            self.stdout.write(self.style.WARNING('DRY RUN - ничего не удалено'))
            return
        
        # ОПТИМИЗАЦИЯ: Батчевое удаление
        total_deleted = 0
        batch_num = 0
        
        while True:
            batch_num += 1
            
            # Получаем ID следующего батча
            ids = list(
                BusLocation.objects.filter(
                    timestamp__lt=cutoff
                ).values_list('id', flat=True)[:batch_size]
            )
            
            if not ids:
                break
            
            # Удаляем батч
            deleted_count, _ = BusLocation.objects.filter(id__in=ids).delete()
            total_deleted += deleted_count
            
            # Логируем прогресс
            progress = (total_deleted / total_count) * 100
            self.stdout.write(
                f'Батч {batch_num}: удалено {deleted_count} записей '
                f'(всего {total_deleted}/{total_count} - {progress:.1f}%)'
            )
        
        self.stdout.write(
            self.style.SUCCESS(f'✅ Успешно удалено {total_deleted} старых координат')
        )