from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from .models import User


class UserSerializer(serializers.ModelSerializer):
    """
    Сериализатор для модели User.
    Используется для GET запросов (получение данных пользователя).
    """
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'role_display', 'phone_number', 'is_blocked',
            'is_active', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_active']


class UserCreateSerializer(serializers.ModelSerializer):
    """
    Сериализатор для создания нового пользователя.
    Включает валидацию пароля.
    """
    password = serializers.CharField(
        write_only=True,
        required=True,
        validators=[validate_password],
        style={'input_type': 'password'}
    )
    password_confirm = serializers.CharField(
        write_only=True,
        required=True,
        style={'input_type': 'password'}
    )
    
    class Meta:
        model = User
        fields = [
            'username', 'email', 'password', 'password_confirm',
            'first_name', 'last_name', 'role', 'phone_number'
        ]
    
    def validate(self, attrs):
        """
        Проверка что пароли совпадают.
        """
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({
                "password": "Пароли не совпадают"
            })
        return attrs
    
    def create(self, validated_data):
        """
        Создание пользователя с хешированием пароля.
        """
        validated_data.pop('password_confirm')
        user = User.objects.create_user(**validated_data)
        return user


class UserUpdateSerializer(serializers.ModelSerializer):
    """
    Сериализатор для обновления данных пользователя.
    """
    class Meta:
        model = User
        fields = [
            'email', 'first_name', 'last_name', 'phone_number'
        ]


class ChangePasswordSerializer(serializers.Serializer):
    """
    Сериализатор для смены пароля.
    """
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(
        required=True,
        write_only=True,
        validators=[validate_password]
    )
    new_password_confirm = serializers.CharField(required=True, write_only=True)
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                "new_password": "Пароли не совпадают"
            })
        return attrs


class DriverSerializer(serializers.ModelSerializer):
    """
    Упрощённый сериализатор для водителей.
    Используется в других сериализаторах.
    """
    class Meta:
        model = User
        fields = ['id', 'username', 'first_name', 'last_name', 'phone_number']