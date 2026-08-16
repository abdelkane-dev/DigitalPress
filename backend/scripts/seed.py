#!/usr/bin/env python
"""
Script de population de la base de données — Digital Press
Crée les comptes test, plans, catégories, publications et données comptables.

Usage:
    cd digital_press_backend
    python manage.py shell < scripts/seed.py
    # ou directement :
    python scripts/seed.py
"""
import os
import sys
import django
from pathlib import Path

# Setup Django
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.utils import timezone
from decimal import Decimal
from datetime import timedelta

from apps.accounts.models import User, PublisherProfile
from apps.publications.models import Publication, Category
from apps.abonnements.models import Plan, Abonnement
from apps.paiements.models import Transaction, DemandeRetrait
from apps.comptabilite.models import EcritureComptable
from apps.notifications.models import Notification


def create_users():
    print("\n📦 Création des utilisateurs...")

    # Admin
    admin, _ = User.objects.get_or_create(
        username='admin',
        defaults={
            'email': 'admin@digitalpress.app',
            'name': 'Administrateur',
            'role': 'admin',
            'is_staff': True,
            'is_superuser': True,
            'is_verified': True,
        }
    )
    admin.set_password('Admin@2024!')
    admin.save()
    print(f"  ✅ Admin: admin / Admin@2024!")

    # Éditeur 1
    editeur1, _ = User.objects.get_or_create(
        username='editeur_afrique',
        defaults={
            'email': 'editeur@afriquepress.ci',
            'name': 'Kofi Asante',
            'role': 'publisher',
            'is_verified': True,
        }
    )
    editeur1.set_password('Editeur@2024!')
    editeur1.save()
    profile1, _ = PublisherProfile.objects.get_or_create(
        user=editeur1,
        defaults={
            'company_name': 'Afrique Press International',
            'siret': 'CI-2021-00123',
            'bio': 'Leader de la presse numérique en Afrique de l\'Ouest.',
            'solde': Decimal('145000.00'),
            'total_earned': Decimal('450000.00'),
        }
    )
    print(f"  ✅ Éditeur 1: editeur_afrique / Editeur@2024! (solde: 145 000 FCFA)")

    # Éditeur 2
    editeur2, _ = User.objects.get_or_create(
        username='editeur_tech',
        defaults={
            'email': 'contact@techmagazine.ci',
            'name': 'Amara Diallo',
            'role': 'publisher',
            'is_verified': True,
        }
    )
    editeur2.set_password('Editeur@2024!')
    editeur2.save()
    profile2, _ = PublisherProfile.objects.get_or_create(
        user=editeur2,
        defaults={
            'company_name': 'Tech Magazine CI',
            'bio': 'Votre référence tech en Côte d\'Ivoire.',
            'solde': Decimal('87500.00'),
            'total_earned': Decimal('210000.00'),
        }
    )
    print(f"  ✅ Éditeur 2: editeur_tech / Editeur@2024! (solde: 87 500 FCFA)")

    # Client 1
    client1, _ = User.objects.get_or_create(
        username='client_yao',
        defaults={
            'email': 'yao.kouassi@gmail.com',
            'name': 'Yao Kouassi',
            'role': 'reader',
            'is_verified': True,
        }
    )
    client1.set_password('Client@2024!')
    client1.save()
    print(f"  ✅ Client 1: client_yao / Client@2024!")

    # Client 2
    client2, _ = User.objects.get_or_create(
        username='client_fatou',
        defaults={
            'email': 'fatou.diop@yahoo.fr',
            'name': 'Fatou Diop',
            'role': 'reader',
            'is_verified': True,
        }
    )
    client2.set_password('Client@2024!')
    client2.save()
    print(f"  ✅ Client 2: client_fatou / Client@2024!")

    return admin, editeur1, editeur2, client1, client2


