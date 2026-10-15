# 🗞️ Digital Press — Backend Django REST API

## Vue d'ensemble

Backend complet pour la plateforme **Digital Press** — presse numérique africaine.

| Technologie | Version |
|---|---|
| Python | 3.10+ |
| Django | 4.2 LTS |
| Django REST Framework | 3.15 |
| PostgreSQL | 15 |
| Redis | 7 |
| Celery | 5.3 |

---

## 🚀 Démarrage rapide

### 1. Prérequis
```bash
# PostgreSQL + Redis doivent être en cours d'exécution
python3 --version  # 3.10+
```

### 2. Installation automatique
```bash
git clone <repo>
cd digital_press_backend
bash scripts/init_db.sh
```

### 3. Démarrage manuel
```bash
python3 -m venv venv
source venv/bin/activate          # Linux/Mac
# venv\Scripts\activate           # Windows

pip install -r requirements.txt
cp .env.example .env              # Éditer .env !

python manage.py makemigrations accounts publications abonnements paiements comptabilite notifications
python manage.py migrate
python scripts/seed.py            # Données de test
python manage.py runserver        # http://localhost:8000
```

```

---

## 🔑 Comptes de test

| Identifiant | Mot de passe | Rôle |
|---|---|---|
| `admin` | `Admin@2024!` | Administrateur |
| `editeur_afrique` | `Editeur@2024!` | Éditeur / Entreprise |
| `editeur_tech` | `Editeur@2024!` | Éditeur / Entreprise |
| `client_yao` | `Client@2024!` | Lecteur / Client |
| `client_fatou` | `Client@2024!` | Lecteur / Client |

---

## 🌐 Endpoints API

| URL | Description |
|---|---|
| `http://localhost:8000/api/docs/` | **Swagger UI** |
| `http://localhost:8000/api/redoc/` | **ReDoc** |
| `http://localhost:8000/admin/` | Django Admin |

### Authentification JWT
```bash
# 1. Obtenir un token
POST /api/accounts/login/
{"username": "admin", "password": "Admin@2024!"}
# → {"access": "...", "refresh": "...", "user": {...}}

# 2. Utiliser le token
GET /api/accounts/me/
Authorization: Bearer <access_token>

# 3. Rafraîchir le token
POST /api/accounts/token/refresh/
{"refresh": "<refresh_token>"}
```

---

## 📋 Modules API

### 👤 Accounts (`/api/accounts/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/register/` | Créer un compte | Non |
| POST | `/login/` | Connexion JWT | Non |
| POST | `/token/refresh/` | Rafraîchir token | Non |
| GET/PUT | `/me/` | Mon profil | Oui |
| POST | `/me/change-password/` | Changer mdp | Oui |
| GET/PUT | `/me/publisher-profile/` | Profil éditeur | Publisher |
| GET | `/users/` | Liste utilisateurs | Admin |
| GET | `/publishers/` | Liste éditeurs + soldes | Admin |

### 📰 Publications (`/api/publications/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/` | Liste publications | Non |
| GET | `/<id>/` | Détail publication | Non |
| GET | `/categories/` | Catégories | Non |
| GET/POST | `/my/` | Mes publications | Publisher |
| PUT/DELETE | `/my/<id>/` | Modifier/supprimer | Publisher |
| GET | `/admin/` | Toutes publications | Admin |
| POST | `/<id>/reviews/add/` | Ajouter un avis | Reader |

### 💳 Abonnements (`/api/abonnements/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/plans/` | Plans disponibles | Non |
| GET | `/my/` | Mes abonnements | Oui |
| POST | `/create/` | S'abonner | Oui |
| POST | `/<id>/activate/` | Activer (après paiement) | Admin |
| GET | `/admin/` | Tous abonnements | Admin |
| GET | `/publisher/` | Abonnements reçus | Publisher |

### 💰 Paiements (`/api/paiements/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| POST | `/initier/` | Initier paiement Movapay | Oui |
| POST | `/verifier/` | Vérifier statut | Oui |
| POST | `/webhook/` | Webhook Movapay | Non |
| GET | `/transactions/` | Mes transactions | Oui |
| POST | `/retrait/demander/` | Demander retrait | Publisher |
| GET | `/retrait/mes-demandes/` | Mes demandes retrait | Publisher |
| GET | `/admin/transactions/` | Toutes transactions | Admin |
| GET | `/admin/retraits/` | Demandes de retrait | Admin |
| POST | `/admin/retraits/<id>/traiter/` | Traiter retrait | Admin |

