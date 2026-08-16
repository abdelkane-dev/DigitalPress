from rest_framework import generics, permissions, status
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from django.utils import timezone
from django.conf import settings
from django.db import transaction as db_transaction
from .models import Transaction, DemandeRetrait
from .serializers import (
    TransactionSerializer, InitierPaiementSerializer,
    VerifierPaiementSerializer, DemandeRetraitSerializer,
    DemandeRetraitCreateSerializer, AdminTraiterRetraitSerializer,
)
from .cinetpay import cinetpay_service, verify_webhook_signature
from apps.accounts.permissions import IsAdmin, IsPublisher, IsAdminOrPublisher
from apps.accounts.models import PublisherProfile, User
from apps.comptabilite.utils import enregistrer_ecriture
from apps.notifications.models import Notification
import uuid
import logging

logger = logging.getLogger(__name__)


def _create_payment_notifications(tx):
    """Crée les notifications après un paiement réussi."""
    try:
        montant = int(tx.montant_brut)
        if tx.type_transaction == 'recharge':
            Notification.objects.create(
                user=tx.payer,
                type_notif='payment_success',
                title='Portefeuille rechargé',
                message=f'Votre portefeuille a été rechargé de {montant} FCFA avec succès.',
                data={'transaction_id': str(tx.id), 'reference': tx.reference},
            )
        elif tx.type_transaction == 'purchase':
            pub_title = tx.publication.title if tx.publication else 'Article'
            Notification.objects.create(
                user=tx.payer,
                type_notif='payment_success',
                title='Achat confirmé',
                message=f'Votre achat de « {pub_title} » ({montant} FCFA) a été confirmé.',
                data={'transaction_id': str(tx.id), 'publication_id': tx.publication_id},
            )
            # Notifier l'éditeur
            if tx.beneficiaire:
                Notification.objects.create(
                    user=tx.beneficiaire,
                    type_notif='payment_success',
                    title='Nouveau revenu reçu',
                    message=f'Vous avez reçu {int(tx.montant_net)} FCFA pour la vente de « {pub_title} ».',
                    data={'transaction_id': str(tx.id)},
                )
        elif tx.type_transaction == 'subscription':
            Notification.objects.create(
                user=tx.payer,
                type_notif='subscription_activated',
                title='Abonnement activé',
                message=f'Votre abonnement a été activé avec succès ({montant} FCFA).',
                data={'transaction_id': str(tx.id)},
            )
    except Exception as e:
        logger.error("Erreur création notification paiement: %s", str(e))

