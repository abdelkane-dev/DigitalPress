# Paiements — intégration Orange Money (backend)

Ceci décrit les endpoints backend fournis et comment tester le flux Mobile Money (Orange Money) localement.

## Endpoints

- `POST /payments/checkout/` — initialise un `Payment` côté serveur.
  - Body JSON attendu: `{ "amount": 1000, "payment_method": "mobile_money", "subscription_type": "monthly" }`
  - Comportement:
    - crée un enregistrement `Payment` en `pending`.
    - si `ORANGE_BASE_URL` et `ORANGE_API_KEY` sont configurés, appelle l'API Orange pour initier la demande et renvoie `provider_ref`.
    - sinon renvoie un message indiquant que le paiement est en attente.

- `POST /payments/webhook/` — endpoint public pour recevoir les callbacks de Orange.
  - Le webhook attend un payload contenant au minimum `clientReference` (notre `payment.id`) et `status`.
  - Si `ORANGE_WEBHOOK_SECRET` est fourni, le serveur vérifie une signature simple via l'en-tête `X-Signature`.
  - En cas de statut réussi (ex: `SUCCESSFUL`, `PAID`, `COMPLETED`), le backend met à jour `Payment.status='success'` et crée l'abonnement si la payload contient `subscription_type`.

## Variables d'environnement

- `ORANGE_BASE_URL` — URL de l'API Orange (ex: `https://api.orange.com`)
- `ORANGE_API_KEY` — token/clé utilisé pour l'appel d'API (Bearer)
- `ORANGE_API_SECRET` — (optionnel) secret si nécessaire pour OAuth
- `ORANGE_WEBHOOK_SECRET` — secret partagé pour vérifier les callbacks (optionnel)
- `ORANGE_CURRENCY` — devise (par défaut `XOF`)

Configurer ces valeurs en production/staging via votre gestionnaire de secrets (env vars, Vault, etc.).

## Exemple d'appel `checkout` (curl)

```
curl -X POST http://localhost:8000/payments/checkout/ \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"amount":1000, "payment_method":"mobile_money", "subscription_type":"monthly"}'
```

Réponse attendue (provider configuré):

```
{
  "payment_id": 123,
  "provider_ref": "REQ-abc123",
  "provider_response": { ... }
}
```

Réponse attendue (fallback):

```
{
  "payment_id": 123,
  "message": "Payment created in pending state. Configure ORANGE_BASE_URL and ORANGE_API_KEY to initiate provider flow."
}
```

## Exemple de webhook simulé (curl)

Simuler un callback Orange localement — remplacez `<payment_id>` par l'id renvoyé précédemment.

```
curl -X POST http://localhost:8000/payments/webhook/ \
  -H "Content-Type: application/json" \
  -H "X-Signature: <ORANGE_WEBHOOK_SECRET>" \
  -d '{"clientReference":"<payment_id>", "status":"SUCCESSFUL", "transactionId":"tx-001"}'
```

Le backend doit répondre `{"status":"ok"}` et vous devriez voir `Payment.status` passer à `success`.

## Tests locaux recommandés

- Installer dépendances: `pip install -r requirements.txt` (assurez-vous que `requests` est installé).
- Démarrer le serveur: `python manage.py runserver`.
- Appeler `checkout` puis simuler le `webhook` comme ci‑dessus.

## Notes et limites

- Le code dans `apps/payments/views.py` implémente un flux générique. Orange Money a plusieurs variantes (OAuth token, signature HMAC, callbacks paginés). Adaptez l'authentification et les endpoints selon la doc Orange spécifique au Mali.
- En production, utilisez HTTPS, vérification de signature robuste, et stockez les secrets hors du repository.
- Pour un flux plus complet, il est recommandé d'implémenter la rotation des tokens, la gestion des erreurs asynchrones et la réconciliation quotidienne des transactions.

---

Fichier source: `apps/payments/views.py`
