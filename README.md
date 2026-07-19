# DigitalPress — Plateforme de Presse Numérique

DigitalPress est une solution complète de kiosque et de presse numérique dédiée à la création, à la gestion et à la diffusion de contenus digitaux sécurisés.

Ce projet unifie :
- **Backend** : Django + Django REST Framework + PostgreSQL + Redis + Celery (géré via Docker)
- **Client Mobile** : Application Flutter moderne avec Riverpod, animations premium et lecteur PDF sécurisé par filigrane dynamique

---

## 🏗️ Architecture Globale

```
digitalpress/
├── backend/               ← API Django REST
│   ├── apps/              ← Modules métier (accounts, publications, paiements…)
│   ├── config/            ← Settings Django, URLs, Celery
│   ├── core/              ← Exceptions personnalisées
│   ├── docker/            ← entrypoint.sh Docker
│   ├── scripts/           ← seed.py, init_db.sh
│   ├── Dockerfile
│   ├── docker-compose.yml ← Lancer le backend seul (depuis backend/)
│   ├── requirements.txt
│   ├── start_backend.ps1  ← Démarrage local Windows
│   ├── start_backend.sh   ← Démarrage local Linux/Mac
│   └── README.md          ← Documentation API complète
│
├── lib/                   ← Application Flutter
│   ├── config/            ← AppConfig, AppTheme, constantes API
│   ├── core/              ← ApiClient (Dio), services, storage, router
│   ├── model/             ← Modèles de données
│   ├── screens/           ← Écrans (Auth, Home, Reader, Paiement…)
│   └── widgets/           ← Composants réutilisables
│
├── scripts/               ← Scripts de lancement (racine)
│   ├── docker-up.ps1      ← Lance toute la stack Docker (Windows)
│   ├── docker-up.sh       ← Lance toute la stack Docker (Linux/Mac)
│   ├── docker-down.ps1    ← Arrête la stack
│   ├── run-flutter.ps1    ← Lance Flutter (Windows)
│   └── fix-flutter-powershell.ps1  ← Fix PowerShell (1 seule fois)
│
├── docker-compose.yml     ← Stack complète depuis la racine (PRINCIPAL)
├── pubspec.yaml
└── README.md              ← Ce fichier
```

---

## 🚀 Démarrage Rapide

### Option A : Stack complète Docker (Recommandé)

Lance PostgreSQL + Redis + Django Backend depuis la **racine du projet** :

#### Windows (PowerShell)
```powershell
.\scripts\docker-up.ps1
```

#### Linux / macOS
```bash
chmod +x scripts/docker-up.sh
./scripts/docker-up.sh
```

#### Manuellement (toutes plateformes)
```bash
docker compose up --build -d
```

---

### Option B : Backend local sans Docker (SQLite)

**Windows (PowerShell) :**
```powershell
cd backend
.\start_backend.ps1
```
**Linux / macOS :**
```bash
cd backend
chmod +x start_backend.sh
./start_backend.sh
```
*Backend disponible sur : `http://127.0.0.1:8000/`*
*Swagger : `http://127.0.0.1:8000/api/docs/`*

---

### Option C : Lancer l'Application Flutter

Dans un **deuxième terminal**, depuis la racine :
```bash
flutter pub get
flutter run
```
Ou via le script (Windows) :
```powershell
.\scripts\run-flutter.ps1
```

---

## 📱 URLs d'API par Plateforme (Automatique)

L'application Flutter adapte automatiquement l'URL de connexion :
- **Windows / Web / Simulateur iOS** : `http://127.0.0.1:8000/api/`
- **Émulateur Android** : `http://10.0.2.2:8000/api/`
- **Téléphone Physique (même WiFi)** : `http://<VOTRE_IP_LAN>:8000/api/`

> **Astuce** : le script `start_backend.ps1` / `start_backend.sh` affiche automatiquement l'IP locale à utiliser.

---

## 🔑 Comptes de Test (Démonstration)

| Identifiant | Mot de passe | Rôle |
| :--- | :--- | :--- |
| `admin` | `Admin123!` | Administrateur |
| `editeur_afrique` | `Editeur@2024!` | Éditeur / Créateur |
| `editeur_tech` | `Editeur@2024!` | Éditeur / Créateur |
| `client_yao` | `Client@2024!` | Lecteur |
| `client_fatou` | `Client@2024!` | Lecteur |

---

## 🔒 Sécurité et Fonctionnalités Clés

1. **JWT sécurisé** : Tokens stockés dans le trousseau système (Keychain/Keystore via FlutterSecureStorage)
2. **Refresh automatique** : `AuthInterceptor` Dio gère le renouvellement transparent des tokens expirés
3. **Filigrane Dynamique** : Affiche l'email de l'utilisateur sur le lecteur PDF (anti-capture)
4. **Paiement Mobile** : Simulation Movapay / Mobile Money avec polling et webhook
5. **Notifications Push** : Firebase Cloud Messaging (FCM)
6. **Celery** : Tâches planifiées (expiration abonnements, réconciliation comptable…)

---

## 🐳 Docker — Deux modes

| Fichier | Depuis | Usage |
|---|---|---|
| `docker-compose.yml` (racine) | `./` | **Principal** — build `./backend`, stack complète |
| `backend/docker-compose.yml` | `./backend/` | Dev backend seul (sans lancer Flutter) |

Les deux sont normaux et complémentaires.

---

## 🛠️ Commandes Utiles

```bash
# Régénérer code auto-généré (Riverpod, JSON)
flutter pub run build_runner build --delete-conflicting-outputs

# Tests Flutter
flutter test

# Logs backend Docker
docker compose logs -f backend

# Arrêter Docker
docker compose down          # ou .\scripts\docker-down.ps1

# Réinitialiser la BDD Docker
docker compose down -v && docker compose up --build -d
```

---

## 📖 Documentation Complémentaire

- **API Backend complète** (endpoints, modèles, Celery) : [`backend/README.md`](backend/README.md)