class InitierPaiementView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        logger.warning(
            "InitierPaiement request user=%s data=%s",
            request.user,
            request.data,
        )
        serializer = InitierPaiementSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Déterminer le bénéficiaire
        beneficiaire = None
        publication = None
        abonnement = None

        if data.get('publication_id'):
            from apps.publications.models import Publication
            try:
                publication = Publication.objects.get(pk=data['publication_id'])
                beneficiaire = publication.publisher
            except Publication.DoesNotExist:
                logger.warning(
                    "InitierPaiement publication introuvable user=%s data=%s",
                    request.user,
                    request.data,
                )
                return Response({'error': 'Publication introuvable.'}, status=404)

        if data.get('abonnement_id'):
            from apps.abonnements.models import Abonnement
            try:
                abonnement = Abonnement.objects.get(pk=data['abonnement_id'], reader=request.user)
            except Abonnement.DoesNotExist:
                logger.warning(
                    "InitierPaiement abonnement introuvable user=%s data=%s",
                    request.user,
                    request.data,
                )
                return Response({'error': 'Abonnement introuvable.'}, status=404)
            if abonnement.status == 'active':
                logger.warning(
                    "InitierPaiement abonnement deja actif user=%s data=%s",
                    request.user,
                    request.data,
                )
                return Response({'error': 'Cet abonnement est déjà actif.'}, status=400)
            beneficiaire = abonnement.publisher

        publisher_subscription = None
        if data.get('publisher_subscription_id'):
            # Le palier plateforme est désormais automatique et gratuit
            # (voir apps.abonnements.services) : aucun paiement n'est plus
            # possible pour ce type de transaction.
            return Response(
                {'error': "Le palier plateforme est automatique et gratuit, aucun paiement n'est requis."},
                status=400,
            )

        from decimal import Decimal
        type_tx = data.get('type_transaction', 'purchase')
        mode_paiement = data.get('mode_paiement', 'cinetpay')

        # ─── MODE SIMULATION ─────────────────────────────────────────────
        # Si 'simulation' est explicitement spécifié (tests/dev), on utilise
        # le mock local. Sinon, CinetPay bascule automatiquement en mode
        # simulation dès qu'aucune clé réelle n'est configurée dans le .env
        # (voir cinetpay.is_sandbox_mode) : tout le parcours de paiement
        # fonctionne en dev, et le passage en production se fait en
        # remplissant CINETPAY_API_KEY / CINETPAY_SITE_ID / CINETPAY_SECRET.
        is_explicit_simulation = (mode_paiement == 'simulation')

        # ─── CANAUX CINETPAY SELON LE MOYEN CHOISI ──────────────────────
        # L'app choisit un moyen (Wave, Orange Money, Moov Money, carte...)
        # → CinetPay n'ouvre que les canaux pertinents :
        #   'mobile_money' -> MOBILE   (Wave/OM/Moov/Sama)
        #   'card'         -> CARD     (Visa, Mastercard, AMEX)
        #   autre / 'all'  -> ALL      (tous les moyens disponibles)
        if mode_paiement == 'mobile_money':
            cinetpay_channels = 'MOBILE'
        elif mode_paiement == 'card':
            cinetpay_channels = 'CARD'
        else:
            cinetpay_channels = 'ALL'

        # ─── SÉCURITÉ CRITIQUE : LE MONTANT N'EST JAMAIS FOURNI PAR LE CLIENT ──
        # Conformément au principe « Aucune confiance accordée au frontend » :
        # auparavant, `montant` provenait directement du corps de la requête,
        # ce qui permettait à n'importe quel utilisateur de payer un article à
        # 1 FCFA au lieu de son prix réel en modifiant simplement la requête.
        # Le montant est désormais TOUJOURS recalculé côté serveur à partir du
        # prix réel enregistré en base — sauf pour une recharge de portefeuille,
        # où l'utilisateur crédite son propre compte avec son propre argent.
        if type_tx == 'recharge':
            try:
                montant = Decimal(str(data.get('montant', '')))
            except Exception:
                logger.warning(
                    "InitierPaiement montant invalide user=%s data=%s",
                    request.user,
                    request.data,
                )
                return Response({'error': 'Montant invalide.'}, status=400)
            if montant <= 0 or montant > Decimal('1000000'):
                logger.warning(
                    "InitierPaiement montant recharge invalide user=%s data=%s montant=%s",
                    request.user,
                    request.data,
                    montant,
                )
                return Response({'error': 'Montant de recharge invalide.'}, status=400)
        elif publication is not None:
            # ─── DROITS DE REVENTE SUPPRIMÉS DE LA PLATEFORME ─────────────
            # Demande explicite : « soit tu achètes, soit tu t'abonnes, point. »
            # Aucun paiement de type resell_right n'est plus accepté, même si
            # un ancien client tente d'appeler l'API directement.
            if type_tx == 'resell_right':
                return Response(
                    {'error': "L'achat de droits de revente a été supprimé de la plateforme."},
                    status=400,
                )
            if publication.is_free or publication.prix == 0:
                logger.warning(
                    "InitierPaiement publication gratuite user=%s data=%s publication=%s",
                    request.user,
                    request.data,
                    publication.id,
                )
                return Response({'error': 'Cette publication est gratuite, aucun paiement requis.'}, status=400)
            montant = publication.prix
        elif abonnement is not None:
            montant = abonnement.montant
        elif publisher_subscription is not None:
            montant = publisher_subscription.montant
        else:
            logger.warning(
                "InitierPaiement montant indetermine user=%s data=%s",
                request.user,
                request.data,
            )
            return Response(
                {'error': "Impossible de déterminer le montant : precisez publication_id, abonnement_id ou publisher_subscription_id."},
                status=400,
            )

        # Récupérer le taux de commission du profil de l'éditeur ou 10% par défaut
        rate = Decimal('10.00')
        if type_tx == 'platform_subscription':
            # 100% pour la plateforme, aucun profil éditeur n'est crédité.
            rate = Decimal('100.00')
        elif beneficiaire and beneficiaire.role == 'publisher':
            profile, _ = PublisherProfile.objects.get_or_create(
                user=beneficiaire,
                defaults={'company_name': beneficiaire.name or beneficiaire.username}
            )
            rate = profile.commission_rate
            # ─── AVANTAGE RÉEL DU PLAN : COMMISSION RÉDUITE ────────────────
            # Le plan plateforme actif de l'éditeur (Basique/Standard/
            # Premium) fixe le taux réellement appliqué — un vrai avantage
            # financier différent par plan, pas juste un texte affiché.
            active_sub = beneficiaire.platform_subscriptions.filter(
                status='active'
            ).select_related('plan').first()
            if active_sub and active_sub.plan:
                rate = active_sub.plan.commission_rate
            
        commission = round(montant * (rate / Decimal('100.00')), 2)
        montant_net = round(montant - commission, 2)
        reference = str(uuid.uuid4())

        if mode_paiement == 'wallet':
            if type_tx == 'recharge' and mode_paiement == 'wallet':
                return Response({'error': 'Impossible de recharger un portefeuille avec le portefeuille.'}, status=400)
            
            user = request.user
            if mode_paiement == 'wallet' and user.solde < montant:
                logger.warning(
                    "InitierPaiement solde insuffisant user=%s data=%s solde=%s montant=%s",
                    request.user,
                    request.data,
                    user.solde,
                    montant,
                )
                return Response({'error': 'Solde insuffisant dans votre portefeuille.'}, status=400)
            
            with db_transaction.atomic():
                # ─── SÉCURITÉ FINANCIÈRE ──────────────────────────────────
                # Reverrouille et re-vérifie le solde DANS la transaction
                # atomique, juste avant le débit : la vérification faite
                # plus haut (avant d'entrer ici) n'empêchait pas un
                # double-clic ou une requête réseau rejouée de passer deux
                # fois la même vérification avant que l'une des deux
                # n'écrive le nouveau solde — d'où un double débit possible
                # sur un simple achat, potentiellement jusqu'à un solde
                # négatif.
                if mode_paiement == 'wallet':
                    user = User.objects.select_for_update().get(pk=user.pk)
                    if user.solde < montant:
                        return Response(
                            {'error': 'Solde insuffisant dans votre portefeuille.'}, status=400
                        )
                    user.solde -= montant
                    user.save(update_fields=['solde'])
                
                # Créditer l'éditeur
                if beneficiaire and beneficiaire.role == 'publisher':
                    profile, _ = PublisherProfile.objects.select_for_update().get_or_create(
                        user=beneficiaire,
                        defaults={'company_name': beneficiaire.name or beneficiaire.username}
                    )
                    profile.solde += montant_net
                    profile.total_earned += montant_net
                    profile.save(update_fields=['solde', 'total_earned'])
                
                # Créer directement la transaction au statut 'success'
                tx = Transaction.objects.create(
                    reference=reference,
                    payer=user,
                    beneficiaire=beneficiaire,
                    publication=publication,
                    abonnement=abonnement,
                    publisher_subscription=publisher_subscription,
                    type_transaction=type_tx,
                    montant_brut=montant,
                    commission=commission,
                    montant_net=montant_net,
                    phone_payer='',
                    status='success',
                    processed_at=timezone.now(),
                    description=data.get('description', f'Achat via {mode_paiement} pour {publication.title if publication else "Abonnement"}'),
                    metadata={'mode_paiement': mode_paiement}
                )
                
                # Activer l'abonnement si type_transaction == 'subscription'
                if type_tx == 'subscription' and abonnement:
                    abonnement.activate(tx.reference)

                if type_tx == 'platform_subscription' and publisher_subscription:
                    publisher_subscription.activate(tx.reference)

                # Enregistrer l'écriture comptable
                try:
                    with db_transaction.atomic():
                        enregistrer_ecriture(tx)
                except Exception as e:
                    # Isolé dans son propre savepoint : une erreur ici ne doit
                    # jamais annuler la validation du paiement lui-même (voir
                    # la note dans EcritureComptable sur l'ancien bug OneToOne).
                    logger.error("Erreur écriture comptable: %s", str(e))

                # Créer notifications
                _create_payment_notifications(tx)
                
            return Response({
                'transaction': TransactionSerializer(tx).data,
                'message': 'Paiement effectué avec succès via votre portefeuille.',
            }, status=status.HTTP_201_CREATED)

        # Appel passerelle CinetPay ou simulation mock
        if is_explicit_simulation:
            cinetpay_result = cinetpay_service._mock_initier(
                reference=reference,
                montant=float(montant),
                phone=data.get('phone', ''),
            )
        else:
            cinetpay_result = cinetpay_service.initier_paiement(
                montant=float(montant),
                reference=reference,
                description=data.get('description', ''),
                phone=data.get('phone', ''),
                email=getattr(request.user, 'email', '') or '',
                customer_name=getattr(request.user, 'name', '') or getattr(request.user, 'username', '') or '',
                channels=cinetpay_channels,
            )

        # Créer la transaction en attente
        tx = Transaction.objects.create(
            reference=reference,
            payer=request.user,
            beneficiaire=beneficiaire,
            publication=publication,
            abonnement=abonnement,
            publisher_subscription=publisher_subscription,
            type_transaction=type_tx,
            montant_brut=montant,
            commission=commission,
            montant_net=montant_net,
            phone_payer=data.get('phone', ''),
            status='pending',
            description=data.get('description', ''),
            metadata=cinetpay_result,
        )

        return Response({
            'transaction': TransactionSerializer(tx).data,
            'payment_url': cinetpay_result.get('payment_url', ''),
            'movapay_ref': cinetpay_result.get('cinetpay_ref', ''),
            'message': cinetpay_result.get('message', ''),
        }, status=status.HTTP_201_CREATED)


