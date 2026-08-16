# DigitalPress — Repères pour Claude

Presse numérique africaine. Backend Django (dossier `backend/`) + app mobile
Flutter (dossier `lib/` à la racine). Déploiement **VPS Ubuntu 24.04 direct
via Systemd, sans Docker** (voir `lancement.md` et `deploy_vps_direct.sh`).

## Architecture
- Backend : Django REST Framework + Daphne (ASGI) + Django Channels
  (WebSockets) + PostgreSQL + Redis. Apps dans `backend/apps/` :
  `accounts`, `publications`, `abonnements`, `paiements`, `comptabilite`,
  `notifications`, `roadmap`.
- Frontend mobile : Flutter (Riverpod + GoRouter), FCM, Syncfusion PDF
  Viewer, WebSockets.
- Reverse proxy : Nginx → 127.0.0.1:8000, statiques via WhiteNoise.

## Modèle économique éditeur (important, à ne jamais réintroduire)
Un éditeur n'a **jamais** rien à payer pour accéder à la plateforme.
`PublisherProfile.is_active=True` dès la création du compte par l'admin. Le
palier (Basique / Standard / Premium) est **100% automatique**, calculé
selon le nombre d'abonnés, de publications et de ventes de l'éditeur — voir
`backend/apps/abonnements/services.py::sync_publisher_tier`. La plateforme
se rémunère uniquement via `commission_rate` prélevée sur les ventes.
Ne jamais recréer un flux de paiement pour ce palier (voir
`apps/paiements/views.py`, qui rejette explicitement
`publisher_subscription_id`).

Le seul vrai abonnement payant du système est **Lecteur → Éditeur**
(`apps.abonnements.Plan` / `Abonnement`), distinct du palier ci-dessus.

## Conventions
- Toujours mettre à jour les migrations Django avec `RunPython` pour les
  changements de données de seed (voir `apps/abonnements/migrations/`).
- Les commentaires en tête de fichier/classe documentent le "pourquoi" —
  les lire avant de modifier une logique métier existante.
- Pas de Docker : toute doc de déploiement doit rester alignée sur un
  déploiement direct Systemd + Nginx.

## Commandes utiles (backend)
```
cd backend
source venv/bin/activate
python manage.py migrate
python manage.py runserver          # dev
daphne -b 0.0.0.0 -p 8000 config.asgi:application   # prod (via systemd)
```

## Audit sécurité du 2026-08-16 (failles.pdf, 20 points) — à ne pas réintroduire
- `GoogleAuthView` : ne JAMAIS décoder un jeton Google sans vérification
  de signature (`verify_signature: False` était une prise de contrôle de
  compte). Jeton accepté uniquement via `verify_oauth2_token` ; sans
  `GOOGLE_OAUTH_CLIENT_ID` → 503, jamais de fallback non vérifié.
- CORS production : jamais `CORS_ALLOW_ALL=True` sur le VPS. Utiliser
  `CORS_ALLOW_ALL=False` + `CORS_ALLOWED_ORIGINS` (domaines officiels).
- Activation par email (OTP 15 min) : tout compte créé via
  `/api/accounts/register/` démarre `is_verified=False` et ne peut se
  connecter qu'après validation du code reçu par email. Ne pas retirer ce
  blocage (tous types de profils). `EmailVerificationCode` = modèle dédié
  (hash, expiration 15 min, 5 tentatives). Les comptes existants ont été
  marqués vérifiés par migration de données.
- Numéro de téléphone OBLIGATOIRE à l'inscription (tous rôles) — ne pas
  le rendre optionnel.
- `poster_my_subscription_screen.dart` : les Decimal Django arrivent en
  CHAÎNES ('20.00', '15000.00') — toujours passer par `_toNum()` (jamais
  de cast `as num`), sinon la page « Mon palier » plante (page vide).
- `short_video_player.dart` : le bouton plein écran doit rester AU-DESSUS
  du fond de titre dans le Stack (sinon taps interceptés), et le plein
  écran doit réutiliser le controller EXISTANT (ne jamais créer un second
  lecteur — re-téléchargement + pause apparente).

## Audit du 2026-08-14 — bugs réels corrigés (à ne pas réintroduire)
- Tâche Celery `expirer_abonnements_editeurs` : neutralisée (le palier
  éditeur n'expire jamais). Ne pas la réactiver.
- Réactivation admin d'un éditeur banni : ne doit plus jamais dépendre
  d'un abonnement payant (voir accounts/serializers.py).
- `User.copyWith()` côté Flutter (model/user.dart) doit TOUJOURS propager
  tous les champs — un champ oublié se réinitialise silencieusement à
  chaque appel (bug déjà rencontré une fois avec `isPublisherActive`).
- Badge de compte ("Membre Standard/Premium", "Super utilisateur",
  "Compte vérifié") : logique centralisée dans `User.badge_label` côté
  Django et `User.membershipBadgeLabel` côté Flutter — ne jamais coder un
  libellé de badge en dur ailleurs (ex: "Membre Premium" en dur dans un
  widget), toujours réutiliser/étendre ces deux points centraux.
- `network_security_config.xml` (Android) et ATS (`Info.plist`, iOS)
  autorisent explicitement `192.162.71.56` en HTTP clair tant que le VPS
  n'a pas de certificat SSL — ne pas retirer cette exception sans d'abord
  passer le backend en HTTPS et mettre à jour `AppConfig.baseUrlWeb`.
- Package Android/iOS : `com.digitalpress.app` (changé depuis
  `com.example.digitalpress`, refusé par le Play Store). Toute config
  Firebase doit être refaite/alignée sur ce nouveau package (voir
  avertissement en tête de `lib/firebase_options.dart`).
- Router Flutter (`app_router.dart`) : ne jamais rediriger vers
  `/auth/login` tant que `authStateProvider` n'a pas émis sa première
  valeur (`isLoading && !hasValue`), sous peine de reproduire le bug du
  flash sur l'écran de connexion à chaque lancement.
