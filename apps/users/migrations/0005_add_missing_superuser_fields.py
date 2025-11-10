# Generated manually to fix missing AbstractUser fields
# The initial migration incorrectly used models.Model as base instead of AbstractUser
# This adds the missing is_superuser and is_staff fields required for Django admin

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0004_fix_user_wechat_phone'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='is_superuser',
            field=models.BooleanField(
                default=False,
                help_text='Designates that this user has all permissions without explicitly assigning them.',
                verbose_name='superuser status'
            ),
        ),
        migrations.AddField(
            model_name='user',
            name='is_staff',
            field=models.BooleanField(
                default=False,
                help_text='Designates whether the user can log into this admin site.',
                verbose_name='staff status'
            ),
        ),
    ]
