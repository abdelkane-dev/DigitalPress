#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# DigitalPress — Installation Directe VPS (sans Docker)
# IP VPS : 192.162.71.56 | Ubuntu 24.04 LTS
# ─────────────────────────────────────────────────────────────────────────────
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}   DigitalPress — Déploiement Direct VPS (Systemd)  ${NC}"
echo -e "${BLUE}====================================================${NC}"

# 1. Paquets système (Python 3.12, PostgreSQL, Redis, Nginx)
echo -e "${YELLOW}⚙  1. Installation des paquets système...${NC}"
apt update && apt upgrade -y
apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib redis-server nginx ufw git

# 2. Configuration Pare-feu
echo -e "${YELLOW}⚙  2. Configuration du pare-feu UFW...${NC}"
ufw allow OpenSSH || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable || true

# 3. Base de données PostgreSQL locale
echo -e "${YELLOW}⚙  3. Configuration de la base de données PostgreSQL...${NC}"
# ─── Mot de passe base de données ─────────────────────────────────────────
# Généré aléatoirement à chaque exécution — JAMAIS en clair dans le script.
# Il n'existe que dans le .env de production sur le VPS. Surcharge possible
# via la variable d'environnement DP_DB_PASSWORD (ex: rotation manuelle).
DB_PASSWORD="${DP_DB_PASSWORD:-$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")}"
sudo -u postgres psql -c "CREATE DATABASE digitalpress;" || true
sudo -u postgres psql -c "CREATE USER dp_user WITH PASSWORD '${DB_PASSWORD}';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE digitalpress TO dp_user;" || true
sudo -u postgres psql -c "ALTER DATABASE digitalpress OWNER TO dp_user;" || true

# 4. Environnement virtuel Python & Dépendances
echo -e "${YELLOW}⚙  4. Installation du Backend Django...${NC}"
mkdir -p /opt/digitalpress/logs /opt/digitalpress/media /opt/digitalpress/staticfiles
cd /opt/digitalpress/backend

if [ ! -d "venv" ]; then
  python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt

# 5. Fichier .env de production
echo -e "${YELLOW}⚙  5. Configuration des variables d'environnement (.env)...${NC}"
if [ ! -f ".env" ]; then
  SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(64))")
  cat > .env << EOF
DEBUG=False
SECRET_KEY=$SECRET
ALLOWED_HOSTS=192.162.71.56,vps123184.serveur-vps.net,digitalpress-ml.com,www.digitalpress-ml.com,digitalpress.ml,www.digitalpress.ml
DATABASE_NAME=digitalpress
DATABASE_USER=dp_user
DATABASE_PASSWORD=${DB_PASSWORD}
DATABASE_HOST=localhost
DATABASE_PORT=5432
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1
# ─── SÉCURITÉ (audit 2026-08-16) ─────────────────────────────────────────
# CORS_ALLOW_ALL=True laissait N'importe quel site web appeler l'API depuis
# le navigateur de nos utilisateurs (façon CSRF par cross-origin). En
# production, seuls nos propres domaines sont autorisés — les apps natives
# (Android/iOS) ne passent pas par CORS. Attention : le serveur derrière le
# domaine nu (digitalpress-ml.com) est intercepté par le proxy anti-DDoS de
# l'hébergeur ; on liste quand même les deux pour couvrir la redirection
# nu → www une fois la zone DNS corrigée.
CORS_ALLOW_ALL=False
CORS_ALLOWED_ORIGINS=https://www.digitalpress-ml.com,https://digitalpress-ml.com,https://www.digitalpress.ml,https://digitalpress.ml
JWT_ACCESS_MINUTES=60
JWT_REFRESH_DAYS=7
# ─── IMPORTANT : TOUJOURS avec le préfixe www ────────────────────────────────
# Le domaine nu (digitalpress-ml.com) passe par le proxy anti-DDoS de
# l'hébergeur (en-têtes X-Anubis) qui renvoie 404 : seul
# www.digitalpress-ml.com atteint directement le VPS. Toutes les URLs
# publiques (webhook Movapay, retour de paiement, médias) utilisent donc
# systématiquement https://www.digitalpress-ml.com.
BACKEND_URL=https://www.digitalpress-ml.com
FRONTEND_SUCCESS_URL=https://www.digitalpress-ml.com/payment/success
CSRF_TRUSTED_ORIGINS=http://192.162.71.56,http://www.digitalpress-ml.com,https://www.digitalpress-ml.com
SECURE_SSL_REDIRECT=False
EOF
fi

# 6. Migrations & Statiques
echo -e "${YELLOW}⚙  6. Application des migrations & collecte des statiques...${NC}"
python manage.py migrate --noinput
python manage.py collectstatic --noinput

# 7. Service Systemd Daphne (ASGI HTTP + WebSockets)
echo -e "${YELLOW}⚙  7. Création du service Systemd backend...${NC}"
cat > /etc/systemd/system/digitalpress.service << 'EOF'
[Unit]
Description=DigitalPress Daphne ASGI Backend Service
After=network.target postgresql.service redis-server.service

[Service]
User=root
WorkingDirectory=/opt/digitalpress/backend
ExecStart=/opt/digitalpress/backend/venv/bin/daphne -b 127.0.0.1 -p 8000 config.asgi:application
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable digitalpress
systemctl restart digitalpress

# 8. Configuration Nginx
echo -e "${YELLOW}⚙  8. Configuration Nginx...${NC}"
cat > /etc/nginx/sites-available/digitalpress << 'EOF'
# ─── Domaine nu → www ──────────────────────────────────────────────────────
# digitalpress-ml.com (sans www) est actuellement intercepté par le proxy
# anti-DDoS de l'hébergeur (404 X-Anubis). Ce bloc redirige proprement vers
# www quand la requête atteint le VPS (après correction de la zone DNS / du
# proxy chez l'hébergeur). Le reste du trafic passe par le bloc principal.
server {
    listen 80;
    server_name digitalpress-ml.com digitalpress.ml;
    return 301 https://www.digitalpress-ml.com$request_uri;
}

server {
    listen 80;
    server_name 192.162.71.56 vps123184.serveur-vps.net www.digitalpress.ml www.digitalpress-ml.com;
    client_max_body_size 50M;

    location /media/ {
        alias /opt/digitalpress/backend/media/;
    }

    location /static/ {
        alias /opt/digitalpress/backend/staticfiles/;
    }

    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/digitalpress /etc/nginx/sites-enabled/digitalpress
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}   🎉 DÉPLOIEMENT DIRECT REUSSI SUR VPS !          ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "  Domaine API : ${BLUE}https://www.digitalpress-ml.com/api/${NC}"
echo -e "  Health Check: ${BLUE}https://www.digitalpress-ml.com/api/health/${NC}"
echo -e "  Admin Django: ${BLUE}https://www.digitalpress-ml.com/admin/${NC}"
echo -e "  WebSocket   : ${BLUE}wss://www.digitalpress-ml.com/ws/notifications/${NC}"
echo -e "  ⚠️  Domaine nu digitalpress-ml.com : corrigez le proxy/la zone DNS chez"
echo -e "      l'hébergeur pour qu'il atteigne le VPS (le bloc nginx ci-dessus"
echo -e "      redirige déjà nu → www une fois la requête arrivée)."
echo ""
echo -e "${YELLOW}🔒 Pour activer HTTPS / SSL gratuit avec Let's Encrypt :${NC}"
echo -e "   sudo apt-get install -y certbot python3-certbot-nginx"
echo -e "   sudo certbot --nginx -d digitalpress-ml.com -d www.digitalpress-ml.com"
echo ""
