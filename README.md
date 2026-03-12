Zbackend
C’est le backend (partie serveur) de l’application Z, construit avec Django et Django REST Framework (DRF).
Il est déjà préparé pour fonctionner en production et gérer les paiements via Orange Money.

Démarrage rapide (mode développement)
Crée un environnement virtuel (virtualenv) et active-le.

Copie le fichier .env.example en .env et remplis les valeurs nécessaires pour ton environnement de développement.

Installe les dépendances avec :

bash
pip install -r requirements.txt
Lance les migrations (pour créer la base de données) et démarre le serveur :

bash
'''
python manage.py migrate
python manage.py runserver
'''
👉 Après ça, ton serveur est prêt et tu peux commencer à tester l’application.

Mode production
Quand tu voudras mettre en ligne ton projet, regarde le fichier docs/PRODUCTION.md qui contient une checklist pour le déploiement.

Pour les développeurs Flutter — Paiements
D’abord, récupère un JWT en envoyant une requête POST /api/auth/login/.
➝ Ensuite, ajoute Authorization: Bearer <token> dans tes requêtes.

Pour lancer un paiement : fais un POST /api/payments/checkout/ avec un objet comme :
{ amount, payment_method: 'mobile_money', subscription_type }

Après le parcours du fournisseur (Orange Money), vérifie le statut final avec :
GET /api/payments/<id>/status/

⚠️ Ne garde jamais les secrets du fournisseur (Orange Money) dans ton application mobile.

Configuration (Environnement)
Tout se règle avec des variables d’environnement.

En local : utilise ton fichier .env.

En production : utilise un gestionnaire de secrets (par exemple, celui fourni par ton hébergeur).