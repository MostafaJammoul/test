# -*- coding: utf-8 -*-
#
from django.apps import AppConfig


class BlockchainConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'blockchain'
    verbose_name = 'Blockchain Chain of Custody'

    def ready(self):
        from . import signal_handlers  # noqa
