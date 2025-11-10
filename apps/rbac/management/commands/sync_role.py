#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Django management command to sync builtin roles to the database.

This command synchronizes all predefined roles (including blockchain roles)
from rbac.builtin.BuiltinRole to the database.

Usage:
    python manage.py sync_role
"""

from django.core.management.base import BaseCommand
from rbac.builtin import BuiltinRole


class Command(BaseCommand):
    help = 'Sync builtin roles (including blockchain roles) to the database'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE('Syncing builtin roles to database...'))

        try:
            BuiltinRole.sync_to_db(show_msg=True)
            self.stdout.write(self.style.SUCCESS('✓ Builtin roles synced successfully'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'✗ Failed to sync roles: {e}'))
            raise
