# Modifications apportées — Digital Press

> Ce fichier a été mis à jour à huit reprises. La section "MISE À JOUR 9"
> décrit les derniers ajouts (OTP retraits, activation email des comptes
> Google/Facebook, pause vidéo au tap, compteur d'achats, redirection après
> achat, publication, Mon Portefeuille éditeur, titres, détail utilisateur
> admin, page profil éditeur retravaillée).

## MISE À JOUR 9 — OTP retraits, activation sociale, notes de test, admin

### 1. Retraits d'argent : confirmation OTP (email ou SMS) obligatoire
- **Backend** : nouveau modèle `WithdrawalVerificationCode` (code 6 chiffres,
  hash SHA-256, 15 min, 5 tentatives max, un seul usage) dans
  `apps/paiements/`. Nouvel endpoint `POST /paiements/retrait/otp/` qui
  envoie le code (email toujours ; canal SMS branché dès qu'un fournisseur
  sera configuré — `WithdrawalOtpView._deliver_sms` est le point de
  branchement). `DemanderRetraitView` refuse désormais toute demande sans
  `otp_code` valide (le code est consommé à l'usage).
- **Frontend** : `withdrawal_request_sheet.dart` réécrit — étapes Moyen →
  Numéro/Montant → Choix Email/SMS → Saisie du code → Validation. Les
  callers (comptabilité éditeur + admin) transmettent `otp_code`.

### 2. Comptes Google/Facebook : activation email OTP 15 min obligatoire
- `GoogleAuthView` / `FacebookAuthView` : un compte créé (ou existant non
  activé) ne reçoit PLUS de jeton — le backend émet un code OTP d'activation
  (15 min) et répond `email_verification_required=True`. L'app bascule sur
  `/auth/verification?mode=activate` (nouvelle exception
  `EmailVerificationRequiredException` côté Flutter). Une fois l'email
  validé, la connexion sociale délivre les jetons normalement.

### 3. Notes de test « Digital Press — Observations » traitées
- **Pause vidéo au tap** : toucher la vidéo met en pause / reprend (lecteur
  inline ET plein écran) au lieu de ne faire qu'afficher/masquer les
  contrôles (`short_video_player.dart`).
- **Compteur « Achats » du profil** : les stats étaient figées depuis la
  connexion — `ProfileScreen` recharge le profil à chaque ouverture ; le
  backend ne compte plus que les achats `status='success'`.
- **Après un achat → ouverture directe de l'article** : le bouton de succès
  du paiement (« Lire l'article ») remplace l'écran de paiement par le
  lecteur de l'article acheté (hors recharge de portefeuille).
- **Publication** : pré-validation explicite « un article publié doit
  contenir du texte » avec message clair avant l'envoi (le backend renvoie
  déjà ce message précis via l'handler d'erreurs).
- **« Mon Portefeuille » ajouté au profil éditeur** (argent personnel,
  recharges, achats), séparé de « Comptabilité Presse » (revenus/ventes).
- **Titres de pages** : « profil », « conversations », « mes abonnés » →
  « Profil », « Conversations », « Mes abonnés » (capitalisation centralisée
  dans `main_app_bar.dart`).

### 4. Admin : page de détail utilisateur + actions
- Nouveaux endpoints : `GET /accounts/admin/users/<pk>/detail/` (identité,
  rôle, création, dernière activité, achats/paiements, statut, historique
  de modération, agence/vérification pour les éditeurs) et
  `POST /accounts/admin/users/<pk>/action/` (`suspend` | `ban` |
  `reactivate`, avec motif journalisé dans `AccountActionLog`).
- Nouvel écran `admin_user_detail_screen.dart` (route `/admin/user/:id`) ;
  chaque utilisateur de « Gestion des utilisateurs » est cliquable.

### 5. Page profil éditeur retravaillée (image)
- Bannière « % Commission plateforme : 20.0% • Palier Basique » SUPPRIMÉE
  (info interne sans rapport avec la page publique — reste visible dans
  Comptabilité Presse).
- Design amélioré : nom de l'agence en évidence sous l'avatar, @username en
  sous-titre, bouton « Modifier le profil » orange, onglets avec libellés
  (Publications / Exclusif), boutons arrondis avec ombre.
- « Partager le profil » copie VRAIMENT le lien (`https://www.digitalpress-
  ml.com/publisher/<id>`) — l'ancien affichait « Lien copié » sans rien
  copier.

### 6. Migrations & tests
- `paiements/0006_withdrawalverificationcode.py`,
  `accounts/0011_accountactionlog.py`. Tests backend : 27 OK (dont retraits
  sans OTP refusés, Google/Facebook exigeant l'activation). `flutter analyze`
  et `flutter test` : OK.

## MISE À JOUR 8 — Audit sécurité (20 points), activation par email (OTP),
« Mon palier » réparé, plein écran vidéo corrigé, note correctifs appliquée

### 1. Audit sécurité « failles.pdf » — failles réelles corrigées
- **GOOGLE_AUTH (critique, prise de contrôle de compte)** :
  `accounts/views.py::GoogleAuthView` décodait le jeton Google SANS
  vérifier sa signature (`verify_signature: False`) dès que
  `GOOGLE_OAUTH_CLIENT_ID` n'était pas configuré — n'importe qui pouvait
  forger un jeton et se connecter comme n'importe quel email. Désormais :
  jeton accepté UNIQUEMENT s'il est vérifié cryptographiquement par
  Google ; sans Client ID configuré, la connexion Google renvoie 503
  (plus aucun fallback non vérifié).
- **CORS production** : `deploy_vps_direct.sh` écrivait `CORS_ALLOW_ALL=True`
  dans le `.env` de production (n'importe quel site pouvait appeler l'API
  depuis le navigateur des utilisateurs). Remplacé par
  `CORS_ALLOW_ALL=False` + `CORS_ALLOWED_ORIGINS` limitée aux domaines
  officiels (www.digitalpress-ml.com…). ⚠️ À appliquer sur le VPS :
  modifier `CORS_ALLOW_ALL=True` → `False` + `CORS_ALLOWED_ORIGINS=…`
  dans `/var/www/.../.env` puis redémarrer le service, OU relancer le
  script de déploiement (le .env existant n'est pas réécrit).
- **Vérifiés sains** (rien à corriger) : .env non versionné, filtres
  serveur par propriétaire (warnings, abonnements, retraits,
  transactions), droits serveur (rôles admin/éditeur protégés contre
  l'auto-promotion), throttles sur auth (10/min), ORM Django (pas de SQL
  concaténé), hachage mot de passe Django (PBKDF2), tokens JWT dans le
  Secure Storage (Keychain/Keystore), back-office Django authentifié,
  webhooks CinetPay avec signature HMAC + re-vérification du statut réel,
  uploads avec whitelist d'extensions + limite de taille,
  `validate_password` (robustesse), erreurs masquées en production.

### 2. Activation du compte par email — OTP 15 min (note Dr. Sissoko)
- **Backend** : nouveau modèle `EmailVerificationCode` (code 6 chiffres,
  hash SHA-256, 15 min de validité, 5 tentatives max). À l'inscription,
  un OTP est envoyé par email ; le compte est créé NON VÉRIFIÉ et la
  connexion est bloquée tant que l'email n'est pas validé (code
  `email_not_verified`). Nouveaux endpoints :
  `POST /api/accounts/verify-email/` et
  `POST /api/accounts/resend-email-verification/` (throttlés).
- **Migration** : `accounts/0010_*` — les comptes EXISTANTS sont marqués
  vérifiés (personne n'est bloqué rétroactivement) ; seuls les nouveaux
  comptes doivent s'activer.
- **Numéro de téléphone obligatoire** à l'inscription (tous types de
  compte) : validation serveur + champ requis côté app.
- **Frontend** : champ téléphone ajouté au formulaire d'inscription ;
  après inscription, bascule automatique sur l'écran de code OTP
  (`/auth/verification?mode=activate`, 15 min) ; une tentative de
  connexion sur un compte non activé redirige aussi vers cet écran.

### 3. « Mon palier » réparé (page + liste des paliers)
- **Cause** : le backend Django sérialise les Decimal en CHAÎNES
  (`'20.00'`, `'15000.00'`), mais la page faisait `as num` → TypeError à
  la construction des tuiles → page vide / paliers du bas absents.
- **Correctif** : parseur `_toNum()` sans cast dans
  `poster_my_subscription_screen.dart` (commission, retraits min/max,
  offres, mise en avant) + formatage propre (20.00 → 20). La carte du
  palier actif, la progression et TOUTES les tuiles « Tous les paliers »
  s'affichent désormais.

### 4. Plein écran vidéo corrigé (partie contenu des publications)
- **Cause 1 (bouton inerte)** : dans `short_video_player.dart`, le fond
  dégradé du titre était posé PAR-DESSUS le bouton plein écran dans le
  Stack → le tap tombait sur le titre (rien ne se passait) ou basculait
  les contrôles.
- **Cause 2 (vidéo en pause / rien)** : le plein écran recréait un SECOND
  lecteur vidéo (re-téléchargement, conflit audio, impression de pause).
- **Correctif** : bouton remonté au-dessus du titre + le controller EXISTANT
  est transmis au plein écran (`FullScreenVideoViewer(controller: …)`) —
  la lecture continue sans coupure ; mode paysage + barres système
  masquées, orientation restaurée à la sortie. S'applique à tous les
  lecteurs (contenu, couverture, dialog, détail).

### 5. Note correctifs — points « en cours » traités
- **Dr. Sissoko** : bouton profil de l'entête désormais cliquable (ouvre
  la page Profil) ; « Mes achats » (nouvel écran `my_purchases_screen.dart`
  à deux onglets : achats simples + abonnements = liste des éditeurs)
  accessible depuis l'entête ET le menu de la page profil ; activation par
  email OTP (ci-dessus) ; téléphone obligatoire (ci-dessus).
- **Lamana** : « filer la vidéo » — bouton de partage natif (share_plus)
  ajouté au lecteur vidéo (contrôles + plein écran) ; « plus de détails
  sur les publications » — date de publication, nombre de vues et note
  moyenne affichés dans le lecteur de contenu ; section achats + liste
  des éditeurs abonnés = l'écran « Mes achats » ci-dessus.
- **Beidy** : déjà en place (vérifié) — choix du moyen de paiement,
  en-tête réorganisé, plus de réponse à soi-même, retraits alignés sur
  les achats, traces de lancement serveur supprimées, suppression des
  notifications (individuelle + tout effacer).
- **Adama** (à suivre) : latence serveur — rien d'implémenté, à traiter
  plus tard (pas de demande bloquante).

### 6. Fichiers modifiés / créés (vague 8)
- Backend : `apps/accounts/{models,serializers,views,urls}.py`,
  `apps/accounts/migrations/0010_emailverificationcode_verify_existing_users.py`,
  `apps/accounts/test_email_verification.py` (7 tests),
  `deploy_vps_direct.sh` (CORS).
- Flutter : `screens/poster/poster_my_subscription_screen.dart`,
  `widgets/short_video_player.dart`, `screens/reader/reader_screen.dart`,
  `widgets/main_app_bar.dart`, `screens/profile/{profile_screen,
  my_purchases_screen.dart (nouveau)}.dart`, `screens/auth/{auth_login_screen,
  verification_screen}.dart`, `core/services/auth_service.dart`,
  `config/api_constants.dart`, `pubspec.yaml` (+ share_plus).

## MISE À JOUR 7 — En-têtes, retraits, CinetPay, médias, « gratuit » supprimé

### 1. En-tête des 4 pages principales (Accueil → Profil)
- `main_app_bar.dart` réécrit : logo + nom collés à gauche et mis en
  évidence, les 3 icônes (vue grille/liste, cloche, avatar) sur la même
  ligne mais collées à droite et plus petites.
- Accueil : en-tête agrandi (`enlarged`) + message de bienvenue sur la ligne
  suivante — « Bienvenue, {prénom} 👋 » à la toute première connexion,
  « Bon retour, {prénom} 👋 » ensuite (mémorisé par utilisateur dans le
  stockage local Hive). Le message n'apparaît que sur l'accueil.
- Onglets « Mes abonnés » (éditeur) et « Catégories » (admin) affichés dans
  les 4 onglets principaux : en-tête comme les autres pages principales
  (`embedded=true`). Sur leurs routes dédiées (/poster/subscribers,
  /admin/categories) l'en-tête actuel est conservé.
- Accueil : padding bas ajouté — on peut scroller jusqu'en bas et voir
  toutes les cartes complètement (la barre flottante ne masque plus rien).

### 2. Espace éditeur : « Mon niveau » réparé
- Le routeur redirigeait tout éditeur non approuvé vers /poster/verification
  pour TOUTE route /poster, y compris « Mon niveau » : la page ne s'ouvrait
  plus. Exemption pour /poster/my-subscription (page d'information) et
  chargement des paliers rendu indépendant du statut (plus jamais de page
  vide).

### 3. Retraits : le bouton est revenu + moyens sélectifs (éditeur ET admin)
- Comptabilité éditeur réécrite (design 2026) : cartes de solde/gains,
  bouton « Retirer des fonds », moyens de retrait affichés de façon
  SÉLECTIVE (Wave, Orange Money, Moov Money, carte bancaire, virement),
  saisie du numéro/compte puis du montant à recevoir, suivi des demandes
  avec statut, journal des écritures.
- Comptabilité admin réécrite : mêmes indicateurs modernisés + gestion des
  demandes des éditeurs (route /admin/withdrawals, badge « à traiter ») +
  demande de retrait propre de l'admin avec le même système que l'éditeur.
- Widget commun : `lib/widgets/withdrawal_request_sheet.dart`.

### 4. Conversation : plus de réponse à soi-même
- Le bouton « Répondre » n'apparaît plus sur ses propres messages (on peut
  toujours répondre aux autres et supprimer le sien).

### 5. Couvertures vidéo : lecture auto en silence, quelques secondes
- `short_video_player.dart` : l'auto-play des couvertures est désormais
  COUPÉ (volume 0) et s'arrête après 3 secondes — pas de musique, pas de
  boucle, lecture manuelle ensuite.

### 6. Médias : validation par type à la création/édition + zéro libellé
- Couverture : photo ≤ 5 Mo, vidéo ≤ 15 s / 50 Mo. Contenu : photo ≤ 15 Mo,
  vidéo ≤ 45 min / 50 Mo, PDF ≤ 50 pages / 30 Mo, texte ≤ 1 Mo — chaque
  dépassement affiche un message clair demandant de réduire/recadrer
  (`lib/core/utils/media_validation.dart`).
- Plus aucune mention « Image / Vidéo / PDF » dans la publication : seules
  les URL nues (`[]()`) sont insérées, le lecteur rend le média (plein
  écran image/vidéo conservé) sans texte parasite.

### 7. Paiement : Movapay → CinetPay (tous rôles, simulation → réel)
- Backend : nouveau service `apps/paiements/cinetpay.py` (initiation
  /v2/payment, vérification /v2/payment/check, webhook avec signature
  HMAC-SHA512 + re-vérification du statut réel). Config `.env` :
  CINETPAY_API_KEY / CINETPAY_SITE_ID / CINETPAY_SECRET — les endpoints
  sont identiques en test et en production ; sans clés réelles, tout
  fonctionne en simulation locale, et le passage en réel se fait en
  remplissant simplement le .env.
- Frontend : canaux CinetPay selon le moyen choisi (mobile_money → MOBILE,
  carte → CARD, portefeuille → wallet), libellés mis à jour.
- DROITS DE REVENTE SUPPRIMÉS partout (frontend + backend) : l'accès se
  fait uniquement par achat unitaire ou abonnement — toute requête
  `resell_right` est rejetée.

### 8. Divers
- Toutes les mentions « Gratuit / GRATUIT / sans frais / pages gratuites »
  supprimées de l'app (libellés neutres « À lire », « Accès libre », « 3
  pages d'aperçu », badge « ACTIF »…).
- Message « digital-press-api • ok • v1 » supprimé : rien n'est affiché
  quand le serveur répond, seul « Le serveur est indisponible » apparaît en
  cas de panne (test mis à jour).
- Notifications : suppression une par une (glisser) + tout effacer — déjà
  en place, vérifié.
- Temps réel : les pages comptabilité (éditeur/admin) se rechargent
  automatiquement à chaque événement WebSocket.

### 9. Fichiers principaux modifiés/créés
- Créés : `backend/apps/paiements/cinetpay.py`, `lib/core/utils/media_validation.dart`,
  `lib/widgets/withdrawal_request_sheet.dart`.
- Modifiés : `lib/widgets/main_app_bar.dart`, `lib/screens/home/home_screen.dart`,
  `lib/screens/profile/{profile_screen,editeur_comptabilite_screen}.dart`,
  `lib/screens/admin/{admin_comptabilite_screen,admin_categories_screen}.dart`,
  `lib/screens/poster/{poster_dashboard_screen,poster_my_subscription_screen,
  poster_subscribers_screen,poster_subscribe_screen,create_articles_screen,
  edit_article_screen,my_articles_screen}.dart`,
  `lib/screens/article/article_comments_screen.dart`,
  `lib/screens/reader/reader_screen.dart`, `lib/screens/payment/payment_screen.dart`,
  `lib/screens/auth/auth_login_screen.dart`, `lib/widgets/{short_video_player,
  payment_selection_sheet,subscribe_or_buy_sheet,feature_publication_sheet}.dart`,
  `lib/core/{api/api_client,router/app_router,services/{payment_service,
  publication_service}}.dart`, `lib/core/storage/storage_service.dart` (usage),
  `lib/model/publication.dart`, `lib/config/{app_config,api_constants}.dart`,
  `backend/apps/paiements/{views,serializers,tests}.py`, `backend/config/settings.py`,
  `backend/.env.example`, `backend/README.md`, `test/health_status_message_test.dart`.

---

## MISE À JOUR 6 — « L'app ne s'ouvre plus » sur le téléphone (corrigé)

### Cause identifiée
Sur Android, après un crash, le système (surtout TECNO/HiOS) marque l'app
« stopped » : le tap sur l'icône ne fait alors **rien du tout** — l'app est
bien dans la liste mais ne s'ouvre pas. Le déclencheur était un crash
silencieux au démarrage, déclenché après quelques utilisations :

1. Clé de chiffrement Hive manquante/corrompue (restauration auto-backup,
   invalidation du Keystore, mise à jour) → `base64Url.decode(encodedKey!)`
   plantait sur un null-assert → la boîte Hive n'était jamais ouverte.
2. `ThemeNotifier._load()` (et `PermissionPrimingService`) lisaient alors
   cette boîte jamais initialisée → `LateInitializationError` **non
   attrapée** → l'app mourait silencieusement en release juste après
   l'ouverture → Android la marquait « stopped ».

### Correctifs appliqués
- `StorageService` : clé régénérée si manquante/corrompue (plus de
  null-assert), boîte recréée si corrompue, boîte en mémoire en dernier
  recours — `init()` ne peut plus laisser la boîte non initialisée.
- `ThemeNotifier._load()` : try/catch, thème clair par défaut en cas
  d'échec — plus aucune erreur async non gérée au démarrage.
- `main.dart` : try/catch sur la déconnexion forcée et sur
  l'initialisation notifications/permissions.
- Journal de crash sur l'appareil : toute erreur fatale est écrite dans
  `/sdcard/Android/data/com.digitalpress.app/files/crash.log` (lisible
  via `adb pull ...` sans root) pour diagnostiquer toute récidive.
- `AndroidManifest.xml` : retrait de `android:taskAffinity=""` (retour
  au comportement standard du lanceur).
- Vérifié sur le téléphone : force-stop → `stopped=true` → lancement via
  l'intent LAUNCHER (équivalent tap icône) → app ouverte, aucun crash.

## MISE À JOUR 5 — Contenus, retraits supprimés, stats par rôle, paliers en cartes

### 1. Contenu des publications : plus jamais d'écran blanc
- Lecteur (`reader_screen.dart`) : un magazine/journal/rapport/e-book publié
  SANS fichier PDF (contenu rédigé, vidéo de couverture seule, publication
  incomplète) retombe désormais sur la vue "contenu" (texte + médias) au
  lieu d'afficher une page intérieure blanche.
- Couvertures : image ou vidéo toujours affichées (fond dégradé + icône du
  type si aucune couverture) ; vidéo de couverture en auto-play UNE seule
  fois (home, `autoPlayOnce`), puis lecture à la convenance de l'utilisateur.
- « À la une » : jusqu'à **12 publications** (back-end + carrousel home),
  tendances 48 h avec plancher de vues.

### 2. Espace « retrait éditeur » supprimé et remplacé
- Supprimé partout (dashboard admin, onglet home, comptabilités éditeur/
  admin) ; remplacé côté admin par la **Gestion des catégories**
  (`admin_categories_screen.dart`, route `/admin/categories`).
- Les revenus de mise en avant « À LA UNE » sont inclus dans la comptabilité
  (type_map recette, `featured_revenue`/`featured_count` du dashboard) et
  apparaissent dans les comptabilités éditeur et admin.

### 3. Remises à zéro & suppressions par les utilisateurs
- Notifications : suppression individuelle (bouton poubelle) + « tout
  effacer » (backend `DELETE /notifications/<pk>/` et
  `DELETE /notifications/delete-all/`).
- Publications (éditeurs uniquement) : suppression définitive + remise à
  zéro des vues/téléchargements/historique
  (`POST /publications/my/<pk>/reset-stats/`).

### 4. Admin : stats globales sur données réelles
- `admin_statistics_screen.dart` réécrit : il lit désormais
  `GET /api/admin/dashboard/stats/` (utilisateurs, éditeurs, lecteurs,
  revenus mois/total, commissions, mises en avant, abonnements actifs,
  soldes éditeurs) — fini les données de démo.

### 5. Profil adapté au rôle + paliers en cartes
- Stats du profil : Éditeur → Publiés/Vues/Abonnés ; Admin →
  Utilisateurs/Revenus/Transactions ; Lecteur → Achats/Lectures/Favoris
  (backend `get_stats` + modèle `UserStats` étendus).
- Admin : « Historique d'achats » remplacé par « Comptabilité générale »
  (l'admin n'achète rien).
- Palier éditeur : les 3 plans s'affichent en **cartes complètes** avec
  tous leurs avantages (commission, badge vérifié, mises en avant,
  export stats, fonctionnalités libres).
- Profil éditeur : @username et nom complet modifiables en plus du reste
  (avatar, couverture, bio, entreprise, site, adresse, SIRET).

### 6. Inscription des éditeurs
- Un éditeur s'inscrit lui-même (choix Lecteur/Éditeur à l'inscription,
  role='publisher' autorisé en public, jamais admin), puis est ramené sur
  la page de connexion pour poursuivre selon son type de compte (le
  processus initial de l'éditeur se continue ensuite à la connexion).

### 7. Production (VPS + web + APK)
- Backend redéployé sur le VPS (migrations, collectstatic, services
  redémarrés, santé 200).
- App web reconstruite et redéployée à la racine du domaine (racine 200,
  API 200, admin 200).
- APK release reconstruit et installé sur le téléphone TECNO.

### 8. Fichiers créés / modifiés (vague 5)
- Nouveaux : `lib/screens/admin/admin_statistics_screen.dart` (réécrit),
  `lib/screens/admin/admin_categories_screen.dart`.
- Modifiés : `backend/apps/accounts/serializers.py` (stats par rôle,
  inscription éditeur), `backend/apps/notifications/{views,urls}.py`,
  `backend/apps/publications/{views,urls}.py` (reset-stats, à la une ≤ 12),
  `backend/apps/comptabilite/{utils,views}.py` (revenus mises en avant),
  `lib/screens/reader/reader_screen.dart`, `lib/screens/home/home_screen.dart`,
  `lib/screens/poster/{my_articles_screen,poster_my_subscription_screen,
  poster_profile_screen}.dart`, `lib/screens/notifications/notifications_screen.dart`,
  `lib/screens/profile/{profile_screen,purchase_history_screen}.dart`,
  `lib/screens/admin/{admin_dashboard_screen,admin_comptabilite_screen}.dart`,
  `lib/screens/auth/auth_login_screen.dart`, `lib/model/user.dart`,
  `lib/core/services/{auth_service,app_notification_service,publication_service}.dart`,
  `lib/widgets/short_video_player.dart`, `lib/core/router/app_router.dart`.

## MISE À JOUR 4 — Stats de vues, modération À LA UNE, profil TikTok, prod

### 1. VPS de production vérifié et mis à jour
- Diagnostic : tous les services actifs (digitalpress/Daphne, Celery worker
  + beat, nginx, PostgreSQL 16, Redis), HTTPS Let's Encrypt OK
  (`https://www.digitalpress-ml.com/api/health/` → 200), `.env` déjà sur le
  domaine www.
- Backend déployé (migrations `accounts/0009_cover_image`,
  `paiements/0005`, `publications/0011` appliquées, services redémarrés),
  tâche Celery `expirer-mises-en-avant` enregistrée et active.
- **App Web Flutter déployée à la racine du domaine** :
  `https://www.digitalpress-ml.com/` sert désormais l'application (plus un
  simple JSON), `/api/`, `/admin/`, `/media/`, `/static/`, `/ws/` restent
  proxyés vers Django. Nouveau script `deploy_web_vps.py`.
- Nouveau script `deploy_vps_full.py` : synchronisation complète du backend
  (exclut `.env`, venv, media, logs) + migrations + redémarrage.
- APK release installé sur le téléphone (TECNO, `com.digitalpress.app`),
  pointant automatiquement vers le domaine de production.

### 2. Historique des vues + stats éditeur
- Backend : `GET /api/publications/my/views-history/?days=N` — série
  journalière (PublicationView) + série par publication.
- Éditeur : carte « Historique des vues » avec graphique en barres des N
  derniers jours et classement par publication dans
  `poster_statistics_screen.dart`.

### 3. Modération Admin des mises en avant « À LA UNE »
- Backend : `GET/POST /api/publications/admin/featured-promotions/`
  (liste + revenu actif + annulation).
- Admin : nouvel écran `admin_featured_screen.dart` (route `/admin/featured`,
  carte au dashboard) — annule une promotion et retire la publication de
  l'accueil.

### 4. Profil public éditeur façon TikTok (complété)
- Couverture/bannière modifiable : champ `PublisherProfile.cover_image`
  (upload d'image whitelistée), exposé dans les serializers public + profil
  éditeur.
- Éditeur : bouton appareil photo sur la bannière pour changer la couverture
  (le reste existait déjà : avatar, @username, stats Publiés/Vues/Abonnés,
  boutons, onglets grille + exclusif, compteur de vues sur les vignettes).

### 5. Fichiers créés / modifiés (vague 4)
- Nouveaux : `deploy_vps_full.py`, `deploy_web_vps.py`,
  `lib/screens/admin/admin_featured_screen.dart`,
  `backend/apps/accounts/migrations/0009_publisherprofile_cover_image.py`.
- Modifiés : `lib/screens/poster/poster_profile_screen.dart`,
  `lib/screens/poster/poster_statistics_screen.dart`,
  `lib/screens/admin/admin_dashboard_screen.dart`, `lib/core/router/app_router.dart`,
  `lib/core/services/auth_service.dart`, `lib/config/api_constants.dart`,
  `lib/core/services/publication_service.dart`,
  `backend/apps/accounts/{models,serializers}.py`,
  `backend/apps/publications/{views,urls,tasks}.py`,
  `backend/config/settings.py`, `MODIFICATIONS.md`.

### 6. À FAIRE restant côté hébergeur
- `digitalpress-ml.com` (sans www) reste intercepté par le proxy anti-DDoS
  de l'hébergeur (404 X-Anubis) : corriger la zone DNS/proxy chez
  l'hébergeur pour que le domaine nu atteigne le VPS (les blocs nginx de
  redirection nu → www sont déjà en place).


## MISE À JOUR 3 — Prod sur le domaine, médias propres, À LA UNE

### 1. Serveur « indisponible » sur le web + domaine en production partout
- **Diagnostic** : `https://www.digitalpress-ml.com/api/health/` répond 200
  (HTTPS Let's Encrypt OK). Le domaine NU `digitalpress-ml.com` (sans www)
  est intercepté par le proxy anti-DDoS de l'hébergeur (en-têtes X-Anubis)
  et renvoie 404 — il faut corriger la zone DNS/proxy chez l'hébergeur
  pour qu'il atteigne le VPS (le bloc nginx redirige déjà nu → www).
- `lib/config/app_config.dart` : `baseUrl` ne pointe plus vers l'IP brute
  `192.162.71.56` — toutes les plateformes (release, web, natives) utilisent
  `https://www.digitalpress-ml.com/api/`.
- `lib/config/api_config.dart` : `sanitizeUrl()` réécrit désormais les URLs
  médias en IP brute / domaine nu / localhost vers l'hôte de production.
- `deploy_vps_direct.sh` : `.env` de production avec `BACKEND_URL` et
  `FRONTEND_SUCCESS_URL` en `https://www.digitalpress-ml.com` (jamais le
  domaine nu), bloc nginx de redirection nu → www.

### 2. Médias (image / vidéo / PDF) — plus aucun nom de fichier + plein écran
- À l'import dans « Créer/Modifier un article », les fichiers sont insérés
  avec des libellés génériques (`Image`, `Vidéo`, `Document PDF`) — le nom
  brut (ex: `PDF DU 19 09 24_240919_081438.pdf`) n'apparaît plus nulle part.
- Couverture : « Image locale sélectionnée ✓ » au lieu du nom du fichier.
- Lecteur : `cleanMediaLabel()` remplace tout ancien libellé qui ressemble
  à un nom de fichier (extension présente) par un libellé propre.
- **Plein écran** pour les images (tap + bouton, zoom par pincement) et les
  vidéos (bouton d'agrandissement → lecture plein écran en mode paysage),
  exactement comme le plein écran PDF déjà existant.

### 3. Un seul champ de prix
- Le double champ « Prix individuel + Prix droit de revente » de l'éditeur
  est remplacé par UN SEUL champ de prix. Le prix de revente reste géré
  côté backend (préservé à l'édition, null à la création).

### 4. Types de publication adaptés (affichage + lecture)
- Badge du type (ARTICLE / MAGAZINE / JOURNAL / RAPPORT / E-BOOK) sur les
  cartes de l'accueil et dans le lecteur.
- Lecture adaptée : E-book en défilement continu vertical ; Magazine /
  Journal / Rapport en pages pleines horizontales ; Article en texte.

### 5. À LA UNE : mises en avant payantes + tendances (accueil)
- **Backend** : modèles `PublicationView` (vues dédupliquées, base des
  tendances) et `FeaturedPromotion` (mise en avant payante), type de
  transaction `featured`, endpoints :
  - `GET /api/publications/featured/` → `{featured, trending}` (tendances =
    fort nombre de vues sur 48 h, plancher 3 vues).
  - `POST /api/publications/<id>/feature/` → payer (7j = 5 000 FCFA,
    14j = 8 000, 30j = 12 000) par solde éditeur (wallet) ou mobile money.
  - `POST /api/publications/<id>/feature/verify/` → confirme le paiement.
  - Tâche Celery `expirer_mises_en_avant` (00:15 chaque nuit) : retire la
    mise en avant à expiration.
- **Frontend** : accueil = carrousel « À LA UNE » (endpoint dédié) + section
  « TENDANCES 🔥 ». Espace Éditeur : bouton étoile « Mettre à la une
  (payant) » sur chaque article publié → feuille de paiement avec durée et
  moyen de paiement, façon publicité Facebook.
- Migrations à appliquer : `publications/0011_*`, `paiements/0005_*`
  (déjà appliquées localement).

### 6. Fichiers créés / modifiés (vague 3)
- Nouveaux : `lib/widgets/feature_publication_sheet.dart`,
  `backend/apps/publications/tasks.py`, migrations 0011 (publications) et
  0005 (paiements).
- Modifiés : `lib/config/app_config.dart`, `lib/config/api_config.dart`,
  `lib/config/api_constants.dart`, `lib/core/services/publication_service.dart`,
  `lib/screens/home/home_screen.dart`, `lib/screens/reader/reader_screen.dart`,
  `lib/screens/poster/{create,edit}_articles_screen.dart`,
  `lib/screens/poster/my_articles_screen.dart`, `lib/widgets/short_video_player.dart`,
  `backend/apps/publications/{models,views,urls,admin,tests}.py`,
  `backend/apps/paiements/models.py`, `backend/config/settings.py`,
  `deploy_vps_direct.sh`, `lancement.md`.


## MISE À JOUR 2 — Conversation façon Facebook, favoris & playlists

### 1. Bouton "conversation" dans le lecteur d'article
Dans `lib/screens/reader/reader_screen.dart`, le bouton de téléchargement de
la barre d'app a été remplacé par un bouton "Voir la conversation" (icône
`forum`) qui ouvre directement `/article/<id>?scrollToComments=true`.

### 2. Conversation façon Facebook (avis + réponses en fil)
- **Nouveau modèle backend `Comment`** (`apps/publications/models.py`) :
  réponses libres, illimitées, avec `parent` pour répondre à n'importe quel
  message (fil de discussion imbriqué, comme des commentaires Facebook).
- Le modèle `Review` (avis noté par étoiles, un par utilisateur/article,
  modifiable) reste le **premier message** de chaque utilisateur dans la
  conversation : impossible de le contourner, l'app affiche une carte
  "Donnez votre avis" tant que l'utilisateur n'a pas encore noté l'article.
  Une fois cet avis posté, il peut discuter librement.
- **Endpoint unifié** `GET /api/publications/<id>/conversation-feed/` :
  renvoie tous les avis + tous les commentaires d'un article, fusionnés et
  triés chronologiquement, avec `type` (`review`/`comment`), `rating`
  (uniquement pour les avis), `parent_id` (pour les réponses) et `is_mine`.
- `POST /api/publications/<id>/comments/add/` — poster une réponse
  (`parent` optionnel).
- `DELETE /api/publications/comments/<id>/` — supprimer son propre message
  (ou n'importe lequel si Admin).
- Frontend : `lib/screens/article/article_comments_screen.dart` entièrement
  réécrit — carte "Votre avis" (étoiles, épinglée), puis le fil complet
  avec bouton "Répondre" sur chaque message (réponses indentées, jusqu'à 2
  niveaux visuellement), et "Supprimer" sur ses propres messages.

### 3. Favoris + playlists personnelles (Lecteur uniquement)
- **Nouveaux modèles** `ReaderCategory` (playlist personnelle) et
  `Favorite` (article favori, rangé dans 0, 1 ou plusieurs playlists via une
  relation many-to-many) — aucun rapport avec le modèle `Category` global.
- Endpoints : `GET/POST /api/publications/reader-categories/`,
  `DELETE /api/publications/reader-categories/<id>/`,
  `GET /api/publications/favorites/?category=<id>`,
  `POST /api/publications/favorites/add/` (ajoute/range un favori),
  `DELETE /api/publications/favorites/<publication_id>/`.
- Frontend :
  - Bouton favori (icône marque-page) sur la page article
    (`article_comments_screen.dart`), visible uniquement pour le Lecteur.
    Ouvre `lib/widgets/add_to_favorites_sheet.dart` : choisir une ou
    plusieurs playlists existantes, ou en créer une nouvelle à la volée.
  - La page "Catégories" du Lecteur (`categories_screen.dart`) a désormais
    deux onglets : **"Catégories"** (inchangé, catégories globales) et
    **"Mes Playlists"** (nouveau) — liste des playlists personnelles,
    création/suppression, et un tap ouvre
    `reader_playlist_detail_screen.dart` listant les articles qui y sont
    rangés (avec possibilité de les retirer de la playlist).
  - Rien de tout cela n'est visible pour Admin/Éditeur.

### 4. Page "Catégories" Admin/Éditeur : confirmation
Vous avez redemandé une page "qui n'a rien à voir avec ce qui est déjà
implémenté, surtout pas les catégories" pour Admin/Éditeur. La page
"Fonctionnalités à venir" mise en place précédemment correspond déjà à
cette contrainte (aucun rapport avec les catégories ni avec une
fonctionnalité existante) ; elle a donc été conservée telle quelle. Dites-
moi si vous préférez autre chose à la place.

### 5. Nouvelles migrations à appliquer
```bash
cd backend
python manage.py migrate
```
Ajoute, dans l'ordre : `0004_comment.py` puis
`0005_reader_categories_favorites.py` (en plus de `0003_conversations.py`
de la première mise à jour).

### 6. Nouveaux fichiers de cette mise à jour
- `backend/apps/publications/migrations/0004_comment.py`
- `backend/apps/publications/migrations/0005_reader_categories_favorites.py`
- `lib/model/conversation_message.dart`, `lib/model/reader_category.dart`,
  `lib/model/favorite_article.dart`
- `lib/core/services/favorites_service.dart`
- `lib/widgets/add_to_favorites_sheet.dart`
- `lib/screens/categories/reader_playlist_detail_screen.dart`
- `lib/screens/article/article_comments_screen.dart` (réécrit)
- `lib/screens/categories/categories_screen.dart` (réécrit, onglets ajoutés)

---

## Première mise à jour (voir sections ci-dessous, inchangées)



## 1. Page "Mes Conversations" (remplace "Favoris")

### Backend (Django — app `publications`)
- **Modèles** (`models.py`) :
  - `ConversationRead(user, publication, last_read_at)` — dernière lecture.
  - `HiddenConversation(user, publication, hidden_at)` — conversations quittées.
  - `Review.updated_at` (nouveau champ) : la date de dernier commentaire
    utilisée pour trier/badger la conversation est désormais `updated_at`
    (modifier son commentaire fait remonter la conversation, comme sur
    WhatsApp).
- **Endpoints** (préfixe `/api/publications/`) :
  - `GET  /conversations/` — liste "Mes Conversations" de l'utilisateur
    connecté (tous rôles), triée par dernier commentaire, avec recherche
    (`?search=...`).
  - `POST /conversations/<id>/read/` — marque comme lue (retire le badge).
  - `POST /conversations/<id>/hide/` — "quitte" la conversation (ne supprime
    pas les commentaires).
  - `POST /<id>/reviews/add/` — poster un commentaire (mis à jour à la
    ligne "Important" ci-dessous).

### ⚠️ Important — modèle de données des commentaires
Le projet utilise le modèle `Review` (avis/note + commentaire) comme unique
système de commentaire, avec une contrainte **un commentaire par
utilisateur et par article**. Il n'y avait donc pas de vrai "chat" multi-
messages dans le code existant. Pour répondre à votre demande sans
réinventer tout le système de commentaires :
- Chaque utilisateur a **un seul message par article**, modifiable à tout
  moment (poster un nouveau commentaire sur un article déjà commenté par
  vous **met à jour** votre message existant au lieu de créer un doublon).
- La "conversation" affichée est la liste de tous les commentaires de tous
  les utilisateurs sur cet article — ordre chronologique, comme un fil de
  discussion.

Si vous voulez un vrai historique multi-messages par utilisateur (plusieurs
messages successifs par la même personne), il faudra créer un modèle
`Comment` séparé (article, auteur, texte, date) sans contrainte d'unicité —
dites-le moi et je l'ajoute.

### Frontend (Flutter)
- **Écran** : `lib/screens/conversations/conversations_screen.dart` (remplace
  `bookmarks_screen.dart`, supprimé) — liste façon WhatsApp/Telegram :
  avatar = initiale du titre, badge rouge "nouveaux commentaires", swipe ou
  appui long pour "quitter la conversation", barre de recherche.
- **Nouvel écran article + commentaires** :
  `lib/screens/article/article_comments_screen.dart` (route `/article/:id`).
  C'est la page qui n'existait pas dans l'app d'origine (il n'y avait aucune
  UI pour lire/poster un commentaire !). Elle affiche l'article, un bouton
  "Lire l'article" (réutilise votre flux d'abonnement existant), puis la
  section Commentaires. Quand on y arrive depuis "Mes Conversations"
  (`?scrollToComments=true`), la page s'ouvre **directement scrollée** sur
  les commentaires.
- Modèle `lib/model/conversation.dart`, service
  `lib/core/services/conversation_service.dart`.
- La page "Favoris" et son modèle (`bookmark.dart`) ont été supprimés (ils
  étaient d'ailleurs déjà en données statiques/mockées, non connectés à un
  vrai backend).

## 2. Page "Catégories" remplacée pour Admin/Éditeur

- Nouvelle app Django **`apps.roadmap`** : modèle `FeatureItem` (titre,
  description, portée `admin`/`publisher`/`both`, statut `à venir` / `en
  cours` / `réalisé` / `non retenu`).
  - `GET/POST /api/roadmap/` — lister/proposer une fonctionnalité (Admin et
    Éditeur uniquement).
  - `PATCH /api/roadmap/<id>/status/` — changer le statut (Admin).
  - `DELETE /api/roadmap/<id>/` — supprimer (Admin).
- Écran `lib/screens/roadmap/feature_roadmap_screen.dart` : liste des
  fonctionnalités à venir, bouton "Proposer", et pour l'Admin un menu pour
  changer le statut / supprimer.
- Dans la barre de navigation basse (`home_screen.dart`), l'onglet
  "Catégories" devient **"À venir"** pour Admin et Éditeur uniquement — le
  Lecteur garde exactement sa page "Catégories" d'origine, inchangée.
- Le dashboard Admin (`/admin/manage-categories`) est remplacé par
  `/admin/feature-roadmap`. Une carte équivalente a été ajoutée au dashboard
  Éditeur (`/poster/feature-roadmap`), qui n'avait auparavant aucun accès à
  la gestion des catégories.
- `manage_categories_screen.dart` (CRUD catégories admin) a été supprimé.

## 3. Catégorie en texte libre pour l'Éditeur

- Backend : `PublicationCreateSerializer` accepte désormais un champ
  `category_name` (texte). S'il est fourni, la catégorie correspondante est
  **récupérée si elle existe déjà (insensible à la casse) ou créée à la
  volée**. L'ancien champ `category` (id) reste accepté pour compatibilité,
  mais n'est plus utilisé par l'app Flutter.
- Frontend : dans "Créer un article" et "Modifier un article", le menu
  déroulant de catégories est remplacé par un champ texte avec
  auto-complétion (suggestions des catégories existantes en tapant, mais
  vous pouvez taper un nom totalement nouveau).
- La page "Catégories" du Lecteur est inchangée : toute nouvelle catégorie
  créée par un éditeur y apparaît automatiquement (comme n'importe quelle
  catégorie), avec les articles qui lui sont assignés.

  > Note sur la phrase "chaque catégorie que l'éditeur va créer sera là pour
  > y mettre les articles qu'il aura mis en favori" : comme la page Favoris
  > est supprimée, j'ai interprété cette partie comme le fonctionnement
  > normal catégorie → articles (un article assigné à une catégorie via son
  > champ catégorie apparaît dans cette catégorie côté Lecteur). Si vous
  > pensiez à autre chose (ex: une liste d'articles "mis en avant" par
  > catégorie et par éditeur), dites-le moi et j'ajusterai.

## 4. Migrations à exécuter

Après avoir installé les dépendances backend (`pip install -r
requirements.txt` dans `backend/`), lancez :

```bash
cd backend
python manage.py migrate
```

Cela appliquera :
- `publications/migrations/0003_conversations.py` (nouveaux champs/tables)
- `roadmap/migrations/0001_initial.py` (nouvelle app)

## 5. Fichiers supprimés
- `lib/screens/bookmarks/bookmarks_screen.dart`
- `lib/model/bookmark.dart`
- `lib/screens/admin/manage_categories_screen.dart`

## 6. Fichiers créés
- `backend/apps/roadmap/` (app complète)
- `backend/apps/publications/migrations/0003_conversations.py`
- `lib/model/conversation.dart`, `lib/model/feature_item.dart`
- `lib/core/services/conversation_service.dart`,
  `lib/core/services/roadmap_service.dart`
- `lib/screens/conversations/conversations_screen.dart`
- `lib/screens/roadmap/feature_roadmap_screen.dart`
- `lib/screens/article/article_comments_screen.dart`
