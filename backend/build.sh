#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Digital Press — Render Build Script
# Exécuté automatiquement par Render à chaque déploiement
# ─────────────────────────────────────────────────────────────────────────────

set -o errexit  # Arrêter si une commande échoue

echo "🔧 Installation des dépendances Python..."
pip install --upgrade pip
pip install -r requirements.txt

echo "📦 Collecte des fichiers statiques..."
python manage.py collectstatic --noinput
echo "🗃️  Correction de l'historique des migrations..."
python manage.py shell << 'PYEOF'
from django.db import connection
with connection.cursor() as cursor:
    # Vérifier si django_migrations existe (BDD déjà initialisée)
    cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_name = 'django_migrations'
        )
    """)
    if cursor.fetchone()[0]:
        # Supprimer l'ancien alias 0003_add_conversations s'il est présent
        cursor.execute(
            "DELETE FROM django_migrations WHERE app='publications' AND name='0003_add_conversations'"
        )
        deleted = cursor.rowcount
        if deleted:
            print(f"🗑️  Supprimé l'entrée obsolète publications.0003_add_conversations")

        # Insérer 0003_conversations s'il n'est pas déjà enregistré
        cursor.execute(
            "SELECT 1 FROM django_migrations WHERE app='publications' AND name='0003_conversations'"
        )
        if not cursor.fetchone():
            cursor.execute(
                "INSERT INTO django_migrations (app, name, applied) VALUES ('publications', '0003_conversations', NOW())"
            )
            print("✅ Enregistré publications.0003_conversations dans django_migrations")
        else:
            print("ℹ️  publications.0003_conversations déjà enregistré")
    else:
        print("ℹ️  Nouvelle base de données — migrate s'en chargera")
PYEOF

echo "🗃️  Application des migrations..."
python manage.py migrate --fake-initial

echo "👤 Création du compte admin (si inexistant)..."
python manage.py shell << 'PYEOF'
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    u = User.objects.create_superuser(
        username='admin',
        email='admin@digitalpress.com',
        password='Admin123!',
    )
    u.role = 'admin'
    u.name = 'Administrateur'
    u.save()
    print("✅ Compte admin créé : admin / Admin123!")
else:
    print("ℹ  Compte admin déjà existant.")
PYEOF

echo "✅ Build terminé avec succès !"
