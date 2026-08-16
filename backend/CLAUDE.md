# DigitalPress Backend — Repères pour Claude

Voir aussi le `CLAUDE.md` racine pour la vue d'ensemble produit.

## Apps et responsabilités
- `accounts` : User, PublisherProfile, PublisherVerification (légitimité,
  n'a plus de rôle bloquant sur l'accès plateforme), permissions par rôle.
- `abonnements` : `Plan`/`Abonnement` = Lecteur→Éditeur (payant, réel).
  `PlatformPlan`/`PublisherSubscription` = palier Éditeur↔Plateforme
  (gratuit, automatique — voir `services.py`).
- `paiements` : Transactions Movapay (achats, abonnements lecteur,
  retraits). Le type `platform_subscription` est désormais mort côté
  paiement (bloqué explicitement) mais conservé en base pour l'historique.
- `comptabilite` : écritures comptables double entrée, réconciliation,
  export CSV. `enregistrer_ecriture()` déclenche aussi la réévaluation du
  palier éditeur sur chaque vente.
- `notifications` : FCM + WebSockets (`/ws/notifications/`).

## Points de vigilance connus
- `enregistrer_ecriture()` (`comptabilite/utils.py`) crée 2 écritures par
  transaction commissionnée — ne jamais remettre `transaction` en
  `OneToOneField` sur `EcritureComptable` (contrainte déjà corrigée par le
  passé, voir commentaire dans `comptabilite/models.py`).
- `sync_publisher_tier()` ne rétrograde jamais un palier déjà atteint — à
  respecter dans tout futur changement de logique de palier.
- Aucun endpoint ne doit accepter de paiement pour le palier plateforme
  (`publisher_subscription_id` est explicitement rejeté dans
  `paiements/views.py`).

## Déploiement VPS (sans Docker)
Systemd + Daphne (ASGI) + Nginx + PostgreSQL + Redis, tous installés
nativement sur Ubuntu 24.04. Voir `lancement.md` et `deploy_vps_direct.sh`
à la racine du projet pour la procédure complète.