def create_categories():
    print("\n📂 Création des catégories...")
    cats = [
        ('Actualités', 'actualites', '📰'),
        ('Technologie', 'technologie', '💻'),
        ('Économie', 'economie', '📈'),
        ('Culture', 'culture', '🎭'),
        ('Sport', 'sport', '⚽'),
        ('Santé', 'sante', '🏥'),
        ('Politique', 'politique', '🏛️'),
        ('Science', 'science', '🔬'),
    ]
    created = []
    for name, slug, icon in cats:
        cat, _ = Category.objects.get_or_create(
            slug=slug,
            defaults={'name': name, 'icon': icon}
        )
        created.append(cat)
    print(f"  ✅ {len(created)} catégories créées.")
    return created


def create_plans():
    print("\n💳 Création des plans d'abonnement...")
    plans_data = [
        {
            'name': 'Starter',
            'prix': Decimal('2500.00'),
            'period': 'monthly',
            'max_publications': 5,
            'features': 'Accès à 5 publications\nNotifications push\nSupport email',
        },
        {
            'name': 'Premium',
            'prix': Decimal('7500.00'),
            'period': 'monthly',
            'max_publications': 0,
            'features': 'Accès illimité\nTéléchargements hors-ligne\nNotifications push\nSupport prioritaire',
        },
        {
            'name': 'Annuel Premium',
            'prix': Decimal('75000.00'),
            'period': 'yearly',
            'max_publications': 0,
            'features': 'Tout Premium\n2 mois offerts\nAccès archives complètes\nNouveautés en avant-première',
        },
        {
            'name': 'Trimestriel',
            'prix': Decimal('20000.00'),
            'period': 'quarterly',
            'max_publications': 0,
            'features': 'Accès illimité 3 mois\nTéléchargements\nNotifications',
        },
    ]
    plans = []
    for data in plans_data:
        plan, _ = Plan.objects.get_or_create(name=data['name'], defaults=data)
        plans.append(plan)
    print(f"  ✅ {len(plans)} plans créés.")
    return plans


def create_publications(editeur1, editeur2, categories):
    print("\n📄 Création des publications...")
    pubs_data = [
        {
            'publisher': editeur1,
            'title': 'Bilan économique de l\'Afrique de l\'Ouest 2024',
            'description': 'Analyse complète de la croissance économique des 16 pays de la CEDEAO.',
            'category': categories[2],  # Économie
            'prix': Decimal('3500.00'),
            'pub_type': 'report',
            'tags': 'économie,CEDEAO,Afrique,croissance',
        },
        {
            'publisher': editeur1,
            'title': 'Revue Politique Africaine — Novembre 2024',
            'description': 'Les grands enjeux politiques du continent africain ce mois.',
            'category': categories[6],  # Politique
            'prix': Decimal('1500.00'),
            'pub_type': 'magazine',
            'tags': 'politique,Afrique,gouvernance',
        },
        {
            'publisher': editeur1,
            'title': 'Football ivoirien : bilan de la saison',
            'description': 'Retour sur la saison de football en Côte d\'Ivoire.',
            'category': categories[4],  # Sport
            'prix': Decimal('0.00'),
            'pub_type': 'article',
            'is_free': True,
            'tags': 'football,CIV,sport',
        },
        {
            'publisher': editeur2,
            'title': 'Intelligence Artificielle : Guide Pratique 2024',
            'description': 'Tout ce que vous devez savoir sur l\'IA en 2024.',
            'category': categories[1],  # Technologie
            'prix': Decimal('5000.00'),
            'pub_type': 'ebook',
            'tags': 'IA,technologie,machine learning',
        },
        {
            'publisher': editeur2,
            'title': 'Fintech Afrique : les startups qui changent tout',
            'description': 'Portrait de 20 startups fintech africaines révolutionnaires.',
            'category': categories[1],  # Technologie
            'prix': Decimal('2500.00'),
            'pub_type': 'magazine',
            'tags': 'fintech,startup,Afrique,mobile money',
        },
        {
            'publisher': editeur2,
            'title': 'Cybersécurité pour les entreprises africaines',
            'description': 'Guide de protection numérique adapté au contexte africain.',
            'category': categories[1],  # Technologie
            'prix': Decimal('4000.00'),
            'pub_type': 'report',
            'tags': 'cybersécurité,sécurité,entreprise',
        },
    ]
    pubs = []
    for data in pubs_data:
        pub, _ = Publication.objects.get_or_create(
            title=data['title'],
            defaults={
                **data,
                'views_count': 50,
                'downloads_count': 10,
                'status': 'published',
            }
        )
        pubs.append(pub)
    print(f"  ✅ {len(pubs)} publications créées.")
    return pubs


