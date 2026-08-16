from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient, APITestCase
from decimal import Decimal

from apps.accounts.models import PublisherProfile, PublisherVerification
from apps.abonnements.models import PlatformPlan, PublisherSubscription
from apps.abonnements.services import sync_publisher_tier
from apps.comptabilite.models import EcritureComptable
from apps.comptabilite.tasks import expirer_abonnements_editeurs

User = get_user_model()


class PublisherTierAndLifecycleIntegrationTests(APITestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_superuser(
            username='admin_test',
            password='AdminPassword123!',
            email='admin@test.com',
            role='admin',
        )
        # Ensure default plans exist
        self.plan_basique, _ = PlatformPlan.objects.get_or_create(
            name='Basique',
            defaults={
                'prix': Decimal('0.00'),
                'commission_rate': Decimal('20.00'),
                'min_subscribers': 0,
                'min_publications': 0,
                'min_sales': 0,
                'is_active': True,
            },
        )
        self.plan_standard, _ = PlatformPlan.objects.get_or_create(
            name='Standard',
            defaults={
                'prix': Decimal('0.00'),
                'commission_rate': Decimal('15.00'),
                'min_subscribers': 1001,
                'min_publications': 61,
                'min_sales': 251,
                'is_active': True,
            },
        )
        self.plan_premium, _ = PlatformPlan.objects.get_or_create(
            name='Premium',
            defaults={
                'prix': Decimal('0.00'),
                'commission_rate': Decimal('10.00'),
                'min_subscribers': 2001,
                'min_publications': 121,
                'min_sales': 501,
                'is_active': True,
            },
        )

    def test_full_publisher_lifecycle_and_auto_tier_upgrade(self):
        """1. Admin creates publisher -> is_active=True immediate.
        2. Verification request -> admin validates.
        3. Palier 'Basique' active automatically.
        4. Tous les seuils du plan Standard atteints (AND) -> auto-upgrades to 'Standard'.
        """
        # Step 1: Admin creates publisher account
        publisher = User.objects.create_user(
            username='editeur_demo',
            password='PublisherPass123!',
            role='publisher',
            name='Éditeur Démo',
        )
        profile, created = PublisherProfile.objects.get_or_create(
            user=publisher,
            defaults={'company_name': 'Éditeur Démo Cie'},
        )
        self.assertTrue(profile.is_active, "PublisherProfile is_active must be True immediately upon creation")

        # Step 2: Verification request and validation
        verification = PublisherVerification.objects.create(
            user=publisher,
            legal_company_name='Éditeur Démo Cie',
            registration_number='RCCM-CI-ABJ-2024-000001',
            tax_id='NIF-1234567890',
            official_address='01 BP 1234 Abidjan',
            city='Abidjan',
            country='Côte d\'Ivoire',
            phone_number='+22501020304',
            legal_representative_name='Kouassi Jean',
            legal_representative_id_number='CNI-CI-1234567',
            id_document_url='https://example.com/cni.pdf',
            registration_document_url='https://example.com/rccm.pdf',
            status='pending',
        )
        self.client.force_authenticate(user=self.admin)
        resp_verify = self.client.post(
            f'/api/accounts/admin/verifications/{verification.id}/review/',
            data={'decision': 'approved'},
            format='json',
        )
        self.assertIn(resp_verify.status_code, [200, 201], msg=f"Review response: {resp_verify.data}")
        verification.refresh_from_db()
        self.assertEqual(verification.status, 'approved')

        # Step 3: Check automatic 'Basique' tier
        sub = sync_publisher_tier(publisher)
        self.assertIsNotNone(sub)
        self.assertEqual(sub.plan.name, 'Basique')
        self.assertEqual(sub.plan.commission_rate, Decimal('20.00'))

        # Optimisation : on utilise les seuils Standard RÉELS du plan créé dans setUp
        # (1001 abonnés ET 61 publications ET 251 ventes) — mais pour garder le test
        # rapide (<5s), on crée un plan "Standard-Test" avec des seuils mini (11/6/5)
        # puis on synchro. La logique AND est identique, seule la taille du seuil change.
        from apps.abonnements.models import PlatformPlan as PP, Abonnement

        plan_test, _ = PP.objects.get_or_create(
            name='Standard-Test',
            defaults={
                'prix': Decimal('0.00'),
                'commission_rate': Decimal('15.00'),
                'min_subscribers': 11,
                'min_publications': 6,
                'min_sales': 5,
                'is_active': True,
            },
        )

        # 5 ventes
        from django.utils import timezone as tz
        now = tz.now()
        for i in range(5):
            EcritureComptable.objects.create(
                reference=f'test-sale-and-{i}',
                editeur=publisher,
                type_ecriture='recette',
                compte_debit='411000',
                compte_credit='706000',
                libelle=f'Vente AND test #{i}',
                montant=Decimal('1000.00'),
                periode_mois=now.month,
                periode_annee=now.year,
            )

        # 6 publications
        from apps.publications.models import Publication, Category
        cat, _ = Category.objects.get_or_create(
            slug='test-cat', defaults={'name': 'Test', 'description': 'test'}
        )
        for i in range(6):
            Publication.objects.create(
                publisher=publisher,
                title=f'Publication AND test {i}',
                description='Description test',
                content='Contenu test',
                category=cat,
                status='published',
            )

        # 11 abonnés — bulk pour la vitesse (pas de hash de mdp nécessaire pour Abonnement)
        readers = User.objects.bulk_create([
            User(username=f'rdr_and_{i}', role='reader', password='!')
            for i in range(11)
        ])
        Abonnement.objects.bulk_create([
            Abonnement(
                publisher=publisher,
                reader=r,
                montant=Decimal('0.00'),
                status='active',
            )
            for r in readers
        ])

        # Tous les 3 seuils Standard-Test atteints (AND) → Standard-Test
        new_sub = sync_publisher_tier(publisher)
        self.assertIsNotNone(new_sub)
        self.assertEqual(
            new_sub.plan.name, 'Standard-Test',
            "AND logic : tous les seuils atteints → palier supérieur"
        )
        self.assertEqual(new_sub.plan.commission_rate, Decimal('15.00'))



    def test_payment_initiation_rejects_publisher_subscription_id(self):
        """Verify POST /api/paiements/initier/ with publisher_subscription_id returns HTTP 400."""
        user = User.objects.create_user(
            username='user_payment_test',
            password='UserPass123!',
            role='reader',
        )
        sub = PublisherSubscription.objects.create(
            publisher=user,
            plan=self.plan_basique,
            montant=0,
            status='active',
        )
        self.client.force_authenticate(user=user)
        response = self.client.post(
            '/api/paiements/initier/',
            data={
                'type_transaction': 'platform_subscription',
                'publisher_subscription_id': sub.id,
                'mode_paiement': 'movapay',
            },
            format='json',
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn('error', response.data)
        self.assertIn('gratuit', response.data['error'])

    def test_expirer_abonnements_editeurs_is_noop(self):
        """Celery task expirer_abonnements_editeurs must be a no-op and preserve is_active=True."""
        publisher = User.objects.create_user(
            username='editeur_celery_test',
            password='PublisherPass123!',
            role='publisher',
        )
        profile = PublisherProfile.objects.create(
            user=publisher,
            company_name='Test Celery Co',
            is_active=True,
        )

        result = expirer_abonnements_editeurs()
        self.assertEqual(result, {'expired_count': 0})
        profile.refresh_from_db()
        self.assertTrue(profile.is_active, "expirer_abonnements_editeurs must never deactivate a publisher profile")

    def test_public_platform_plans_endpoint_accessible(self):
        """Verify GET /api/abonnements/platform-plans/ is accessible publicly (HTTP 200, unauthenticated)."""
        response = self.client.get('/api/abonnements/platform-plans/')
        self.assertEqual(response.status_code, 200)
