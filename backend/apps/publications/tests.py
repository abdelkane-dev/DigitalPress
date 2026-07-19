from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory, force_authenticate
from rest_framework.request import Request

from apps.paiements.models import Transaction
from .models import Category, Publication
from .serializers import PublicationCreateSerializer, PublicationSerializer
from .views import PublicationListView, PublicationFileAccessView


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
