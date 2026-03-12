# DigitalPress — Foundation Documentation

Objectif
-------
Ce document décrit la fondation fournie : structure du backend Django/DRF, endpoints API essentiels, structure du client Flutter, scripts d'aide au développement et notes d'extension.

Principe
--------
Il s'agit d'une fondation propre et minimale destinée aux équipes qui construiront la logique métier. Le code évite les fonctionnalités sensibles (paiements, DRM, analytics, anti-capture).

Arborescence clé (à la racine)
--------------------------------
- `back/` : backend Django (project + apps)
  - `manage.py` — script Django
  - `config/` — settings, urls, wsgi/asgi
  - `apps/accounts/` — gestion utilisateurs et profils
    - `models.py` : `User`, `PublisherProfile`
    - `serializers.py`, `views.py`, `urls.py`, `permissions.py`
  - `apps/publications/` — modèle `Publication`, sérializers et vues
  - `.env.example` — variables d'environnement
  - `seed.py` — script de peuplement d'exemple (admin, publisher, reader, publication)
  - `requirements.txt` — dépendances Python

- `mobile/` : application Flutter minimaliste
  - `pubspec.yaml` — dépendances Flutter (http, provider)
  - `lib/` — structure modulaire
    - `core/`, `features/` (`auth`, `reader`, `publisher`, `admin`)
    - `services/api_service.dart` — client HTTP simple
    - `providers/auth_provider.dart` — gestion basique du token
    - `routes.dart`, `main.dart`

- `docker-compose.yml` : configuration Docker pour PostgreSQL + backend

Endpoints API (exemples)
-----------------------
- `POST /api/accounts/register/` — inscription (body: `username`, `email`, `password`, `name?`, `role?`)
- `POST /api/accounts/login/` — obtention du JWT (retourne `access` / `refresh`)
- `GET/PUT /api/accounts/me/` — profil connecté
- `GET /api/publications/` — lister publications (public)
- `GET /api/publications/<id>/` — détail publication (public)
- `POST /api/publications/create/` — création (publisher authentifié)
- `GET /api/accounts/users/` — lister utilisateurs (admin)
- Swagger UI : `/swagger/`

Modèles de données (simplifiés)
-------------------------------
- `User` : id, username, email, password, name, role (reader|publisher|admin)
- `PublisherProfile` : user (OneToOne), company_name
- `Publication` : id, title, description, publisher(FK->User), created_at

Authentification
----------------
- JWT via `djangorestframework-simplejwt`. Les endpoints de login/register sont prêts et le front mobile consomme `access` pour les requêtes.

Permissions / Rôles
-------------------
- `IsAdmin`, `IsPublisher`, `IsReader` : classes simples dans `apps/accounts/permissions.py`.
- Exemple d'utilisation : création de publication restreinte aux `publisher`.

Scripts et développement
------------------------
- Installer dépendances Python : `pip install -r back/requirements.txt`
- Variables d'environnement : copier `back/.env.example` -> `back/.env` et adapter
- Migrer et lancer :

```powershell
cd back
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python seed.py
python manage.py runserver
```

- Docker (optionnel) :

```bash
docker-compose up --build
```

Données de test créées par `seed.py`
-----------------------------------
- `admin` / `adminpass` (superuser, role `admin`)
- `publisher1` / `pubpass` (role `publisher`)
- `reader1` / `readerpass` (role `reader`)
- Une publication d'exemple liée à `publisher1`.

Flutter — notes rapides
-----------------------
- Le client Flutter est un scaffold minimal :
  - `AuthProvider` gère le token en mémoire.
  - `ApiService` propose des méthodes `get`/`post` et gère l'entête `Authorization`.
  - Écrans fournis : login, register, reader home (liste factice), publication detail, publisher dashboard, admin panel.
- L'URL de base du backend utilisée dans le scaffold est `http://10.0.2.2:8000/api/` (émulateur Android). Adapter pour iOS/production.

Conseils d'extension
--------------------
- Séparer les settings par environnement (`config/settings/`) avant de produire en prod.
- Ajouter une gestion des migrations et des fixtures plus robuste pour les environnements CI/CD.
- Remplacer les permissions basiques par des classes plus fines si besoin (object-level permissions).
- Intégrer tests unitaires et tests API (pytest / Django test suite).

Limitations volontaires
-----------------------
- Pas de paiement / DRM / analytics / anti-capture.
- Pas de logique métier avancée (workflows, moderation, publication scheduling).

Où commencer pour développer
---------------------------
1. Cloner et lancer le backend. Vérifier `/swagger/` et les endpoints.
2. Étendre `apps.publications` pour ajouter images ou fichiers (FieldFile/Storage) si nécessaire.
3. Sur le mobile, implémenter le parsing JSON réel et remplacer les écrans placeholders par des widgets liés aux endpoints.

Contact et propriétés du dépôt
------------------------------
Ce dépôt est une fondation. Tout nouveau service devrait être documenté et testé avant intégration.