class VerifierPaiementView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = VerifierPaiementSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            tx = Transaction.objects.get(reference=data['reference'])
        except Transaction.DoesNotExist:
            return Response({'error': 'Transaction introuvable.'}, status=404)

        if tx.payer_id != request.user.id and request.user.role != 'admin':
            return Response({'error': 'Accès refusé à cette transaction.'}, status=403)

        # Si la transaction est déjà à un statut final, ou si elle a été réglée
        # via le portefeuille interne (pas de référence passerelle), on renvoie
        # directement le résultat sans interroger la passerelle externe.
        is_wallet = isinstance(tx.metadata, dict) and tx.metadata.get('mode_paiement') == 'wallet'
        is_final = tx.status in ('success', 'failed', 'cancelled', 'refunded')
        if is_final or is_wallet:
            return Response({
                'transaction': TransactionSerializer(tx).data,
                'movapay_status': tx.status,
                'message': 'Transaction déjà traitée.',
            })

        # Vérifier auprès de CinetPay (statut réel, pas les données client)
        result = cinetpay_service.verifier_paiement(reference=data['reference'])
        result.setdefault('movapay_ref', result.get('cinetpay_ref', ''))

        if result.get('status') == 'success' and tx.status == 'pending':
            with db_transaction.atomic():
                # ─── SÉCURITÉ FINANCIÈRE ──────────────────────────────────
                # Reverrouille la transaction sous select_for_update() dans
                # la section critique : sans ça, deux vérifications
                # concurrentes (ex: le webhook Movapay ET cet appel manuel
                # de vérification arrivant en même temps) pouvaient toutes
                # les deux lire status='pending' avant que l'une n'écrive
                # 'success', et donc créditer le portefeuille DEUX FOIS
                # pour un seul paiement réel.
                tx = Transaction.objects.select_for_update().get(pk=tx.pk)
                if tx.status != 'pending':
                    return Response({
                        'transaction': TransactionSerializer(tx).data,
                        'movapay_status': tx.status,
                        'message': 'Transaction déjà traitée.',
                    })
                tx.status = 'success'
                tx.movapay_ref = result.get('movapay_ref', tx.movapay_ref)
                tx.processed_at = timezone.now()
                tx.save()

                if tx.type_transaction == 'recharge':
                    # Créditer le solde portefeuille du client
                    payer = User.objects.select_for_update().get(pk=tx.payer_id)
                    payer.solde += tx.montant_brut
                    payer.save(update_fields=['solde'])
                else:
                    # Créditer le solde de l'éditeur
                    if tx.beneficiaire and tx.beneficiaire.role == 'publisher':
                        profile, _ = PublisherProfile.objects.get_or_create(
                            user=tx.beneficiaire,
                            defaults={'company_name': tx.beneficiaire.name}
                        )
                        profile.solde += tx.montant_net
                        profile.total_earned += tx.montant_net
                        profile.save(update_fields=['solde', 'total_earned'])

                # Activer l'abonnement si type_transaction == 'subscription'
                if tx.type_transaction == 'subscription' and tx.abonnement:
                    tx.abonnement.activate(tx.reference)

                if tx.type_transaction == 'platform_subscription' and tx.publisher_subscription:
                    tx.publisher_subscription.activate(tx.reference)

                # Enregistrer écriture comptable
                try:
                    with db_transaction.atomic():
                        enregistrer_ecriture(tx)
                except Exception as e:
                    # Isolé dans son propre savepoint : une erreur ici ne doit
                    # jamais annuler la validation du paiement lui-même (voir
                    # la note dans EcritureComptable sur l'ancien bug OneToOne).
                    logger.error("Erreur écriture comptable: %s", str(e))

                # Créer notifications
                _create_payment_notifications(tx)

        elif result.get('status') == 'failed':
            tx.status = 'failed'
            tx.save(update_fields=['status'])
            Notification.objects.create(
                user=tx.payer,
                type_notif='payment_failed',
                title='Paiement échoué',
                message=f'Votre paiement de {int(tx.montant_brut)} FCFA a échoué. Veuillez réessayer.',
                data={'transaction_id': str(tx.id)},
            )
        elif result.get('status') == 'cancelled':
            tx.status = 'cancelled'
            tx.save(update_fields=['status'])

        return Response({
            'transaction': TransactionSerializer(tx).data,
            'movapay_status': result.get('status', 'unknown'),
            'message': result.get('message', ''),
        })


