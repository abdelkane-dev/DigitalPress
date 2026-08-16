from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate
from rest_framework.request import Request

from apps.paiements.models import Transaction
from .models import Category, Publication, PublicationView
from .serializers import PublicationCreateSerializer, PublicationSerializer
from .views import (
    PublicationListView, PublicationFileAccessView,
    FeaturedPublicationsView, FeaturePublicationView,
    VerifyFeaturePaymentView,
)


class PublicationCreateSerializerTests(TestCase):
    def test_category_filter_accepts_human_readable_category_name(self):
        publisher = get_user_model().objects.create_user(
            username='publisher-filter',
            password='secret123',
            role='publisher',
        )
        category = Category.objects.create(name='Actualités', slug='actualites')
        publication = Publication.objects.create(
            title='Article filtré',
            description='Description',
            content='Contenu',
            publisher=publisher,
            category=category,
            status='published',
        )

        django_request = APIRequestFactory().get('/api/publications/', {'category': 'Actualités'})
        request = Request(django_request)
        view = PublicationListView()
        view.request = request

        qs = view.get_queryset()

        self.assertIn(publication, qs)

    def test_create_serializer_returns_publication_id(self):
        user = get_user_model().objects.create_user(
            username='publisher-test',
            password='secret123',
            role='publisher',
        )
        request = APIRequestFactory().post('/', data={})
        request.user = user

        serializer = PublicationCreateSerializer(
            data={
                'title': 'Titre test',
                'description': 'Description test',
                'content': 'Contenu test',
                'category_name': 'Sports',
                'cover_image': 'https://example.com/cover.jpg',
                'file_url': 'https://example.com/file.pdf',
                'prix': '1500.00',
                'is_free': False,
                'pub_type': 'article',
                'tags': 'tag1, tag2',
            },
            context={'request': request},
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)
        publication = serializer.save()

        response_data = PublicationCreateSerializer(publication).data
        self.assertIn('id', response_data)
        self.assertEqual(response_data['id'], publication.id)

    def test_paid_publication_access_is_granted_after_successful_purchase(self):
        User = get_user_model()
        publisher = User.objects.create_user(
            username='publisher-pay',
            password='secret123',
            role='publisher',
        )
        reader = User.objects.create_user(
            username='reader-pay',
            password='secret123',
            role='reader',
        )
        category = Category.objects.create(name='Culture', slug='culture')
        publication = Publication.objects.create(
            title='Article premium',
            description='Description premium',
            content='Contenu premium',
            publisher=publisher,
            category=category,
            status='published',
            prix=2000,
            is_free=False,
            file_url='https://example.com/premium.pdf',
        )

        Transaction.objects.create(
            payer=reader,
            beneficiaire=publisher,
            publication=publication,
            type_transaction='purchase',
            montant_brut=2000,
            commission=200,
            montant_net=1800,
            status='success',
            phone_payer='',
            reference='test-purchase',
            processed_at=timezone.now(),
        )

        # Vérifier l'accès contrôlé au fichier via l'endpoint sécurisé
        factory = APIRequestFactory()
        request = factory.get(f'/api/publications/{publication.id}/file/')
        force_authenticate(request, user=reader)
        response = PublicationFileAccessView.as_view()(request, pk=publication.id)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['file_url'], publication.file_url)

        # Vérifier que le serializer expose le contenu et file_url pour un utilisateur autorisé.
        serializer_request = Request(factory.get('/'))
        serializer_request.user = reader
        serializer = PublicationSerializer(publication, context={'request': serializer_request})
        self.assertEqual(serializer.data['file_url'], publication.file_url)
        self.assertEqual(serializer.data['content'], publication.content)
        self.assertTrue(serializer.data['is_subscribed'])

    def test_subscription_only_grants_access_to_same_publisher_articles(self):
        User = get_user_model()
        publisher_a = User.objects.create_user(
            username='publisher-a',
            password='secret123',
            role='publisher',
        )
        publisher_b = User.objects.create_user(
            username='publisher-b',
            password='secret123',
            role='publisher',
        )
        reader = User.objects.create_user(
            username='reader-subscriber',
            password='secret123',
            role='reader',
        )
        category = Category.objects.create(name='Économie', slug='economie')
        publication_b = Publication.objects.create(
            title='Article B',
            description='Description',
            content='Contenu B',
            publisher=publisher_b,
            category=category,
            status='published',
            prix=1500,
            is_free=False,
            file_url='https://example.com/file-b.pdf',
        )
        publication_a = Publication.objects.create(
            title='Article A',
            description='Description A',
            content='Contenu A',
            publisher=publisher_a,
            category=category,
            status='published',
            prix=1500,
            is_free=False,
            file_url='https://example.com/file-a.pdf',
        )
        from apps.abonnements.models import Abonnement
        from apps.abonnements.models import Plan

        plan = Plan.objects.create(
            name='Plan éditeur A',
            publisher=publisher_a,
            description='Abonnement pour A',
            prix=1000,
            period='monthly',
        )
        abonnement = Abonnement.objects.create(
            reader=reader,
            publisher=publisher_a,
            plan=plan,
            montant=1000,
            status='active',
            start_date=timezone.now(),
            end_date=timezone.now() + timezone.timedelta(days=30),
        )

        factory = APIRequestFactory()
        request = factory.get(f'/api/publications/{publication_b.id}/file/')
        force_authenticate(request, user=reader)
        response = PublicationFileAccessView.as_view()(request, pk=publication_b.id)

        self.assertEqual(response.status_code, 403)


