"""
PKI API URLs
"""
from rest_framework.routers import DefaultRouter
from . import certificate

app_name = 'pki'

router = DefaultRouter()
router.register('certificates', certificate.CertificateViewSet, basename='certificate')

urlpatterns = router.urls
