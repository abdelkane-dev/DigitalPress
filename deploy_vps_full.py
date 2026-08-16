"""Déploiement complet du backend DigitalPress sur le VPS de production.

Usage :
  DP_VPS_PASSWORD='...' python deploy_vps_full.py

Fait :
  1. Compresse le dossier backend/ en excluant .env (secrets !), venv/,
     media/, logs/, staticfiles/, __pycache__ et *.pyc.
  2. Transfère l'archive via SFTP et l'extrait sur /opt/digitalpress/backend.
  3. Applique les migrations, collectstatic, redémarre les services
     (digitalpress, celery, celery-beat) et vérifie la santé.

Le .env de production n'est JAMAIS écrasé (exclu de l'archive).
"""
import os
import sys
import tarfile
import io
import paramiko

VPS_IP = os.environ.get("DP_VPS_IP", "192.162.71.56")
VPS_USER = os.environ.get("DP_VPS_USER", "root")
PASSWORD = os.environ.get("DP_VPS_PASSWORD", "")
LOCAL_BACKEND = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend")
REMOTE_BACKEND = "/opt/digitalpress/backend"

EXCLUDED_NAMES = {"venv", "media", "logs", "staticfiles", "__pycache__", ".venv"}
EXCLUDED_SUFFIXES = (".pyc",)
EXCLUDED_FILES = {".env", ".env.example"}


def build_archive() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for root, dirs, files in os.walk(LOCAL_BACKEND):
            rel_root = os.path.relpath(root, LOCAL_BACKEND)
            dirs[:] = [d for d in dirs if d not in EXCLUDED_NAMES]
            for fname in files:
                if fname in EXCLUDED_FILES or fname.endswith(EXCLUDED_SUFFIXES):
                    continue
                full = os.path.join(root, fname)
                arcname = os.path.join("backend", rel_root, fname) if rel_root != "." else os.path.join("backend", fname)
                tar.add(full, arcname=arcname)
    return buf.getvalue()


def run(ssh, cmd, timeout=180):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    return out, err


