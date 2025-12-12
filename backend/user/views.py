from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import authenticate
from .models import User
from .serializers import (
    UserSerializer, UserCreateSerializer, UserUpdateSerializer,
    ChangePasswordSerializer, DriverSerializer
)


class UserViewSet(viewsets.ModelViewSet):
    """
    ViewSet для управления пользователями.
    
    Endpoints:
    - GET    /api/users/          - Список всех пользователей
    - POST   /api/users/          - Создать пользователя
    - GET    /api/users/{id}/     - Получить пользователя
    - PUT    /api/users/{id}/     - Обновить пользователя
    - DELETE /api/users/{id}/     - Удалить пользователя
    - GET    /api/users/me/       - Получить текущего пользователя
    - POST   /api/users/change_password/ - Сменить пароль
    - POST   /api/users/{id}/block/   - Заблокировать пользователя
    - POST   /api/users/{id}/unblock/ - Разблокировать пользователя
    - GET    /api/users/drivers/  - Список водителей
    """
    queryset = User.objects.all()
    permission_classes = [IsAuthenticated]
    
    def get_serializer_class(self):
        """
        Возвращает нужный сериализатор в зависимости от действия.
        """
        if self.action == 'create':
            return UserCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return UserUpdateSerializer
        elif self.action == 'change_password':
            return ChangePasswordSerializer
        elif self.action == 'drivers':
            return DriverSerializer
        return UserSerializer
    
    def get_permissions(self):
        """
        Разрешения: только администраторы могут управлять пользователями.
        """
        if self.action in ['create', 'update', 'partial_update', 'destroy', 'block', 'unblock']:
            return [IsAuthenticated()]
        return super().get_permissions()
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """
        Получить данные текущего пользователя.
        GET /api/users/me/
        """
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def change_password(self, request):
        """
        Сменить пароль текущего пользователя.
        POST /api/users/change_password/
        Body: {
            "old_password": "старый_пароль",
            "new_password": "новый_пароль",
            "new_password_confirm": "новый_пароль"
        }
        """
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        user = request.user
        
        # Проверяем старый пароль
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'old_password': 'Неверный пароль'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Устанавливаем новый пароль
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        
        return Response({'detail': 'Пароль успешно изменён'})
    
    @action(detail=True, methods=['post'])
    def block(self, request, pk=None):
        """
        Заблокировать пользователя.
        POST /api/users/{id}/block/
        """
        user = self.get_object()
        user.block()
        return Response({'detail': f'Пользователь {user.username} заблокирован'})
    
    @action(detail=True, methods=['post'])
    def unblock(self, request, pk=None):
        """
        Разблокировать пользователя.
        POST /api/users/{id}/unblock/
        """
        user = self.get_object()
        user.unblock()
        return Response({'detail': f'Пользователь {user.username} разблокирован'})
    
    @action(detail=False, methods=['get'])
    def drivers(self, request):
        """
        Получить список всех водителей.
        GET /api/users/drivers/
        """
        drivers = User.objects.filter(role='driver', is_active=True)
        serializer = self.get_serializer(drivers, many=True)
        return Response(serializer.data)