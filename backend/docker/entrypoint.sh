#!/bin/sh
set -e

echo "=== Digital Press Backend (Docker) ==="

echo "Attente de PostgreSQL..."
until python -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
s.connect(('${DATABASE_HOST:-db}', int('${DATABASE_PORT:-5432}')))
s.close()
" 2>/dev/null; do
  echo "  PostgreSQL pas encore prêt..."
  sleep 2
done
echo "PostgreSQL OK"

echo "Migrations..."
python manage.py migrate --noinput

echo "Comptes de démonstration..."
python manage.py create_demo_users || true

echo ""
echo "API:    http://0.0.0.0:8000/api/"
echo "Health: http://0.0.0.0:8000/api/health/"
echo "Admin:  admin / Admin123!"
echo ""

exec "$@"
