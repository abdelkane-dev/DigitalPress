"""Déploiement de l'app Web Flutter (build/web) sur le VPS.

Usage :
  DP_VPS_PASSWORD='...' python deploy_web_vps.py

Étapes :
  1. Compresse build/web et l'extrait dans /opt/digitalpress/webapp.
  2. Sauvegarde la config nginx actuelle, en écrit une nouvelle qui sert
     l'app web à la racine (/) tout en conservant /api/, /admin/, /media/,
     /static/ et /ws/ vers le backend Django.
  3. nginx -t + reload + vérification finale.
"""
import io
import os
import sys
import tarfile
import paramiko

VPS_IP = os.environ.get("DP_VPS_IP", "192.162.71.56")
VPS_USER = os.environ.get("DP_VPS_USER", "root")
PASSWORD = os.environ.get("DP_VPS_PASSWORD", "")
LOCAL_WEB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

NGINX_CONFIG = """# DigitalPress — Nginx : sert l'app web Flutter à la racine, l'API Django
# sous /api/ (+ /admin/, /media/, /static/, /ws/).
server {
    listen 443 ssl; # managed by Certbot
    server_name www.digitalpress-ml.com;
    client_max_body_size 50M;

    ssl_certificate /etc/letsencrypt/live/digitalpress-ml.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/digitalpress-ml.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    # Médias uploadés (images, PDF, vidéos)
    location /media/ {
        alias /opt/digitalpress/backend/media/;
    }

    # Statiques Django (admin)
    location /static/ {
        alias /opt/digitalpress/backend/staticfiles/;
    }

    # API + admin Django → Daphne
    location ~ ^/(api|admin)/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSockets → Daphne
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

    # App Web Flutter (SPA : repli sur index.html pour le routing)
    location / {
        root /opt/digitalpress/webapp;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}

# Domaine nu → www (requêtes qui atteignent le VPS)
server {
    listen 443 ssl; # managed by Certbot
    server_name digitalpress-ml.com digitalpress.ml;
    ssl_certificate /etc/letsencrypt/live/digitalpress-ml.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/digitalpress-ml.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
    return 301 https://www.digitalpress-ml.com$request_uri;
}

# HTTP → HTTPS (géré par Certbot, conservé)
server {
    listen 80;
    server_name www.digitalpress-ml.com;
    return 301 https://$host$request_uri;
}

server {
    listen 80;
    server_name digitalpress-ml.com digitalpress.ml;
    return 301 https://www.digitalpress-ml.com$request_uri;
}
"""


def run(ssh, cmd, timeout=120):
    stdin, stdout, stderr = ssh.exec_command(cmd, timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    return out, err


def build_archive() -> bytes:
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for root, dirs, files in os.walk(LOCAL_WEB):
            rel_root = os.path.relpath(root, LOCAL_WEB)
            for fname in files:
                full = os.path.join(root, fname)
                arcname = os.path.join("webapp", rel_root, fname) if rel_root != "." else os.path.join("webapp", fname)
                tar.add(full, arcname=arcname)
    return buf.getvalue()


def main():
    try:
        sys.stdout.reconfigure(errors="replace")
        sys.stderr.reconfigure(errors="replace")
    except Exception:
        pass

    if not PASSWORD:
        print("ERREUR : définissez DP_VPS_PASSWORD.")
        sys.exit(1)

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    print(f"Connexion à {VPS_USER}@{VPS_IP}...")
    ssh.connect(VPS_IP, port=22, username=VPS_USER, password=PASSWORD, timeout=20)

    print("1. Compression de build/web...")
    archive = build_archive()
    print(f"   Archive : {len(archive) / 1024 / 1024:.1f} Mo")

    print("2. Transfert + extraction vers /opt/digitalpress/webapp...")
    sftp = ssh.open_sftp()
    with sftp.file("/tmp/digitalpress_web.tar.gz", "wb") as f:
        f.write(archive)
    sftp.close()
    out, err = run(ssh, "rm -rf /opt/digitalpress/webapp && mkdir -p /opt/digitalpress && tar -xzf /tmp/digitalpress_web.tar.gz -C /opt/digitalpress && rm -f /tmp/digitalpress_web.tar.gz && ls /opt/digitalpress/webapp | head -5")
    print(out.strip() or err.strip()[-400:] or "   OK")

    print("3. Sauvegarde + nouvelle config nginx...")
    out, err = run(ssh, "cp /etc/nginx/sites-available/digitalpress /etc/nginx/sites-available/digitalpress.bak && echo backup_ok")
    print(out.strip() or err.strip())
    sftp = ssh.open_sftp()
    with sftp.file("/etc/nginx/sites-available/digitalpress", "w") as f:
        f.write(NGINX_CONFIG)
    sftp.close()

    print("4. Test nginx + reload...")
    out, err = run(ssh, "nginx -t 2>&1 | tail -3")
    print(out.strip() or err.strip())
    if "successful" not in (out + err):
        print("   ⚠️  Test nginx échoué — restauration de l'ancienne config.")
        run(ssh, "cp /etc/nginx/sites-available/digitalpress.bak /etc/nginx/sites-available/digitalpress && nginx -t 2>&1 | tail -2")
        ssh.close()
        sys.exit(1)
    out, err = run(ssh, "systemctl reload nginx && echo reloaded")
    print(out.strip() or err.strip())

    print("5. Vérifications...")
    out, err = run(ssh, "sleep 2; curl -s -o /dev/null -w 'racine web: %{http_code}\\n' https://www.digitalpress-ml.com/ ; curl -s -o /dev/null -w 'api health: %{http_code}\\n' https://www.digitalpress-ml.com/api/health/ ; curl -s -o /dev/null -w 'admin: %{http_code}\\n' https://www.digitalpress-ml.com/admin/login/")
    print(out.strip() or err.strip())
    out, err = run(ssh, "curl -s https://www.digitalpress-ml.com/ | grep -o '<title>[^<]*</title>' | head -1")
    print(out.strip() or err.strip())

    ssh.close()
    print("\nDéploiement web terminé.")


if __name__ == "__main__":
    main()
