Checklist de déploiement en production
1. Environnement & Secrets
Fichiers locaux : Crée ton fichier .env . Remplis-le avec tes valeurs réelles.

Sécurisation : Ne stocke jamais tes secrets dans le code source. Utilise les variables d'environnement de ton CI/CD ou un gestionnaire de secrets dédié (GitHub Secrets, Vault).

Astuce de pro : Vérifie bien que ton .env est dans ton fichier .gitignore pour éviter de le pousser sur GitHub par erreur !

2. GitHub
Dépôt : Utilise un dépôt privé et pousse ton code.

Secrets : Configure dans les paramètres de ton repo les secrets nécessaires (SECRET_KEY, identifiants de BDD, ORANGE_API_KEY, ORANGE_WEBHOOK_SECRET, etc.).



4. Déploiement
Serveur : Utilise un serveur ASGI (Gunicorn avec workers Uvicorn) placé derrière un proxy inverse comme Nginx.

Service : Configure systemd pour que ton application se relance automatiquement en cas de crash ou de redémarrage du serveur.

Assets : Assure-toi que tes fichiers statiques et médias sont servis correctement (idéalement via un CDN ou un stockage objet comme S3).

Routine : Automatise les commandes lors du déploiement :

python manage.py migrate (pour mettre à jour le schéma BDD).

python manage.py collectstatic --noinput (pour regrouper les fichiers statiques).

5. Sécurité (Crucial !)
Mode Prod : Passe DEBUG à False dans tes settings.

Accès : Configure ALLOWED_HOSTS avec ton nom de domaine exact.

Transport : Active le HTTPS et renforce les cookies avec SESSION_COOKIE_SECURE=True.

Maintenance : Prends l'habitude de renouveler (rotation) tes clés d'API et secrets de webhooks périodiquement.

6. Monitoring
Visibilité : Configure les logs. Si tu peux, ajoute Sentry pour être alerté en temps réel en cas d'erreur.

Sécurité des données : Mets en place une stratégie de sauvegarde automatique de ta base de données.