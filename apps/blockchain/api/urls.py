# -*- coding: utf-8 -*-
#
"""
Blockchain API URL Configuration

API Endpoints:
    /api/v1/blockchain/investigations/              - Investigation CRUD
    /api/v1/blockchain/investigations/{id}/archive/ - Archive investigation
    /api/v1/blockchain/investigations/{id}/reopen/  - Reopen investigation
    /api/v1/blockchain/evidence/                    - Evidence upload/list
    /api/v1/blockchain/evidence/{id}/download/      - Download evidence
    /api/v1/blockchain/evidence/{id}/verify/        - Verify evidence integrity
    /api/v1/blockchain/transactions/                - Blockchain transaction history
    /api/v1/blockchain/guid/resolve/                - GUID resolution (Court only)
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'blockchain'

# Create router for ViewSets
router = DefaultRouter()
router.register(r'investigations', views.InvestigationViewSet, basename='investigation')
router.register(r'evidence', views.EvidenceViewSet, basename='evidence')
router.register(r'transactions', views.BlockchainTransactionViewSet, basename='transaction')
router.register(r'guid', views.GUIDResolverViewSet, basename='guid')

urlpatterns = [
    path('', include(router.urls)),
]
