# -*- coding: utf-8 -*-
#
"""
PKI API URL Configuration

API Endpoints:
    /api/v1/pki/ca/                           - List Certificate Authorities
    /api/v1/pki/ca/{id}/                      - Get CA detail
    /api/v1/pki/ca/{id}/cert/                 - Download CA certificate
    /api/v1/pki/certificates/                 - List user certificates
    /api/v1/pki/certificates/issue/           - Issue new certificate
    /api/v1/pki/certificates/{id}/            - Get certificate detail
    /api/v1/pki/certificates/{id}/download/   - Download certificate (.p12)
    /api/v1/pki/certificates/{id}/revoke/     - Revoke certificate
    /api/v1/pki/certificates/{id}/renew/      - Renew certificate
    /api/v1/pki/crl/                          - Download CRL
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'pki'

# Create router for ViewSets
router = DefaultRouter()
router.register(r'ca', views.CertificateAuthorityViewSet, basename='ca')
router.register(r'certificates', views.UserCertificateViewSet, basename='certificate')

urlpatterns = [
    path('', include(router.urls)),
    path('crl/', views.CertificateRevocationListView.as_view({'get': 'list'}), name='crl'),
]
