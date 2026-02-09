import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.accounts.models import User, PublisherProfile
from apps.publications.models import Publication

def run():
    if not User.objects.filter(username='admin').exists():
        admin = User.objects.create_superuser('admin','admin@example.com','adminpass')
        admin.role = 'admin'
        admin.save()
        print('Created admin')

    if not User.objects.filter(username='publisher1').exists():
        pub = User.objects.create_user('publisher1','pub1@example.com','pubpass')
        pub.role='publisher'
        pub.save()
        PublisherProfile.objects.create(user=pub, company_name='Acme Press')
        print('Created publisher1')

    if not User.objects.filter(username='reader1').exists():
        reader = User.objects.create_user('reader1','reader@example.com','readerpass')
        reader.role='reader'
        reader.save()
        print('Created reader1')

    # sample publications
    pub_user = User.objects.filter(role='publisher').first()
    if pub_user and not Publication.objects.exists():
        Publication.objects.create(title='Welcome to DigitalPress', description='Sample publication', publisher=pub_user)
        print('Created sample publication')

if __name__ == '__main__':
    run()
