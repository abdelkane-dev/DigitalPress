#!/usr/bin/env bash
# Digital Press — Lancer toute la stack Docker
set -e
# Se positionner à la racine du projet (un niveau au-dessus du dossier scripts)
cd "$(dirname "$0")/.."

echo ""
echo "========================================"
echo "  Digital Press — Docker Stack"
echo "========================================"
echo ""

if ! command -v docker &>/dev/null; then
  echo "ERREUR: Docker n'est pas installé."
  exit 1
fi

echo "1/3 Construction et démarrage..."
docker compose up --build -d

echo ""
echo "2/3 Attente du backend..."
for i in $(seq 1 60); do
  if curl -sf http://127.0.0.1:8000/api/health/ >/dev/null 2>&1; then
    echo "Backend OK!"
    break
  fi
  sleep 2
  echo "  En attente... ($i/60)"
done

echo ""
echo "3/3 Test login..."
curl -sf -X POST http://127.0.0.1:8000/api/accounts/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin123!"}' | head -c 80 && echo ""

echo ""
echo "========================================"
echo "  STACK DOCKER PRÊTE"
echo "========================================"
echo "  API:    http://127.0.0.1:8000/api/"
echo "  Flutter: flutter run"
echo "  Arrêter: docker compose down"
echo ""