def create_transactions(editeur1, editeur2, client1, client2, publications):
    print("\n💰 Création des transactions de démonstration...")
    now = timezone.now()
    txs = []
    tx_data = [
        # Transactions client1
        {
            'payer': client1, 'beneficiaire': editeur1,
            'publication': publications[0],
            'type_transaction': 'purchase',
            'montant_brut': Decimal('3500'), 'commission': Decimal('350'),
            'montant_net': Decimal('3150'), 'status': 'success',
            'processed_at': now - timedelta(days=5),
        },
        {
            'payer': client1, 'beneficiaire': editeur2,
            'publication': publications[3],
            'type_transaction': 'purchase',
            'montant_brut': Decimal('5000'), 'commission': Decimal('500'),
            'montant_net': Decimal('4500'), 'status': 'success',
            'processed_at': now - timedelta(days=10),
        },
        {
            'payer': client1, 'beneficiaire': editeur2,
            'publication': publications[4],
            'type_transaction': 'subscription',
            'montant_brut': Decimal('7500'), 'commission': Decimal('750'),
            'montant_net': Decimal('6750'), 'status': 'success',
            'processed_at': now - timedelta(days=2),
        },
        # Transactions client2
        {
            'payer': client2, 'beneficiaire': editeur1,
            'publication': publications[1],
            'type_transaction': 'purchase',
            'montant_brut': Decimal('1500'), 'commission': Decimal('150'),
            'montant_net': Decimal('1350'), 'status': 'success',
            'processed_at': now - timedelta(days=15),
        },
        {
            'payer': client2, 'beneficiaire': editeur2,
            'publication': publications[5],
            'type_transaction': 'purchase',
            'montant_brut': Decimal('4000'), 'commission': Decimal('400'),
            'montant_net': Decimal('3600'), 'status': 'success',
            'processed_at': now - timedelta(days=3),
        },
        # Transaction en attente
        {
            'payer': client1, 'beneficiaire': editeur1,
            'publication': publications[0],
            'type_transaction': 'purchase',
            'montant_brut': Decimal('3500'), 'commission': Decimal('350'),
            'montant_net': Decimal('3150'), 'status': 'pending',
        },
    ]
    for data in tx_data:
        import uuid
        tx = Transaction.objects.create(
            reference=str(uuid.uuid4()),
            **data,
        )
        txs.append(tx)

        # Créer écriture comptable pour les transactions success
        if tx.status == 'success':
            from apps.comptabilite.utils import enregistrer_ecriture
            enregistrer_ecriture(tx)

    print(f"  ✅ {len(txs)} transactions créées.")
    return txs


def create_abonnements(client1, client2, editeur1, editeur2, publications, plans):
    print("\n📋 Création des abonnements...")
    now = timezone.now()
    abs_data = [
        {
            'reader': client1, 'publication': publications[3],
            'publisher': editeur2, 'plan': plans[1],
            'montant': Decimal('7500'),
            'status': 'active',
            'start_date': now - timedelta(days=20),
            'end_date': now + timedelta(days=10),
        },
        {
            'reader': client2, 'publication': publications[0],
            'publisher': editeur1, 'plan': plans[0],
            'montant': Decimal('2500'),
            'status': 'active',
            'start_date': now - timedelta(days=5),
            'end_date': now + timedelta(days=25),
        },
        {
            'reader': client1, 'publication': None,
            'publisher': None, 'plan': plans[2],
            'montant': Decimal('75000'),
            'status': 'active',
            'start_date': now - timedelta(days=60),
            'end_date': now + timedelta(days=305),
        },
    ]
    abs_list = []
    for data in abs_data:
        ab = Abonnement.objects.create(**data)
        abs_list.append(ab)
    print(f"  ✅ {len(abs_list)} abonnements créés.")
    return abs_list


