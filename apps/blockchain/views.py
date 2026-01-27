# -*- coding: utf-8 -*-
#
"""
Blockchain Chain of Custody Views

Django views for rendering blockchain UI templates
"""
from django.contrib.auth.decorators import login_required
from django.shortcuts import render
from django.views.generic import TemplateView
from django.utils.decorators import method_decorator


@method_decorator(login_required, name='dispatch')
class BlockchainDashboardView(TemplateView):
    """
    Main Blockchain Dashboard

    Renders role-based dashboard for blockchain evidence management.
    UI dynamically adapts based on user's blockchain role:
    - Investigator: Create investigations, upload evidence
    - Auditor: Read-only access, audit logs
    - Court: Archive/reopen, GUID resolution
    - Admin: Full access
    """
    template_name = 'blockchain/dashboard.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Blockchain Chain of Custody'
        return context


@login_required
def blockchain_dashboard(request):
    """
    Function-based view for blockchain dashboard

    Alternative to class-based view for simpler use cases
    """
    return render(request, 'blockchain/dashboard.html', {
        'page_title': 'Blockchain Chain of Custody'
    })
