# Generated migration to add p12_bundle field for browser-importable certificates

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('pki', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='certificate',
            name='p12_bundle',
            field=models.TextField(
                blank=True,
                null=True,
                verbose_name='P12 Bundle (Base64)'
            ),
        ),
    ]