def create_demandes_retrait(editeur1, editeur2):
    print("\n💸 Création des demandes de retrait...")
    now = timezone.now()
    demandes_data = [
        {
            'editeur': editeur1,
            'montant': Decimal('50000'),
            'mode_paiement': 'mobile_money',
            'numero_compte': '+225 07 00 00 00 01',
            'status': 'pending',
        },
        {
            'editeur': editeur2,
            'montant': Decimal('30000'),
            'mode_paiement': 'mobile_money',
            'numero_compte': '+225 05 00 00 00 02',
            'status': 'approved',
        },
        {
            'editeur': editeur1,
            'montant': Decimal('20000'),
            'mode_paiement': 'bank_transfer',
            'numero_compte': 'CI93-CI0080111301134016345673',
            'status': 'completed',
        },
    ]
    created = []
    for data in demandes_data:
        dr = DemandeRetrait.objects.create(**data)
        created.append(dr)
    print(f"  ✅ {len(created)} demandes de retrait créées.")
    return created


def create_notifications(admin, editeur1, editeur2, client1, client2):
    print("\n🔔 Création des notifications...")
    notifs = [
        {
            'user': client1,
            'type_notif': 'payment_success',
            'title': 'Paiement confirmé',
            'message': 'Votre achat de "Bilan économique de l\'Afrique 2024" a été confirmé.',
        },
        {
            'user': editeur1,
            'type_notif': 'payment_success',
            'title': 'Nouveau paiement reçu',
            'message': 'Vous avez reçu 3 150 FCFA pour votre publication.',
        },
        {
            'user': editeur2,
            'type_notif': 'withdrawal_approved',
            'title': 'Retrait approuvé',
            'message': 'Votre demande de retrait de 30 000 FCFA a été approuvée.',
        },
        {
            'user': admin,
            'type_notif': 'system',
            'title': 'Système initialisé',
            'message': 'La base de données Digital Press a été initialisée avec succès.',
        },
        {
            'user': client2,
            'type_notif': 'subscription_activated',
            'title': 'Abonnement activé',
            'message': 'Votre abonnement Starter est maintenant actif.',
        },
    ]
    for data in notifs:
        Notification.objects.get_or_create(
            user=data['user'],
            title=data['title'],
            defaults={'type_notif': data['type_notif'], 'message': data['message']},
        )
    print(f"  ✅ {len(notifs)} notifications créées.")


def run():
    print("=" * 60)
    print("  Digital Press — Initialisation de la base de données")
    print("=" * 60)

    admin, editeur1, editeur2, client1, client2 = create_users()
    categories = create_categories()
    plans = create_plans()
    publications = create_publications(editeur1, editeur2, categories)
    transactions = create_transactions(editeur1, editeur2, client1, client2, publications)
    create_abonnements(client1, client2, editeur1, editeur2, publications, plans)
    create_demandes_retrait(editeur1, editeur2)
    create_notifications(admin, editeur1, editeur2, client1, client2)

    print("\n" + "=" * 60)
    print("  ✅ Base de données initialisée avec succès!")
    print("=" * 60)
    print("\n  📌 Comptes de test:")
    print("  ┌──────────────────┬──────────────────┬───────────┐")
    print("  │ Identifiant      │ Mot de passe     │ Rôle      │")
    print("  ├──────────────────┼──────────────────┼───────────┤")
    print("  │ admin            │ Admin@2024!      │ Admin     │")
    print("  │ editeur_afrique  │ Editeur@2024!    │ Éditeur   │")
    print("  │ editeur_tech     │ Editeur@2024!    │ Éditeur   │")
    print("  │ client_yao       │ Client@2024!     │ Client    │")
    print("  │ client_fatou     │ Client@2024!     │ Client    │")
    print("  └──────────────────┴──────────────────┴───────────┘")
    print("\n  🌐 Swagger UI:  http://localhost:8000/api/docs/")
    print("  📚 ReDoc:       http://localhost:8000/api/redoc/")
    print("  🔧 Admin Django: http://localhost:8000/admin/\n")


if __name__ == '__main__':
    run()
