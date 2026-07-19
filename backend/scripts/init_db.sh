#!/bin/bash
# ============================================================
# Digital Press — Script d'initialisation complète
# Usage: bash scripts/init_db.sh
# ============================================================
set -e

echo "╔══════════════════════════════════════════════════════╗"
echo "║     Digital Press — Initialisation Backend           ║"
echo "╚══════════════════════════════════════════════════════╝"

# Vérifier Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trouvé. Installez Python 3.10+"
    exit 1
fi

# Créer l'environnement virtuel si absent
if [ ! -d "venv" ]; then
    echo "📦 Création de l'environnement virtuel..."
    python3 -m venv venv
fi

# Activer l'environnement virtuel
source venv/bin/activate

# Installer les dépendances
echo "📥 Installation des dépendances..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Copier .env si absent
if [ ! -f ".env" ]; then
    echo "⚙️  Création du fichier .env depuis .env.example..."
    cp .env.example .env
    echo "⚠️  Pensez à éditer .env avec vos vraies valeurs!"
fi

# Créer le dossier logs
mkdir -p logs

# Appliquer les migrations
echo "🗄️  Application des migrations..."
python manage.py makemigrations accounts publications abonnements paiements comptabilite notifications
python manage.py migrate

# Collecter les fichiers statiques
echo "📁 Collecte des fichiers statiques..."
python manage.py collectstatic --noinput --clear 2>/dev/null || true

# Peupler la base de données
echo "🌱 Population de la base de données..."
python scripts/seed.py

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ Backend Digital Press prêt!                      ║"
echo "║                                                      ║"
echo "║  Lancer le serveur:                                  ║"
echo "║    python manage.py runserver                        ║"
echo "║                                                      ║"
echo "║  Swagger: http://localhost:8000/api/docs/            ║"
echo "╚══════════════════════════════════════════════════════╝"