class WebhookView(APIView):
    """Webhook CinetPay — notification de paiement.

    Ce point d'accès doit rester ouvert (AllowAny) car c'est CinetPay, et non
    un utilisateur connecté, qui l'appelle. La sécurité repose donc sur DEUX
    vérifications complémentaires :
      1. La signature HMAC du webhook (X-TOKEN / X-Cinetpay-Signature) — sans
         elle, n'importe qui pouvait simuler une confirmation et créditer
         frauduleusement un compte.
      2. La re-vérification du statut RÉEL de la transaction auprès de
         l'API CinetPay (/v2/payment/check) : les données du webhook ne
         servent que de déclencheur, jamais de preuve (recommandation
         officielle CinetPay — un faux webhook signé ne suffit donc pas).
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        # CinetPay peut envoyer la signature sous X-TOKEN ou une en-tête
        # dédiée selon la version de l'API.
        signature = request.headers.get(
            'X-TOKEN', request.headers.get('X-Cinetpay-Signature', '')
        )
        if not verify_webhook_signature(request.body, signature):
            logger.warning("Webhook CinetPay rejeté : signature invalide ou manquante.")
            return Response({'error': 'Signature invalide.'}, status=status.HTTP_401_UNAUTHORIZED)

        data = request.data or {}
        reference = data.get('cpm_trans_id') or data.get('external_ref') or data.get('transaction_id', '')

        if not reference:
            return Response({'error': 'Référence manquante.'}, status=400)

        try:
            tx = Transaction.objects.get(reference=reference)
        except Transaction.DoesNotExist:
            return Response({'error': 'Transaction introuvable.'}, status=404)

        # ⚠️ Sécurité : on ne fait JAMAIS confiance au statut envoyé par le
        # webhook — on interroge CinetPay pour obtenir le statut réel.
        result = cinetpay_service.verifier_paiement(reference=reference)
        new_status = result.get('status', 'pending')
        movapay_ref = result.get('cinetpay_ref', '') or reference

        if new_status == 'success' and tx.status == 'pending':
            with db_transaction.atomic():
                # Voir le commentaire équivalent dans VerifierPaiementView :
                # reverrouillage anti-double-crédit indispensable ici aussi,
                # c'est le webhook Movapay qui peut légitimement être
                # rappelé plusieurs fois par la passerelle (retries réseau).
                tx = Transaction.objects.select_for_update().get(pk=tx.pk)
                if tx.status != 'pending':
                    return Response({'message': 'Déjà traité.'})
                tx.status = 'success'
                tx.movapay_ref = movapay_ref
                tx.processed_at = timezone.now()
                tx.save()

                if tx.type_transaction == 'recharge':
                    # Créditer le solde portefeuille du client
                    payer = User.objects.select_for_update().get(pk=tx.payer_id)
                    payer.solde += tx.montant_brut
                    payer.save(update_fields=['solde'])
                else:
                    if tx.beneficiaire and tx.beneficiaire.role == 'publisher':
                        profile, _ = PublisherProfile.objects.get_or_create(
                            user=tx.beneficiaire,
                            defaults={'company_name': tx.beneficiaire.name}
                        )
                        profile.solde += tx.montant_net
                        profile.total_earned += tx.montant_net
                        profile.save(update_fields=['solde', 'total_earned'])

                # Activer l'abonnement si type_transaction == 'subscription'
                if tx.type_transaction == 'subscription' and tx.abonnement:
                    tx.abonnement.activate(tx.reference)

                if tx.type_transaction == 'platform_subscription' and tx.publisher_subscription:
                    tx.publisher_subscription.activate(tx.reference)

                try:
                    with db_transaction.atomic():
                        enregistrer_ecriture(tx)
                except Exception as e:
                    logger.error("Webhook comptable error: %s", str(e))

                # Créer notifications
                _create_payment_notifications(tx)

        elif new_status in ('failed', 'cancelled') and tx.status == 'pending':
            tx.status = new_status
            tx.save(update_fields=['status'])

        return Response({'status': 'ok'})


class MesTransactionsView(generics.ListAPIView):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = Transaction.objects.filter(payer=user).select_related('publication', 'beneficiaire')
        tx_type = self.request.query_params.get('type')
        if tx_type:
            qs = qs.filter(type_transaction=tx_type)
        # ─── FILTRE PAR STATUT (ex: ?status=refunded pour la page
        # « Remboursements » du portefeuille) ──────────────────────────────
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs.order_by('-created_at')


class AdminTransactionsView(generics.ListAPIView):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = Transaction.objects.all().select_related('payer', 'beneficiaire', 'publication')
        status_filter = self.request.query_params.get('status')
        tx_type = self.request.query_params.get('type')
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')
        if status_filter:
            qs = qs.filter(status=status_filter)
        if tx_type:
            qs = qs.filter(type_transaction=tx_type)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)
        return qs.order_by('-created_at')


class WithdrawalOtpView(APIView):
    """POST /api/paiements/retrait/otp/  Body: {"channel": "email" | "sms"}

    Envoie un code OTP à 6 chiffres (15 min) au titulaire du compte avant
    qu'il puisse valider une demande de retrait — protection contre les
    retraits frauduleux (demande explicite). Le code est haché en base
    (jamais stocké en clair), comme les codes d'activation de compte.

    Canal : 'email' par défaut (boîte mail du compte). Le canal 'sms'
    envoie de vrais SMS via le fournisseur Twilio dès que les clés
    TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN / TWILIO_FROM_NUMBER sont
    renseignées dans le .env (voir apps/paiements/sms.py) ; sans clés, le
    code est journalisé (dev) et l'email reste le canal de livraison.
    """
    permission_classes = [permissions.IsAuthenticated, IsAdminOrPublisher]
    throttle_scope = 'auth'
    throttle_classes = [ScopedRateThrottle]

    @staticmethod
    def _deliver_sms(user, raw_code):
        """Point unique de branchement d'un fournisseur SMS : envoie le
        code via le service Twilio (apps.paiements.sms). Un échec de la
        passerelle est journalisé mais ne bloque JAMAIS la demande —
        l'email envoyé en parallèle reste le canal de livraison fiable."""
        try:
            from .sms import send_withdrawal_otp
            send_withdrawal_otp(user, raw_code)
        except Exception:
            logger.exception(
                "[SMS OTP retrait] échec envoi SMS à %s — code livré par email",
                user.phone or user.email,
            )

    def post(self, request):
        channel = (request.data.get('channel') or 'email').strip().lower()
        if channel not in ('email', 'sms'):
            return Response({'error': "Canal invalide. Choisissez 'email' ou 'sms'."}, status=400)

        from .models import WithdrawalVerificationCode
        raw_code = WithdrawalVerificationCode.issue_for(request.user, channel=channel)

        # ─── LIVRAISON DU CODE ────────────────────────────────────────────
        if channel == 'sms':
            self._deliver_sms(request.user, raw_code)
        # Toujours envoyer aussi par email quand le compte en a un : c'est le
        # canal le plus fiable tant qu'aucun fournisseur SMS n'est branché.
        if request.user.email:
            try:
                from django.core.mail import send_mail
                send_mail(
                    subject='DigitalPress — Confirmez votre retrait',
                    message=(
                        f"Bonjour {request.user.name or request.user.username},\n\n"
                        f"Voici votre code de confirmation de retrait : {raw_code}\n"
                        f"Il expire dans 15 minutes. Saisissez-le dans l'application pour "
                        f"valider votre demande de retrait.\n\n"
                        f"Si vous n'êtes pas à l'origine de cette demande, contactez "
                        f"immédiatement le support.\n\nL'équipe DigitalPress"
                    ),
                    from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'no-reply@digitalpress.local'),
                    recipient_list=[request.user.email],
                    fail_silently=True,
                )
            except Exception:
                logger.exception("Echec envoi email OTP retrait à %s", request.user.email)

        # Masque le destinataire (ex: j***@gmail.com) : ne révèle jamais
        # l'adresse complète dans la réponse.
        destination = request.user.email or request.user.phone or ''
        masked = destination
        if '@' in destination:
            local, _, domain = destination.partition('@')
            masked = f"{local[:1]}{'*' * max(len(local) - 1, 2)}@{domain}" if len(local) > 1 else f"*@{domain}"
        elif len(destination) >= 4:
            masked = f"{'*' * (len(destination) - 3)}{destination[-3:]}"

        return Response({
            'message': f"Un code de confirmation a été envoyé par {channel}.",
            'channel': channel,
            'destination': masked,
            'expires_in_minutes': 15,
        })


