from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import BusLocationViewSet

router = DefaultRouter()
router.register(r'', BusLocationViewSet, basename='buslocation')

urlpatterns = router.urls