class FeaturedPublicationsTests(TestCase):
    """Tests du système « À la une » : vitrine tendances + mise en avant
    payante par l'éditeur (façon publicité Facebook)."""

    def setUp(self):
        User = get_user_model()
        self.publisher = User.objects.create_user(
            username='publisher-featured',
            password='secret123',
            role='publisher',
        )
        self.other_publisher = User.objects.create_user(
            username='publisher-featured-2',
            password='secret123',
            role='publisher',
        )
        category = Category.objects.create(name='Tech', slug='tech')
        self.pub_a = Publication.objects.create(
            title='Article tendance',
            description='Description',
            content='Contenu',
            publisher=self.publisher,
            category=category,
            status='published',
        )
        self.pub_b = Publication.objects.create(
            title='Article brouillon',
            description='Description',
            content='Contenu',
            publisher=self.publisher,
            category=category,
            status='draft',
        )

    def test_trending_uses_recent_views_only(self):
        # 4 vues récentes sur pub_a → tendance. 4 vues anciennes sur pub_b
        # → ne doit PAS apparaître (statut brouillon + vues anciennes).
        for i in range(4):
            PublicationView.objects.create(
                publication=self.pub_a, viewer_key=f'ip_1{i}'
            )
        old = timezone.now() - timezone.timedelta(days=10)
        for i in range(4):
            PublicationView.objects.create(
                publication=self.pub_b, viewer_key=f'ip_2{i}'
            )
        PublicationView.objects.filter(
            publication=self.pub_b
        ).update(viewed_at=old)

        request = APIRequestFactory().get('/api/publications/featured/')
        response = FeaturedPublicationsView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        trending_ids = [p['id'] for p in response.data['trending']]
        self.assertIn(self.pub_a.id, trending_ids)
        self.assertNotIn(self.pub_b.id, trending_ids)

    def test_featured_wallet_payment_activates_promotion(self):
        from apps.accounts.models import PublisherProfile
        profile, _ = PublisherProfile.objects.get_or_create(
            user=self.publisher,
            defaults={'company_name': 'Featured Press'},
        )
        profile.solde = 10000
        profile.save(update_fields=['solde'])

        request = APIRequestFactory().post(
            f'/api/publications/{self.pub_a.id}/feature/',
            data={'days': 7, 'mode_paiement': 'wallet'},
            format='json',
        )
        force_authenticate(request, user=self.publisher)
        response = FeaturePublicationView.as_view()(request, pk=self.pub_a.id)

        self.assertEqual(response.status_code, 201, response.data)
        profile.refresh_from_db()
        self.assertEqual(profile.solde, 5000)  # 10 000 - 5 000 FCFA
        self.pub_a.refresh_from_db()
        self.assertTrue(self.pub_a.is_featured)
        promotion = self.pub_a.featured_promotions.get()
        self.assertEqual(promotion.status, 'active')
        self.assertIsNotNone(promotion.ends_at)

    def test_featured_simulation_then_verify(self):
        request = APIRequestFactory().post(
            f'/api/publications/{self.pub_a.id}/feature/',
            data={'days': 14, 'mode_paiement': 'simulation'},
            format='json',
        )
        force_authenticate(request, user=self.publisher)
        response = FeaturePublicationView.as_view()(request, pk=self.pub_a.id)
        self.assertEqual(response.status_code, 201, response.data)
        reference = response.data['transaction']
        self.assertTrue(reference)
        self.pub_a.refresh_from_db()
        self.assertFalse(self.pub_a.is_featured)  # pas encore payé

        verify = APIRequestFactory().post(
            f'/api/publications/{self.pub_a.id}/feature/verify/',
            data={'reference': reference},
            format='json',
        )
        force_authenticate(verify, user=self.publisher)
        verify_response = VerifyFeaturePaymentView.as_view()(
            verify, pk=self.pub_a.id
        )
        self.assertEqual(verify_response.status_code, 200)
        self.assertTrue(verify_response.data['featured'])
        self.pub_a.refresh_from_db()
        self.assertTrue(self.pub_a.is_featured)

    def test_cannot_feature_another_publishers_publication(self):
        request = APIRequestFactory().post(
            f'/api/publications/{self.pub_a.id}/feature/',
            data={'days': 7, 'mode_paiement': 'wallet'},
            format='json',
        )
        force_authenticate(request, user=self.other_publisher)
        response = FeaturePublicationView.as_view()(request, pk=self.pub_a.id)
        self.assertEqual(response.status_code, 404)