class DemanderRetraitView(generics.CreateAPIView):
    serializer_class = DemandeRetraitCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdminOrPublisher]

    def create(self, request, *args, **kwargs):
        try:
            request_data = request.data
            logger.debug(
                'Demande retrait request: user=%s, path=%s, content_type=%s, data=%s',
                request.user,
                request.path,
                request.META.get('CONTENT_TYPE'),
                request_data,
            )
            serializer = self.get_serializer(data=request_data, context={'request': request})
            serializer.is_valid(raise_exception=True)
        except Exception as exc:
            logger.warning(
                'Bad request on retrait demand: user=%s, path=%s, content_type=%s, data=%s, error=%s',
                request.user,
                request.path,
                request.META.get('CONTENT_TYPE'),
                getattr(request, 'data', None),
                exc,
                exc_info=True,
            )
            raise

        demande = serializer.save()
        return Response(DemandeRetraitSerializer(demande).data, status=status.HTTP_201_CREATED)


class MesDemandesRetraitView(generics.ListAPIView):
    serializer_class = DemandeRetraitSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_queryset(self):
        return DemandeRetrait.objects.filter(editeur=self.request.user).order_by('-created_at')


class AdminDemandesRetraitView(generics.ListAPIView):
    serializer_class = DemandeRetraitSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = DemandeRetrait.objects.all().select_related('editeur', 'traitee_par')
        status_filter = self.request.query_params.get('status')
        if status_filter:
            qs = qs.filter(status=status_filter)
        return qs.order_by('-created_at')