def main():
    try:
        sys.stdout.reconfigure(errors="replace")
        sys.stderr.reconfigure(errors="replace")
    except Exception:
        pass

    if not PASSWORD:
        print("ERREUR : définissez DP_VPS_PASSWORD (jamais en clair dans un fichier).")
        sys.exit(1)

    print(f"Connexion à {VPS_USER}@{VPS_IP}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(VPS_IP, port=22, username=VPS_USER, password=PASSWORD, timeout=20)

    print("1. Construction de l'archive (backend, sans .env/venv/media...)...")
    archive = build_archive()
    print(f"   Archive : {len(archive) / 1024 / 1024:.1f} Mo")

    print("2. Transfert SFTP...")
    sftp = ssh.open_sftp()
    with sftp.file("/tmp/digitalpress_backend.tar.gz", "wb") as f:
        f.write(archive)
    sftp.close()
    print("   Transférée.")

    print("3. Extraction sur le VPS...")
    # Les arcnames de l'archive sont préfixés par 'backend/' : on extrait
    # donc dans /opt/digitalpress (et non à la racine '/', ce qui aurait
    # créé un dossier /backend fantôme à la racine du disque).
    out, err = run(ssh, f"mkdir -p /opt/digitalpress && tar -xzf /tmp/digitalpress_backend.tar.gz -C /opt/digitalpress && rm -f /tmp/digitalpress_backend.tar.gz")
    print(out.strip() or err.strip()[-500:] or "   OK")
    # Nettoyage d'un éventuel /backend fantôme créé par une ancienne
    # extraction incorrecte (jamais /opt/digitalpress/backend).
    out, err = run(ssh, "rm -rf /backend")
    if err.strip():
        print("   [warn] nettoyage /backend:", err.strip()[:200])

    print("4. Vérification Django + migrations...")
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py check 2>&1 | tail -3")
    print(out.strip() or err.strip())
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py migrate --noinput 2>&1 | tail -8")
    print(out.strip() or err.strip())
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && venv/bin/python manage.py collectstatic --noinput 2>&1 | tail -3")
    print(out.strip() or err.strip())

    print("5. Sécurité CORS + config sociale (.env production)...")
    # ─── CORS SÉCURISÉ (audit 2026-08-16) ────────────────────────────────
    # Le .env existant n'est jamais écrasé par l'archive ; on corrige donc
    # ici CORS_ALLOW_ALL=True → False + CORS_ALLOWED_ORIGINS limitée aux
    # domaines officiels, pour qu'aucun site tiers ne puisse appeler l'API.
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && sed -i 's/^CORS_ALLOW_ALL=.*/CORS_ALLOW_ALL=False/' .env")
    if err.strip():
        print("   [warn]", err.strip()[:200])
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && grep -q '^CORS_ALLOWED_ORIGINS=' .env && sed -i 's|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=https://www.digitalpress-ml.com,https://digitalpress-ml.com,https://www.digitalpress.ml,https://digitalpress.ml|' .env || echo 'CORS_ALLOWED_ORIGINS=https://www.digitalpress-ml.com,https://digitalpress-ml.com,https://www.digitalpress.ml,https://digitalpress.ml' >> .env")
    if err.strip():
        print("   [warn]", err.strip()[:200])

    # ─── CONFIG SOCIALE (Google/Facebook) pour l'activation email OTP ────
    # Copie les identifiants applicatifs (Client ID Google, App ID/Secret
    # Facebook) depuis le .env LOCAL vers le .env du VPS s'ils y manquent :
    # sans GOOGLE_OAUTH_CLIENT_ID, la connexion Google renvoie 503 et les
    # nouveaux comptes sociaux ne peuvent pas recevoir leur code d'activation.
    local_env = {}
    try:
        with open(os.path.join(LOCAL_BACKEND, ".env"), encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, _, v = line.partition("=")
                    local_env[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    for key in (
        "GOOGLE_OAUTH_CLIENT_ID",
        "FACEBOOK_APP_ID",
        "FACEBOOK_APP_SECRET",
        # Clés SMS (canal 'sms' des retraits — fournisseur Twilio) : copiées
        # depuis le .env LOCAL dès qu'elles y sont renseignées, pour que le
        # prochain déploiement active les vrais SMS sans toucher à la main
        # le .env du VPS.
        "TWILIO_ACCOUNT_SID",
        "TWILIO_AUTH_TOKEN",
        "TWILIO_FROM_NUMBER",
        "TWILIO_DEFAULT_COUNTRY_CODE",
    ):
        value = local_env.get(key, "")
        if not value:
            continue
        # Le .env du VPS n'est jamais écrasé par l'archive ; on insère la
        # clé si absente, sinon on MET À JOUR sa valeur (pour qu'un simple
        # redéploiement active de nouvelles clés déjà remplies en local).
        out, err = run(
            ssh,
            f"cd {REMOTE_BACKEND} && "
            f"(grep -q '^{key}=' .env && sed -i 's|^{key}=.*|{key}={value}|' .env "
            f"|| echo '{key}={value}' >> .env)",
        )
        if err.strip():
            print(f"   [warn] {key}: {err.strip()[:150]}")
    out, err = run(ssh, f"cd {REMOTE_BACKEND} && grep -E '^(CORS_ALLOW_ALL|CORS_ALLOWED_ORIGINS|GOOGLE_OAUTH_CLIENT_ID|FACEBOOK_APP_ID|FACEBOOK_APP_SECRET|TWILIO_ACCOUNT_SID|TWILIO_AUTH_TOKEN|TWILIO_FROM_NUMBER|TWILIO_DEFAULT_COUNTRY_CODE)=' .env | sed 's/=.*/=<set>/'")
    print(out.strip() or err.strip() or "   (rien à corriger)")

    print("6. Redémarrage des services...")
    out, err = run(ssh, "systemctl restart digitalpress digitalpress-celery digitalpress-celery-beat && sleep 4 && systemctl is-active digitalpress digitalpress-celery digitalpress-celery-beat")
    print(out.strip() or err.strip())

    print("7. Vérification santé...")
    out, err = run(ssh, "sleep 2; curl -s -o /dev/null -w 'https www: %{http_code}\\n' https://www.digitalpress-ml.com/api/health/")
    print(out.strip() or err.strip())
    out, err = run(ssh, "curl -s https://www.digitalpress-ml.com/api/health/")
    print(out.strip()[:200] or "")

    ssh.close()
    print("\nDéploiement terminé.")


if __name__ == "__main__":
    main()
