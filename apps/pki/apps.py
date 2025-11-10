# -*- coding: utf-8 -*-
#
from django.apps import AppConfig


class PKIConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'pki'
    verbose_name = 'PKI (Certificate Authority)'

    def ready(self):
        """Import signal handlers when app is ready"""
        import pki.signals  # noqa
