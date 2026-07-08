from django.test import TestCase

from apps.accounts.models import User
from apps.publications.models import Category, Publication
from apps.publications.serializers import PublicationCreateSerializer


class PublicationCreateSerializerTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='publisher',
            email='publisher@example.com',
            password='secret123',
            role='publisher',
        )
        self.category = Category.objects.create(name='Tech', slug='tech')

    def test_create_serializer_returns_publication_id_in_response(self):
        request = type('Request', (), {'user': self.user})()
        serializer = PublicationCreateSerializer(
            data={
                'title': 'Mon article',
                'description': 'Description',
                'content': 'Contenu',
                'category': self.category.id,
                'cover_image': 'https://example.com/cover.jpg',
                'file_url': 'https://example.com/file.pdf',
                'prix': '10.50',
                'status': 'draft',
                'pub_type': 'article',
                'is_free': False,
                'tags': 'tag1, tag2',
            },
            context={'request': request},
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)
        publication = serializer.save()

        self.assertIsInstance(publication, Publication)
        self.assertEqual(serializer.data['id'], publication.id)
