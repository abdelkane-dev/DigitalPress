import os
import django
import random
import string
import datetime

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.accounts.models import User, PublisherProfile
from apps.publications.models import Category, Publication, Review
from django.utils.text import slugify

def generate_random_string(length=10):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(length))

def generate_sentence():
    words = [generate_random_string(random.randint(3, 8)) for _ in range(random.randint(5, 10))]
    return " ".join(words).capitalize() + "."

def seed():
    print("Deleting old data...")
    Review.objects.all().delete()
    Publication.objects.all().delete()
    Category.objects.all().delete()
    User.objects.exclude(is_superuser=True).delete()

    print("Checking for admin...")
    if not User.objects.filter(username='admin').exists():
        print("Creating admin...")
        User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    else:
        print("Admin already exists.")
    
    print("Creating publishers...")
    publishers = []
    for i in range(3):
        pub = User.objects.create_user(
            username=f'editeur{i+1}', 
            email=f'editeur{i+1}@example.com', 
            password='password123',
        )
        pub.role = 'publisher'
        pub.name = f'Entreprise {i+1}'
        pub.is_verified = True
        pub.save()

        PublisherProfile.objects.create(
            user=pub,
            company_name=pub.name,
            bio=generate_sentence()
        )
        publishers.append(pub)

    print("Creating readers...")
    readers = []
    for i in range(5):
        reader = User.objects.create_user(
            username=f'lecteur{i+1}', 
            email=f'lecteur{i+1}@example.com', 
            password='password123'
        )
        reader.role = 'reader'
        reader.name = f'Utilisateur Lecteur {i+1}'
        reader.save()
        readers.append(reader)

    print("Creating categories...")
    cat_names = ['Actualité', 'Sports', 'Technologie', 'Économie', 'Culture', 'Politique']
    categories = []
    for name in cat_names:
        cat, created = Category.objects.get_or_create(
            name=name,
            defaults={'description': generate_sentence()}
        )
        categories.append(cat)

    print("Creating publications...")
    pub_types = ['article', 'magazine', 'journal', 'report', 'ebook']
    covers = [
        "https://images.unsplash.com/photo-1504711434969-e33886168f5c?auto=format&fit=crop&w=400&q=80",
        "https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=400&q=80",
        "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?auto=format&fit=crop&w=400&q=80",
        "https://images.unsplash.com/photo-1504465039710-0f49c0a47eb7?auto=format&fit=crop&w=400&q=80"
    ]
    for publisher in publishers:
        for _ in range(10):
            Publication.objects.create(
                title=f"{random.choice(['Le journal de', 'La revue sur', 'Livre: '])} {generate_random_string()}",
                description=generate_sentence() + " " + generate_sentence(),
                content=generate_sentence() * 10,
                publisher=publisher,
                category=random.choice(categories),
                cover_image=random.choice(covers),
                file_url="https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                prix=random.choice([0, 0, 500, 1000, 2000]),
                status='published',
                pub_type=random.choice(pub_types),
                is_free=random.choice([True, False]),
                views_count=random.randint(0, 1000),
                downloads_count=random.randint(0, 500),
                tags=f"{generate_random_string(5)},{generate_random_string(4)}"
            )

    print("Creating reviews...")
    publications = Publication.objects.all()
    for pub in publications:
        if random.random() > 0.3:  # 70% chance to have a review
            try:
                Review.objects.create(
                    publication=pub,
                    reader=random.choice(readers),
                    rating=random.randint(3, 5),
                    comment=generate_sentence()
                )
            except Exception as e:
                pass  # Ignore uniqueness constraint errors randomly

    print("Database seeded successfully! (3 Publishers, 5 Readers, Categories, and 30 Publications)")

if __name__ == '__main__':
    seed()
