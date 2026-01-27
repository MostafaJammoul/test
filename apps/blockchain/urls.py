# -*- coding: utf-8 -*-
#
"""
Blockchain Chain of Custody URL Configuration

URL patterns for blockchain UI views (not API endpoints)
API endpoints are in blockchain/api/urls.py
"""
from django.urls import path
from . import views

app_name = 'blockchain'

urlpatterns = [
    # Main blockchain dashboard
    path('dashboard/', views.blockchain_dashboard, name='dashboard'),

    # Alternative class-based view URL
    # path('dashboard/', views.BlockchainDashboardView.as_view(), name='dashboard'),
]