class AdminTraiterRetraitView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def post(self, request, pk):
        try:
            demande = DemandeRetrait.objects.select_related('editeur').get(pk=pk)
        except DemandeRetrait.DoesNotExist:
            return Response({'error': 'Demande introuvable.'}, status=404)

        serializer = AdminTraiterRetraitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        action = serializer.validated_data['action']

        with db_transaction.atomic():
            # ─── SÉCURITÉ FINANCIÈRE ──────────────────────────────────────
            # select_for_update() verrouille la ligne DemandeRetrait pour
            # toute la durée de la transaction : sans ce verrou, un
            # double-clic admin ou deux requêtes concurrentes pouvaient
            # toutes les deux lire status='approved' avant que l'une des
            # deux n'écrive 'completed', et donc débiter le solde de
            # l'éditeur DEUX FOIS pour un seul retrait réel.
            demande = DemandeRetrait.objects.select_for_update().select_related('editeur').get(pk=pk)

            if action == 'approve':
                demande.status = 'approved'
                demande.traitee_par = request.user
                demande.notes_admin = serializer.validated_data.get('notes_admin', '')
                demande.save()

            elif action == 'reject':
                if not serializer.validated_data.get('motif_rejet'):
                    return Response({'error': 'Un motif de rejet est requis.'}, status=400)
                demande.status = 'rejected'
                demande.motif_rejet = serializer.validated_data['motif_rejet']
                demande.traitee_par = request.user
                demande.save()

            elif action == 'complete':
                if demande.status not in ('approved', 'processing'):
                    return Response({'error': 'Demande non approuvée.'}, status=400)
                # Débiter le solde — profil verrouillé aussi (select_for_update)
                # pour la même raison que ci-dessus : deux retraits complétés
                # en parallèle sur le même éditeur ne doivent jamais lire un
                # solde obsolète.
                profile = PublisherProfile.objects.select_for_update().get(user=demande.editeur)
                if profile.solde < demande.montant:
                    return Response({'error': 'Solde insuffisant.'}, status=400)
                profile.solde -= demande.montant
                profile.save(update_fields=['solde'])
                # Créer transaction retrait
                tx = Transaction.objects.create(
                    payer=demande.editeur,
                    type_transaction='withdrawal',
                    montant_brut=demande.montant,
                    commission=0,
                    montant_net=demande.montant,
                    status='success',
                    processed_at=timezone.now(),
                    description=f'Retrait {demande.editeur.username}',
                )
                demande.status = 'completed'
                demande.transaction = tx
                demande.traitee_par = request.user
                demande.save()

        return Response(DemandeRetraitSerializer(demande).data)
