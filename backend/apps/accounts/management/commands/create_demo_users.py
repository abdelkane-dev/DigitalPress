from django.core.management.base import BaseCommand
from apps.accounts.models import User, PublisherProfile


class Command(BaseCommand):
    help = 'Crée les comptes de démonstration pour Digital Press'

    def handle(self, *args, **options):
        admin, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@digitalpress.com',
                'name': 'Administrateur',
                'role': 'admin',
                'is_staff': True,
                'is_superuser': True,
                'is_verified': True,
            },
        )
        admin.set_password('Admin123!')
        admin.role = 'admin'
        admin.is_staff = True
        admin.is_superuser = True
        admin.save()
        self.stdout.write(self.style.SUCCESS(
            f"{'Créé' if created else 'Mis à jour'}: admin / Admin123!"
        ))

        poster, created = User.objects.get_or_create(
            username='editeur_afrique',
            defaults={
                'email': 'editeur@afriquepress.ci',
                'name': 'Kofi Asante',
                'role': 'publisher',
                'is_verified': True,
            },
        )
        poster.set_password('Editeur@2024!')
        poster.role = 'publisher'
        poster.save()
        PublisherProfile.objects.get_or_create(
            user=poster,
            defaults={'company_name': 'Afrique Press International'},
        )
        self.stdout.write(self.style.SUCCESS(
            f"{'Créé' if created else 'Mis à jour'}: editeur_afrique / Editeur@2024!"
        ))

        reader, created = User.objects.get_or_create(
            username='lecteur1',
            defaults={
                'email': 'lecteur@digitalpress.com',
                'name': 'Lecteur Demo',
                'role': 'reader',
                'is_verified': True,
            },
        )
        reader.set_password('Lecteur@2024!')
        reader.role = 'reader'
        reader.save()
        self.stdout.write(self.style.SUCCESS(
            f"{'Créé' if created else 'Mis à jour'}: lecteur1 / Lecteur@2024!"
        ))
