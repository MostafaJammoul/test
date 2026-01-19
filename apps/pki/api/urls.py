"""
PKI API URLs
"""
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'pki'

router = DefaultRouter()
# Use UserCertificateViewSet which has issue/revoke/renew actions
router.register('certificates', views.UserCertificateViewSet, basename='certificate')

urlpatterns = router.urls
