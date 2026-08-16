#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────────
#  Relance DigitalPress sur le téléphone Android (Git Bash / macOS / Linux).
#
#  Après une installation ou un force-stop, Android place l'app en état
#  « stopped » : le tap sur l'icône ne lance rien tant que l'app n'a pas été
#  démarrée une fois. Ce script force ce premier démarrage via adb.
# ────────────────────────────────────────────────────────────────────────────
set -e

ADB="${ADB:-}"
if [ -z "$ADB" ]; then
  for candidate in \
    "$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe" \
    "$HOME/Android/Sdk/platform-tools/adb" \
    "adb"; do
    if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
      ADB="$candidate"
      break
    fi
  done
fi
if [ -z "$ADB" ]; then
  echo "ERREUR : adb introuvable. Installez les platform-tools Android."
  exit 1
fi

echo "[1/2] Vérifie la connexion du téléphone..."
"$ADB" get-state

echo "[2/2] Lancement de DigitalPress (com.digitalpress.app)..."
"$ADB" shell am start -n com.digitalpress.app/.MainActivity

echo
echo "OK : l'app est lancée, le tap sur l'icône fonctionnera normalement."
