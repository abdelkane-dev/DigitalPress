# DigitalPress — Lancement & Déploiement (guide complet, poste vierge)

Ce guide part du principe que **rien n'est installé** sur votre machine.
Suivez les sections dans l'ordre.

---

## 0. Prérequis à installer une seule fois

| Outil | Version | Pourquoi |
|---|---|---|
| [Python](https://www.python.org/downloads/) | 3.12+ | Backend Django |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.x (canal stable) | App mobile/desktop/web |
| [PostgreSQL](https://www.postgresql.org/download/) | 15+ | Base de données (obligatoire — le projet n'utilise que PostgreSQL) |
| [Redis](https://redis.io/docs/getting-started/installation/) | 7+ | WebSockets (Django Channels), cache |
| Git | — | Cloner/versionner le projet |
| VS Code | — | Éditeur (extensions déjà recommandées dans `.vscode/extensions.json`) |

Après installation, vérifiez dans un terminal :
```bash
python3 --version
flutter --version
flutter doctor          # doit afficher le moins de X possible
```
`flutter doctor` vous dira précisément ce qu'il manque pour chaque
plateforme cible (Android Studio + SDK pour Android, Xcode pour
iOS/macOS, Visual Studio avec charge de travail "Développement Desktop
C++" pour Windows).

---

## 1. Backend Django — développement local

Le script `backend/start_backend.sh` fait TOUT automatiquement : crée
l'environnement virtuel, installe les dépendances, applique les
migrations, crée un compte admin de démo, lance le serveur.

```bash
cd backend
chmod +x start_backend.sh    # une seule fois
./start_backend.sh
```

À la fin, le script affiche l'IP locale à utiliser et les identifiants de
connexion admin (`admin` / `Admin123!`). **Changez ce mot de passe avant
toute mise en production.**

Sous Windows sans Git Bash/WSL, lancez les mêmes étapes manuellement :
```powershell
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env        # puis éditez .env si besoin
python manage.py migrate
python manage.py create_demo_users
daphne -b 0.0.0.0 -p 8000 config.asgi:application
```

Le serveur écoute alors sur `http://<votre-ip-locale>:8000/api/` (API) et
`ws://<votre-ip-locale>:8000/ws/` (WebSockets).

---

## 2. Frontend Flutter — installation des dépendances

```bash
flutter pub get
```

### 2.1 Pointer l'app vers votre backend local
Dans `lib/config/app_config.dart`, `baseUrl` (Android) pointe par défaut
vers `192.168.1.2` — remplacez par l'IP locale affichée par
`start_backend.sh` (ou utilisez la redirection USB ci-dessous pour un
téléphone Android branché).

### 2.2 Lancer sur un téléphone Android physique (câble USB)
```bash
# Redirige le port du PC vers le téléphone — évite de changer l'IP à chaque fois
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

### 2.3 Lancer sur émulateur Android
L'émulateur voit le PC hôte via l'IP spéciale `10.0.2.2` :
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/
```

### 2.4 Lancer sur simulateur/appareil iOS (macOS + Xcode requis)
```bash
open ios/Runner.xcworkspace   # première fois : vérifier signature dans Xcode
flutter run -d ios --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

### 2.5 Lancer sur macOS (app native desktop)
```bash
flutter run -d macos --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

### 2.6 Lancer sur Windows (app native desktop)
```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

### 2.7 Lancer sur le Web
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/
```

Lister les appareils/plateformes disponibles à tout moment :
```bash
flutter devices
```

---

## 3. Builds de production — pointent tous vers le VPS

Nom de domaine officiel : **`https://www.digitalpress-ml.com`** (TOUJOURS
avec le préfixe `www` — le domaine nu `digitalpress-ml.com` est intercepté
par le proxy anti-DDoS de l'hébergeur, en-têtes X-Anubis, et renvoie 404).
IP VPS : `192.162.71.56`.

```bash
# Android — App Bundle pour le Play Store
flutter build appbundle --release

# Android — APK (test direct, hors Play Store)
flutter build apk --release

# iOS — nécessite macOS + Xcode + compte Apple Developer
flutter build ios --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release

# Web
flutter build web --release
```

En mode `--release`, l'app pointe **automatiquement** vers le VPS
(`AppConfig.baseUrlWeb`, voir `lib/config/api_config.dart`) — pas besoin
de `--dart-define` pour ces builds.

Le VPS est désormais servi en **HTTPS avec Let's Encrypt** (`www` OK,
vérifié : `https://www.digitalpress-ml.com/api/health/` → 200). Toutes les
URLs de production (API, médias, webhooks, retours de paiement) utilisent
**uniquement** le nom de domaine `https://www.digitalpress-ml.com` — jamais
l'IP brute ni le domaine nu.

⚠️ Si `https://digitalpress-ml.com` (sans www) affiche encore une erreur,
c'est le proxy de l'hébergeur qui intercepte le domaine nu : le bloc nginx
`deploy_vps_direct.sh` redirige déjà nu → www une fois la requête arrivée au
VPS, mais il faut aussi corriger la zone DNS / le proxy chez l'hébergeur
pour que le domaine nu atteigne le VPS.

---

## 4. Déploiement sur le VPS de production

IP VPS : `192.162.71.56`, hostname `vps123184.serveur-vps.net`, Ubuntu
24.04 LTS, déploiement direct Systemd (sans Docker).

### 4.1 Copier le projet sur le VPS
Depuis votre machine (remplacez le chemin local par le vôtre) :
```bash
scp -r /chemin/vers/digitalpress_corrige root@192.162.71.56:/opt/digitalpress
```
Sous Windows PowerShell :
```powershell
scp -r C:\chemin\vers\digitalpress_corrige root@192.162.71.56:/opt/digitalpress
```

### 4.2 Lancer l'installation automatique sur le VPS
```bash
ssh root@192.162.71.56
bash /opt/digitalpress/deploy_vps_direct.sh
```
Ce script installe PostgreSQL, Redis, le service Systemd Daphne, et
configure Nginx (voir le fichier pour le détail exact des étapes).

### 4.3 Mises à jour ultérieures (après le premier déploiement)
```bash
ssh root@192.162.71.56
cd /opt/digitalpress/backend
source venv/bin/activate
git pull                      # ou re-scp des fichiers modifiés
python manage.py migrate
python manage.py collectstatic --noinput
systemctl restart digitalpress
journalctl -u digitalpress -f   # vérifier les logs en direct après redémarrage
```

### 4.4 Changer le mot de passe root du VPS
Un mot de passe root a circulé en clair pendant le développement (chat,
scripts de débogage aujourd'hui supprimés — voir FICHIERS_SUPPRIMES.txt).
Par précaution, changez-le :
```bash
ssh root@192.162.71.56
passwd
```

---

## 5. Ce qui reste à faire ailleurs que dans ce dépôt

Voir `PROMPT_POUR_IDE_AGENTIQUE.md` pour la liste complète et détaillée
(config Google Sign-In/Firebase, certificats de signature Play
Store/App Store, HTTPS). Ce ne sont pas des commandes de lancement mais
des actions ponctuelles sur des comptes/consoles externes.