### 📊 Comptabilité (`/api/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/admin/dashboard/stats/` | KPIs dashboard | Admin |
| GET | `/admin/dashboard/top-editeurs/` | Top éditeurs | Admin |
| GET | `/admin/dashboard/evolution-ventes/` | Évolution mensuelle | Admin |
| GET | `/admin/comptabilite/journal/` | Journal comptable | Admin |
| GET | `/admin/comptabilite/journal/<id>/` | Détail écriture | Admin |
| GET/POST | `/admin/comptabilite/reconciliation/` | Réconciliation | Admin |
| GET | `/admin/comptabilite/export/?format=csv` | Export CSV journal | Admin |
| GET | `/admin/comptabilite/export/transactions/` | Export CSV transactions | Admin |
| GET | `/admin/editeurs/soldes/` | Soldes éditeurs | Admin |
| GET | `/entreprise/comptabilite/journal/` | Mon journal | Publisher |
| GET | `/entreprise/comptabilite/solde/` | Mon solde | Publisher |
| GET | `/entreprise/comptabilite/export/` | Export CSV éditeur | Publisher |
| GET | `/entreprise/comptabilite/stats/` | Stats ventes | Publisher |
| GET | `/entreprise/transactions/` | Historique transactions | Publisher |

### 🔔 Notifications (`/api/notifications/`)
| Méthode | Endpoint | Description | Auth |
|---|---|---|---|
| GET | `/` | Mes notifications | Oui |
| GET | `/count/` | Compteur non lues | Oui |
| POST | `/mark-read/` | Tout marquer lu | Oui |
| POST | `/<id>/mark-read/` | Marquer lu | Oui |
| POST | `/fcm/register/` | Enregistrer token FCM | Oui |

---

## 🐛 Bugs Corrigés

| # | Problème | Correction |
|---|---|---|
| BUG-001 | **Historique transactionnel manquant** | Endpoints `/entreprise/transactions/` et `/admin/transactions/` créés avec filtrage complet |
| BUG-002 | **Journal comptable incomplet** | Modèle `EcritureComptable` complet avec tous les champs + endpoint CRUD |
| BUG-003 | **Endpoints comptables manquants** | 15+ nouveaux endpoints comptables créés |
| BUG-004 | **Pas de réconciliation** | Modèle `ReconciliationComptable` + calcul automatique |
| BUG-005 | **Commission non enregistrée** | Fonction `enregistrer_ecriture()` crée 2 écritures (recette + commission) |
| BUG-006 | **Solde éditeur non mis à jour** | Mise à jour automatique via webhook Movapay + tâche Celery |
| BUG-007 | **Export CSV absent** | Endpoints export CSV pour admin et éditeurs |
| BUG-008 | **Pas de dashboard stats** | Endpoint `/admin/dashboard/stats/` avec tous les KPIs |
| BUG-009 | **Webhook Movapay absent** | `POST /api/paiements/webhook/` implémenté |
| BUG-010 | **Tâches Celery manquantes** | 6 tâches planifiées (vérification paiements, expiration abo, réconciliation...) |

---

## ⚙️ Tâches Celery planifiées

| Tâche | Fréquence | Description |
|---|---|---|
| `verifier_paiements_pending_batch` | Toutes les 5 min | Vérifie transactions pending > 5min |
| `expirer_abonnements` | Quotidien 02h00 | Expire les abonnements terminés |
| `nettoyer_transactions_abandonnees` | Quotidien 03h00 | Annule transactions > 24h |
| `calculer_reconciliation_mensuelle` | 1er du mois 01h00 | Réconciliation comptable mensuelle |

### Lancer Celery
```bash
# Worker
celery -A config worker --loglevel=info

# Beat (scheduler)
celery -A config beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler

# Flower (monitoring)
pip install flower
celery -A config flower
```

---

## 🏗️ Architecture

```
digital_press_backend/
├── apps/
│   ├── accounts/         # Utilisateurs, JWT, profils éditeurs
│   ├── publications/     # Publications, catégories, avis
│   ├── abonnements/      # Plans et abonnements
│   ├── paiements/        # Transactions Movapay, retraits
│   ├── comptabilite/     # Journal, réconciliation, exports, tâches Celery
│   └── notifications/    # Notifications, tokens FCM
├── config/
│   ├── settings.py       # Configuration Django
│   ├── urls.py           # Routes principales
│   ├── celery.py         # Configuration Celery
│   ├── wsgi.py
│   └── asgi.py
├── core/
│   └── exceptions.py     # Gestion d'erreurs personnalisée
├── scripts/
│   ├── seed.py           # Population BDD
│   └── init_db.sh        # Script d'init complet
├── manage.py
├── requirements.txt
├── .env.example
├── Dockerfile
└── docker-compose.yml
```

---

## 💡 Intégration Movapay

En mode développement (sans clé API configurée), le service utilise automatiquement un **sandbox mock** qui simule les paiements.

```python
# Configuration dans .env
CINETPAY_API_KEY=votre_cle_api
CINETPAY_SITE_ID=votre_site_id
CINETPAY_SECRET=votre_secret
CINETPAY_BASE_URL=https://api-checkout.cinetpay.com/v2
```

**Flux de paiement:**
1. `POST /api/paiements/initier/` → obtenir `payment_url`
2. Rediriger l'utilisateur vers `payment_url`
3. Movapay appelle `POST /api/paiements/webhook/`
4. OU vérifier manuellement avec `POST /api/paiements/verifier/`
