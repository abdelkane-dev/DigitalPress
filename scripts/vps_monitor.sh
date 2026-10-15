#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# DigitalPress VPS Monitor — vérifie la santé des services toutes les 5 min
# et alerte par email (via la console Django) si un problème est détecté.
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

LOG="/var/log/dp-monitor.log"
ALERT_SENT="/tmp/.dp_monitor_alerted"
BACKEND="/opt/digitalpress/backend"
VENV="$BACKEND/venv/bin/activate"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "$(timestamp) $1" >> "$LOG"; }

ERRORS=()

# ─── 1. API Health ──────────────────────────────────────────────────────────
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8000/api/health/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "200" ]; then
    ERRORS+=("API DOWN (HTTP $HTTP_CODE)")
    log "CRITICAL: API health check failed (HTTP $HTTP_CODE)"
fi

# ─── 2. Redis ───────────────────────────────────────────────────────────────
if ! redis-cli ping 2>/dev/null | grep -q PONG; then
    ERRORS+=("REDIS DOWN")
    log "CRITICAL: Redis not responding"
fi

# ─── 3. Django service ──────────────────────────────────────────────────────
if ! systemctl is-active --quiet digitalpress; then
    ERRORS+=("DJANGO SERVICE DOWN")
    log "CRITICAL: digitalpress.service is not active"
fi

# ─── 4. Celery worker ──────────────────────────────────────────────────────
if ! systemctl is-active --quiet digitalpress-celery; then
    ERRORS+=("CELERY WORKER DOWN")
    log "CRITICAL: digitalpress-celery.service is not active"
fi

# ─── 5. Celery beat ─────────────────────────────────────────────────────────
if ! systemctl is-active --quiet digitalpress-celery-beat; then
    ERRORS+=("CELERY BEAT DOWN")
    log "CRITICAL: digitalpress-celery-beat.service is not active"
fi

# ─── 6. Disk space (>90% = alerte) ─────────────────────────────────────────
DISK_PCT=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
if [ "$DISK_PCT" -gt 90 ] 2>/dev/null; then
    ERRORS+=("DISK ${DISK_PCT}% FULL")
    log "WARNING: Disk usage at ${DISK_PCT}%"
fi

# ─── 7. Log growth (>100MB = nettoyage) ────────────────────────────────────
DJANGO_LOG="$BACKEND/logs/django.log"
if [ -f "$DJANGO_LOG" ]; then
    LOG_SIZE=$(stat -f%z "$DJANGO_LOG" 2>/dev/null || stat -c%s "$DJANGO_LOG" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 104857600 ]; then
        log "CLEANING: django.log exceeds 100MB ($LOG_SIZE bytes)"
        truncate -s 10M "$DJANGO_LOG"
    fi
fi

# ─── Alertes ────────────────────────────────────────────────────────────────
if [ ${#ERRORS[@]} -gt 0 ]; then
    ERROR_MSG=$(IFS=', '; echo "${ERRORS[*]}")
    log "ALERT: $ERROR_MSG"

    # Éviter le spam : une seule alerte par heure
    if [ ! -f "$ALERT_SENT" ] || [ $(find "$ALERT_SENT" -mmin +60 2>/dev/null | wc -l) -gt 0 ]; then
        # Créer une notification Django pour les admins
        source "$VENV" 2>/dev/null
        cd "$BACKEND"
        python manage.py shell -c "
from apps.accounts.models import User
from apps.notifications.models import Notification
for admin in User.objects.filter(role='admin', is_active=True):
    Notification.objects.create(
        user=admin, type_notif='system',
        title='⚠ Alerte serveur',
        message='Problème détecté: $ERROR_MSG. Vérifiez le VPS immédiatement.',
    )
" 2>/dev/null || true
        touch "$ALERT_SENT"
        log "ALERT SENT: $ERROR_MSG"
    fi
else
    log "OK: All services healthy"
    # Supprimer le fichier d'alerte si tout va bien
    rm -f "$ALERT_SENT"
fi
