"""Déploiement VPS DigitalPress via paramiko.

Utilisation :
  DP_VPS_PASSWORD='...' python deploy_vps_agent.py diag      # lecture seule
  DP_VPS_PASSWORD='...' python deploy_vps_agent.py deploy    # applique tout

Le mot de passe SSH est lu UNIQUEMENT depuis la variable d'environnement
DP_VPS_PASSWORD — jamais stocké dans un fichier.
"""
import os
import sys
import paramiko

VPS_IP = os.environ.get("DP_VPS_IP", "192.162.71.56")
VPS_USER = os.environ.get("DP_VPS_USER", "root")
PASSWORD = os.environ.get("DP_VPS_PASSWORD", "")

LOCAL_BACKEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend")
REMOTE_BACKEND = "/opt/digitalpress/backend"

FILES_TO_UPLOAD = [
    "apps/abonnements/serializers.py",
    "apps/abonnements/models.py",
    "apps/abonnements/migrations/0013_alter_platformplan_options.py",
    "apps/abonnements/migrations/0014_corrige_texte_commissions_paliers.py",
    "apps/publications/serializers.py",
]

DIAG_COMMANDS = [
    "echo '=== .env (sans secrets) ==='; grep -E '^(DEBUG|ALLOWED_HOSTS|CSRF_TRUSTED_ORIGINS|SECURE_|BACKEND_URL|FRONTEND_SUCCESS_URL|DATABASE_NAME|DATABASE_USER|DATABASE_HOST)' " + REMOTE_BACKEND + "/.env 2>/dev/null || echo 'pas de .env'",
    "echo '=== services ==='; systemctl is-active digitalpress digitalpress-daphne 2>/dev/null; systemctl list-units --type=service --state=running 2>/dev/null | grep -iE 'digitalpress|nginx|postgres|redis|celery' | head -10",
    "echo '=== nginx sites ==='; ls /etc/nginx/sites-enabled/ 2>/dev/null; echo '---'; cat /etc/nginx/sites-enabled/digitalpress 2>/dev/null | head -60",
    "echo '=== certbot ==='; certbot --version 2>&1 | head -1 || echo 'certbot absent'",
    "echo '=== manage.py check ==='; cd " + REMOTE_BACKEND + " && venv/bin/python manage.py check 2>&1 | tail -2",
    "echo '=== version ==='; cd " + REMOTE_BACKEND + " && venv/bin/python --version && venv/bin/pip show django 2>/dev/null | grep -E '^Version'",
]


def run(ssh, cmd, timeout=120):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    return out, err


