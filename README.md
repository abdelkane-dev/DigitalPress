# DigitalPress — Boilerplate Foundation

Boilerplate de base pour démarrer la plateforme DigitalPress. Cette fondation fournit :

- Un backend Django + Django REST Framework prêt pour l'extension.
- Une API documentée (Swagger/OpenAPI).
- Authentification JWT simple.
- Un client mobile Flutter minimal pour prototypage.

IMPORTANT : il s'agit d'une fondation. Les fonctionnalités sensibles (paiements, DRM, analytics, anti-capture) ne sont pas implémentées.

Ressources principales
- `back/` : backend Django (migrations, seed, endpoints)
- `mobile/` : application Flutter (scaffold, providers, écrans de base)
- `docs/FOUNDATION.md` : documentation détaillée de la fondation et instructions de démarrage
- `docker-compose.yml` : configuration pour lancer PostgreSQL + backend

Quickstart local (backend)

1. Copier les variables d'environnement :

```powershell
cd back
copy .env.example .env
```

2. Créer un environnement virtuel et installer les dépendances :

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

3. Appliquer les migrations et peupler des données d'exemple :

```powershell
python manage.py migrate
python seed.py
python manage.py runserver
```

4. Swagger UI : `http://localhost:8000/swagger/`

Quickstart avec Docker

```bash
docker-compose up --build
```

Données de test (créées par `back/seed.py`)
- `admin` / `adminpass` (superuser, role `admin`)
- `publisher1` / `pubpass` (role `publisher`)
- `reader1` / `readerpass` (role `reader`)

Mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```

Notes techniques rapides
- Auth JWT : endpoints `api/accounts/login/` et `api/accounts/register/`.
- Permissions de base : `apps/accounts/permissions.py`.
- Exemple de seed et fixtures : `back/seed.py`.

Lire la documentation complète : `docs/FOUNDATION.md`

Contributions
- Cette base est destinée à être forkée et étendue : créer des branches par service/feature, ajouter tests et CI avant merge.

# DigitalPress
Digital Press est une solution de presse numérique dédiée à la création, à la gestion et à la diffusion de contenus digitaux. Elle vise à offrir une plateforme moderne, structurée et évolutive, adaptée aux nouveaux usages des médias et des créateurs d’information.
