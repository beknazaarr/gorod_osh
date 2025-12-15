from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import timedelta
from .models import Shift
from .serializers import (
    ShiftSerializer, ShiftListSerializer, ShiftStartSerializer,
    ShiftHistorySerializer
)
import json


class ShiftViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления сменами.
    """
    queryset = Shift.objects.select_related('driver', 'bus', 'bus__route').all()
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        """
        Возвращает нужный сериализатор в зависимости от действия.
        """
        if self.action == 'list':
            return ShiftListSerializer
        elif self.action == 'start':
            return ShiftStartSerializer
        elif self.action in ['history', 'my_history']:
            return ShiftHistorySerializer
        return ShiftSerializer
    
    def get_queryset(self):
        """
        Водители видят только свои смены.
        Админы видят все смены.
        """
        if self.request.user.role == 'driver':
            return self.queryset.filter(driver=self.request.user)
        return self.queryset
    
    @action(detail=False, methods=['post'])
    def start(self, request):
        """
        Начать новую смену.
        POST /api/shifts/start/
        Body: {
            "bus": 1
        }
        """
        # ОТЛАДКА
        print(f"\n{'='*60}")
        print(f"🚀 ЗАПРОС НА НАЧАЛО СМЕНЫ")
        print(f"{'='*60}")
        print(f"👤 Пользователь: {request.user}")
        print(f"📦 Данные запроса: {json.dumps(request.data, indent=2, ensure_ascii=False)}")
        
        serializer = self.get_serializer(data=request.data, context={'request': request})
        
        if not serializer.is_valid():
            print(f"❌ ОШИБКИ ВАЛИДАЦИИ:")
            for field, errors in serializer.errors.items():
                print(f"   - {field}: {errors}")
            print(f"{'='*60}\n")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            shift = serializer.save()
            print(f"✅ Смена начата:")
            print(f"   - ID смены: {shift.id}")
            print(f"   - Автобус: {shift.bus.registration_number}")
            print(f"   - Маршрут: {shift.bus.route.number if shift.bus.route else 'НЕТ'}")
            print(f"{'='*60}\n")
            
            response_serializer = ShiftSerializer(shift)
            return Response(
                response_serializer.data,
                status=status.HTTP_201_CREATED
            )
        except Exception as e:
            print(f"❌ ОШИБКА ПРИ СОХРАНЕНИИ СМЕНЫ:")
            print(f"   - {type(e).__name__}: {e}")
            print(f"{'='*60}\n")
            return Response(
                {'detail': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=False, methods=['post'])
    def complete(self, request):
        """
        Завершить текущую активную смену.
        POST /api/shifts/complete/
        """
        try:
            shift = Shift.objects.get(
                driver=request.user,
                status='active'
            )
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        shift.complete()
        serializer = ShiftSerializer(shift)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def active(self, request):
        """
        Получить список активных смен.
        GET /api/shifts/active/
        """
        active_shifts = self.get_queryset().filter(status='active')
        serializer = ShiftListSerializer(active_shifts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'], url_path='my-active')
    def my_active(self, request):
        """
        Получить свою активную смену.
        GET /api/shifts/my-active/
        """
        try:
            shift = Shift.objects.get(
                driver=request.user,
                status='active'
            )
            serializer = ShiftSerializer(shift)
            return Response(serializer.data)
        except Shift.DoesNotExist:
            return Response(
                {'detail': 'У вас нет активной смены'},
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=False, methods=['get'], url_path='my-history')
    def my_history(self, request):
        """
        Получить историю своих смен.
        GET /api/shifts/my-history/
        
        Query params:
        - days: количество дней (по умолчанию 30)
        """
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now() - timedelta(days=days)
        
        shifts = Shift.objects.filter(
            driver=request.user,
            status='completed',
            start_time__gte=start_date
        ).order_by('-start_time')
        
        serializer = self.get_serializer(shifts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def history(self, request):
        """
        Получить историю всех смен (только для админов).
        GET /api/shifts/history/
        
        Query params:
        - days: количество дней (по умолчанию 30)
        - driver: ID водителя (опционально)
        - bus: ID автобуса (опционально)
        """
        if request.user.role != 'admin':
            return Response(
                {'detail': 'Доступно только администраторам'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now() - timedelta(days=days)
        
        shifts = Shift.objects.filter(
            status='completed',
            start_time__gte=start_date
        )
        
        # Фильтр по водителю
        driver_id = request.query_params.get('driver')
        if driver_id:
            shifts = shifts.filter(driver_id=driver_id)
        
        # Фильтр по автобусу
        bus_id = request.query_params.get('bus')
        if bus_id:
            shifts = shifts.filter(bus_id=bus_id)
        
        shifts = shifts.order_by('-start_time')
        
        serializer = self.get_serializer(shifts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """
        Получить статистику по сменам.
        GET /api/shifts/statistics/
        
        Query params:
        - days: количество дней (по умолчанию 30)
        """
        if request.user.role != 'admin':
            return Response(
                {'detail': 'Доступно только администраторам'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        days = int(request.query_params.get('days', 30))
        start_date = timezone.now() - timedelta(days=days)
        
        # Общая статистика
        total_shifts = Shift.objects.filter(
            start_time__gte=start_date
        ).count()
        
        active_shifts = Shift.objects.filter(
            status='active'
        ).count()
        
        completed_shifts = Shift.objects.filter(
            status='completed',
            start_time__gte=start_date
        ).count()
        
        # Средняя продолжительность
        completed = Shift.objects.filter(
            status='completed',
            start_time__gte=start_date
        )
        
        if completed.exists():
            total_hours = sum([s.duration_hours for s in completed])
            avg_duration = total_hours / completed.count()
        else:
            avg_duration = 0
        
        return Response({
            'period_days': days,
            'total_shifts': total_shifts,
            'active_shifts': active_shifts,
            'completed_shifts': completed_shifts,
            'average_duration_hours': round(avg_duration, 2)
        })
    
    def destroy(self, request, *args, **kwargs):
        """
        Можно удалить только завершённую смену.
        """
        shift = self.get_object()
        
        if shift.status == 'active':
            return Response(
                {'detail': 'Нельзя удалить активную смену. Завершите её сначала.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        return super().destroy(request, *args, **kwargs)