# Fix database-level defaults for is_superuser and is_staff fields
# Django's AddField with default doesn't always set database-level defaults
# This migration explicitly sets the database defaults using SQL

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0005_add_missing_superuser_fields'),
    ]

    operations = [
        # Set database-level defaults for is_superuser and is_staff
        migrations.RunSQL(
            sql=[
                'ALTER TABLE users_user ALTER COLUMN is_superuser SET DEFAULT false;',
                'ALTER TABLE users_user ALTER COLUMN is_staff SET DEFAULT false;',
            ],
            reverse_sql=[
                'ALTER TABLE users_user ALTER COLUMN is_superuser DROP DEFAULT;',
                'ALTER TABLE users_user ALTER COLUMN is_staff DROP DEFAULT;',
            ],
        ),
    ]