def main():
    # Console Windows cp1252 : ne jamais planter sur un caractère non
    # encodable (ex: U+2192 dans la sortie d'apt) — on remplace au lieu de
    # lever UnicodeEncodeError.
    try:
        sys.stdout.reconfigure(errors="replace")
        sys.stderr.reconfigure(errors="replace")
    except Exception:
        pass

    mode = sys.argv[1] if len(sys.argv) > 1 else "diag"
    if not PASSWORD:
        print("ERREUR : définissez DP_VPS_PASSWORD (jamais en clair dans un fichier).")
        sys.exit(1)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connexion à {VPS_USER}@{VPS_IP}...")
    ssh.connect(VPS_IP, port=22, username=VPS_USER, password=PASSWORD, timeout=20)

    if mode == "diag":
        for cmd in DIAG_COMMANDS:
            print(f"\n$ {cmd.split(';')[0]} ...")
            out, err = run(ssh, cmd)
            print(out.strip())
            if err.strip():
                print("[stderr]", err.strip()[:400])
        ssh.close()
        return

    if mode == "deploy":
        print("\n=== 1. Upload des fichiers backend modifiés ===")
        sftp = ssh.open_sftp()
        for rel in FILES_TO_UPLOAD:
            local = os.path.join(LOCAL_BACKEND, rel.replace("/", os.sep))
            remote = f"{REMOTE_BACKEND}/{rel}"
            sftp.put(local, remote)
            print(f"  -> {rel}")
        sftp.close()

        print("\n=== 2. Verification Django + migrations (securite) ===")
        out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py check 2>&1 | tail -3")
        print(out.strip() or err.strip())
        out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py migrate --noinput 2>&1 | tail -5")
        print(out.strip() or err.strip())

        print("\n=== 3. Correction du .env de production ===")
        # DEBUG doit être False en prod ; les URLs publiques passent en HTTPS.
        env_cmds = [
            "sed -i 's/^DEBUG=.*/DEBUG=False/' .env",
            "sed -i 's|^BACKEND_URL=.*|BACKEND_URL=https://www.digitalpress-ml.com|' .env",
            "sed -i 's|^FRONTEND_SUCCESS_URL=.*|FRONTEND_SUCCESS_URL=https://www.digitalpress-ml.com/payment/success|' .env",
        ]
        for cmd in env_cmds:
            out, err = run(ssh, f"cd {REMOTE_BACKEND} && {cmd}")
            if err.strip():
                print(f"  [warn] {cmd}: {err.strip()[:200]}")
        out, err = run(ssh, f"cd {REMOTE_BACKEND} && grep -E '^(DEBUG|BACKEND_URL|FRONTEND_SUCCESS_URL)' .env")
        print(out.strip() or err.strip())

        print("\n=== 4. Redémarrage du service Daphne ===")
        out, err = run(ssh, "systemctl restart digitalpress && sleep 3 && systemctl is-active digitalpress")
        print(out.strip() or err.strip())

        print("\n=== 5. Valeurs des paliers en production ===")
        out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py shell -c \""
                          f"from apps.abonnements.models import PlatformPlan; "
                          f"[print(f'{{p.name}}: {{p.commission_rate}}% slots={{p.max_priority_slots}} plans={{p.max_reader_plans}} retrait_min={{p.min_withdrawal_amount}} csv={{p.has_stats_export}} seuils={{p.min_subscribers}}/{{p.min_publications}}/{{p.min_sales}}') for p in PlatformPlan.objects.filter(is_active=True).order_by('min_subscribers')]\"")
        print(out.strip() or err.strip())

        print("\n=== 6. Certificat HTTPS (Let's Encrypt) ===")
        out, err = run(ssh, "apt-get install -y certbot python3-certbot-nginx 2>&1 | tail -2", timeout=300)
        print(out.strip() or err.strip())
        out, err = run(
            ssh,
            "certbot --nginx -d digitalpress-ml.com -d www.digitalpress-ml.com "
            "--non-interactive --agree-tos --register-unsafely-without-email --redirect 2>&1 | tail -12",
            timeout=300,
        )
        print(out.strip() or err.strip())

        print("\n=== 7. Rechargement nginx + vérification ===")
        run(ssh, "systemctl reload nginx")
        out, err = run(ssh, "sleep 2; curl -s -o /dev/null -w 'https www: %{http_code}\\n' https://www.digitalpress-ml.com/api/health/ ; curl -s -o /dev/null -w 'https bare: %{http_code}\\n' https://digitalpress-ml.com/api/health/ ; curl -s -o /dev/null -w 'http→https redirect: %{http_code} url=%{redirect_url}\\n' http://www.digitalpress-ml.com/api/health/")
        print(out.strip() or err.strip())

        ssh.close()
        print("\nTerminé.")
        return

    if mode == "cert":
        print("=== Certificat HTTPS (Let's Encrypt) ===")
        out, err = run(ssh, "apt-get install -y certbot python3-certbot-nginx 2>&1 | tail -2", timeout=300)
        print(out.strip() or err.strip())
        out, err = run(
            ssh,
            "certbot --nginx -d digitalpress-ml.com -d www.digitalpress-ml.com "
            "--non-interactive --agree-tos --register-unsafely-without-email --redirect 2>&1 | tail -12",
            timeout=300,
        )
        print(out.strip() or err.strip())
        print("\n=== Verification ===")
        run(ssh, "systemctl reload nginx")
        out, err = run(ssh, "sleep 2; curl -s -o /dev/null -w 'https www: %{http_code}\\n' https://www.digitalpress-ml.com/api/health/ ; curl -s -o /dev/null -w 'https bare: %{http_code}\\n' https://digitalpress-ml.com/api/health/ ; curl -s -o /dev/null -w 'http redirect: %{http_code} -> %{redirect_url}\\n' http://www.digitalpress-ml.com/api/health/")
        print(out.strip() or err.strip())
        ssh.close()
        print("Termine.")
        return

    if mode == "celery":
        print("=== Services Celery worker + beat ===")
        worker_unit = """[Unit]
Description=DigitalPress Celery Worker
After=network.target redis-server.service postgresql.service

[Service]
User=root
WorkingDirectory=/opt/digitalpress/backend
ExecStart=/opt/digitalpress/backend/venv/bin/celery -A config worker --loglevel=info --concurrency=2
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
        beat_unit = """[Unit]
Description=DigitalPress Celery Beat Scheduler
After=network.target redis-server.service postgresql.service

[Service]
User=root
WorkingDirectory=/opt/digitalpress/backend
ExecStart=/opt/digitalpress/backend/venv/bin/celery -A config beat --loglevel=info
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
        sftp = ssh.open_sftp()
        with sftp.file("/tmp/digitalpress-celery.service", "w") as f:
            f.write(worker_unit)
        with sftp.file("/tmp/digitalpress-celery-beat.service", "w") as f:
            f.write(beat_unit)
        sftp.close()

        cmds = [
            "mv /tmp/digitalpress-celery.service /etc/systemd/system/ && mv /tmp/digitalpress-celery-beat.service /etc/systemd/system/",
            "systemctl daemon-reload",
            "systemctl enable --now digitalpress-celery digitalpress-celery-beat 2>&1 | tail -2",
            "sleep 5",
            "systemctl is-active digitalpress-celery digitalpress-celery-beat",
            "cd /opt/digitalpress/backend && venv/bin/celery -A config inspect ping 2>&1 | tail -4",
        ]
        for cmd in cmds:
            out, err = run(ssh, cmd, timeout=90)
            txt = (out or err).strip()
            if txt:
                print(txt)
        ssh.close()
        print("Termine.")
        return

    print("Usage : deploy_vps_agent.py diag|deploy|cert|celery")
    ssh.close()


if __name__ == "__main__":
    main()
