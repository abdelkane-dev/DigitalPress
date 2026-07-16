# Modifications apportées — Digital Press

> Ce fichier a été mis à jour à deux reprises. La section "MISE À JOUR 2"
> décrit les derniers ajouts (conversation façon Facebook, bouton
> conversation dans le lecteur, favoris/playlists du Lecteur). Le reste du
> document (sections 1 à 6) décrit la première vague de modifications
> (Mes Conversations, Fonctionnalités à venir, catégorie en texte libre).

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
