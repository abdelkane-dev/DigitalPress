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

echo "🗃️  Application des migrations..."
# Si un déploiement précédent a planté après avoir créé certaines tables,
# les migrations correspondantes ne sont pas dans django_migrations mais les tables existent.
# On fake toute l'app publications pour éviter le DuplicateTable, puis on migre normalement.
python manage.py migrate publications --fake 2>/dev/null || true
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
