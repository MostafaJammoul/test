# Add investigation assignments for role-based access control
# Investigators and Auditors can only access assigned investigations

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('blockchain', '0001_initial'),
        ('users', '0005_add_missing_superuser_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='investigation',
            name='assigned_investigators',
            field=models.ManyToManyField(
                blank=True,
                related_name='assigned_investigations_as_investigator',
                to='users.User',
                verbose_name='Assigned Investigators',
                help_text='Investigators assigned to this case'
            ),
        ),
        migrations.AddField(
            model_name='investigation',
            name='assigned_auditors',
            field=models.ManyToManyField(
                blank=True,
                related_name='assigned_investigations_as_auditor',
                to='users.User',
                verbose_name='Assigned Auditors',
                help_text='Auditors assigned to this case'
            ),
        ),
    ]
