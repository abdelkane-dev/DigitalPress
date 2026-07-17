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

echo "🗑️ Réinitialisation de la base de données..."
python manage.py shell << 'PYEOF'
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;")
    print("✅ Base de données réinitialisée !")
PYEOF

echo "🗃️  Application des migrations..."
python manage.py migrate

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
