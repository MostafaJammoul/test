# -*- coding: utf-8 -*-
#
"""
Blockchain API URL Configuration

API Endpoints:
    # Core Blockchain Endpoints
    /api/v1/blockchain/investigations/              - Investigation CRUD
    /api/v1/blockchain/investigations/{id}/archive/ - Archive investigation
    /api/v1/blockchain/investigations/{id}/reopen/  - Reopen investigation
    /api/v1/blockchain/evidence/                    - Evidence upload/list
    /api/v1/blockchain/evidence/{id}/download/      - Download evidence
    /api/v1/blockchain/evidence/{id}/verify/        - Verify evidence integrity
    /api/v1/blockchain/transactions/                - Blockchain transaction history
    /api/v1/blockchain/guid/resolve/                - GUID resolution (Court only)

    # UI Enhancement Endpoints
    /api/v1/blockchain/tags/                        - Tag management (Admin only)
    /api/v1/blockchain/investigation-tags/          - Tag assignment (Admin only, max 3)
    /api/v1/blockchain/notes/                       - Investigation notes (Investigator create)
    /api/v1/blockchain/activities/                  - Activity tracking (Read-only)
    /api/v1/blockchain/activities/{id}/mark_viewed/ - Mark activity as viewed
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'blockchain'

# Create router for ViewSets
router = DefaultRouter()

# Core blockchain endpoints
router.register(r'investigations', views.InvestigationViewSet, basename='investigation')
router.register(r'evidence', views.EvidenceViewSet, basename='evidence')
router.register(r'transactions', views.BlockchainTransactionViewSet, basename='transaction')
router.register(r'guid', views.GUIDResolverViewSet, basename='guid')

# User profile endpoint
router.register(r'user-profile', views.UserBlockchainProfileViewSet, basename='user-profile')

# UI enhancement endpoints
router.register(r'tags', views.TagViewSet, basename='tag')
router.register(r'investigation-tags', views.InvestigationTagViewSet, basename='investigation-tag')
router.register(r'notes', views.InvestigationNoteViewSet, basename='note')
router.register(r'activities', views.InvestigationActivityViewSet, basename='activity')

urlpatterns = [
    path('', include(router.urls)),
]
