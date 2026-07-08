#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Digital Press — Backend Startup Script
# Run this script to start the Django development server
# ─────────────────────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Digital Press — Backend Django Server    ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

# ── 1. Check Python ──────────────────────────────────────────────────────────
PYTHON_BIN="python3"
if ! command -v python3 &>/dev/null; then
  if command -v python &>/dev/null; then
    PYTHON_BIN="python"
  else
    echo -e "${RED}❌ Python non trouvé. Installez Python 3.9+${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✓${NC} Python trouvé : $($PYTHON_BIN --version)"

# ── 2. Virtual environment ───────────────────────────────────────────────────
if [ ! -d "venv" ]; then
  echo -e "${YELLOW}⚙  Création de l'environnement virtuel...${NC}"
  $PYTHON_BIN -m venv venv
fi

if [ -f "venv/Scripts/activate" ]; then
  source venv/Scripts/activate
elif [ -f "venv/bin/activate" ]; then
  source venv/bin/activate
else
  echo -e "${RED}❌ Impossible d'activer l'environnement virtuel.${NC}"
  exit 1
fi
echo -e "${GREEN}✓${NC} Environnement virtuel activé"

# ── 3. Install dependencies ──────────────────────────────────────────────────
echo -e "${YELLOW}⚙  Installation des dépendances...${NC}"
pip install -r requirements.txt -q
echo -e "${GREEN}✓${NC} Dépendances installées"

# ── 4. Copy .env if missing ──────────────────────────────────────────────────
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
  cp .env.example .env
  echo -e "${YELLOW}⚠  Fichier .env créé depuis .env.example — vérifiez les valeurs !${NC}"
fi

# ── 5. Database migrations ───────────────────────────────────────────────────
echo -e "${YELLOW}⚙  Application des migrations...${NC}"
python manage.py migrate --run-syncdb 2>&1 | tail -5
echo -e "${GREEN}✓${NC} Base de données à jour"

echo -e "${YELLOW}⚙  Comptes de démonstration...${NC}"
python manage.py create_demo_users 2>&1 | tail -5
echo -e "${GREEN}✓${NC} Comptes demo prêts"

# ── 6. Create superuser if none exists ──────────────────────────────────────
USER_COUNT=$(python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
print(User.objects.filter(is_superuser=True).count())
" 2>/dev/null || echo "0")

if [ "$USER_COUNT" = "0" ]; then
  echo ""
  echo -e "${YELLOW}════════════════════════════════════════════${NC}"
  echo -e "${YELLOW}  Aucun compte admin trouvé.                ${NC}"
  echo -e "${YELLOW}  Création du compte administrateur...      ${NC}"
  echo -e "${YELLOW}════════════════════════════════════════════${NC}"
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
fi

# ── 7. Detect local IP ───────────────────────────────────────────────────────
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
  LOCAL_IP=$(ipconfig 2>/dev/null | grep -i "IPv4" | head -n 1 | awk -F: '{print $2}' | tr -d '[[:space:]\r]')
fi
if [ -z "$LOCAL_IP" ]; then
  LOCAL_IP="127.0.0.1"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Serveur Django démarré !                 ${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}Admin Django :${NC}  http://$LOCAL_IP:8000/admin/"
echo -e "  ${BLUE}API :${NC}           http://$LOCAL_IP:8000/api/"
echo -e "  ${BLUE}Logins demo :${NC}   admin / Admin123!"
echo ""
echo -e "${YELLOW}⚠  Dans Flutter app_config.dart, mettez :${NC}"
echo -e "   ${BLUE}baseUrlWeb = 'http://$LOCAL_IP:8000/api/';${NC}"
echo ""
echo -e "  Arrêter : Ctrl+C"
echo ""

# ── 8. Start server ──────────────────────────────────────────────────────────
python manage.py runserver 0.0.0.0:8000
