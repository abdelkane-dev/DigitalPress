from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from django.db import transaction as db_transaction
from .models import Transaction, DemandeRetrait
from .serializers import (
    TransactionSerializer, InitierPaiementSerializer,
    VerifierPaiementSerializer, DemandeRetraitSerializer,
    DemandeRetraitCreateSerializer, AdminTraiterRetraitSerializer,
)
from .movapay import movapay_service, verify_webhook_signature
from apps.accounts.permissions import IsAdmin, IsPublisher
from apps.accounts.models import PublisherProfile
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
                return Response({'error': 'Publication introuvable.'}, status=404)

        if data.get('abonnement_id'):
            from apps.abonnements.models import Abonnement
            try:
                abonnement = Abonnement.objects.get(pk=data['abonnement_id'], reader=request.user)
            except Abonnement.DoesNotExist:
                return Response({'error': 'Abonnement introuvable.'}, status=404)
            if abonnement.status == 'active':
                return Response({'error': 'Cet abonnement est déjà actif.'}, status=400)
            beneficiaire = abonnement.publisher

        from decimal import Decimal
        type_tx = data.get('type_transaction', 'purchase')
        mode_paiement = data.get('mode_paiement', 'movapay')

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
                return Response({'error': 'Montant invalide.'}, status=400)
            if montant <= 0 or montant > Decimal('1000000'):
                return Response({'error': 'Montant de recharge invalide.'}, status=400)
        elif publication is not None:
            if publication.is_free or publication.prix == 0:
                return Response({'error': 'Cette publication est gratuite, aucun paiement requis.'}, status=400)
            montant = publication.prix
        elif abonnement is not None:
            montant = abonnement.montant
        else:
            return Response(
                {'error': "Impossible de déterminer le montant : precisez publication_id ou abonnement_id."},
                status=400,
            )

        # Récupérer le taux de commission du profil de l'éditeur ou 10% par défaut
        rate = Decimal('10.00')
        if beneficiaire and beneficiaire.role == 'publisher':
            profile, _ = PublisherProfile.objects.get_or_create(
                user=beneficiaire,
                defaults={'company_name': beneficiaire.name or beneficiaire.username}
            )
            rate = profile.commission_rate
            
        commission = round(montant * (rate / Decimal('100.00')), 2)
        montant_net = round(montant - commission, 2)
        reference = str(uuid.uuid4())

        if mode_paiement == 'wallet':
            if type_tx == 'recharge':
                return Response({'error': 'Impossible de recharger un portefeuille avec le portefeuille.'}, status=400)
            
            user = request.user
            if user.solde < montant:
                return Response({'error': 'Solde insuffisant dans votre portefeuille.'}, status=400)
            
            with db_transaction.atomic():
                # Débiter le client
                user.solde -= montant
                user.save(update_fields=['solde'])
                
                # Créditer l'éditeur
                if beneficiaire and beneficiaire.role == 'publisher':
                    profile, _ = PublisherProfile.objects.get_or_create(
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
                    type_transaction=type_tx,
                    montant_brut=montant,
                    commission=commission,
                    montant_net=montant_net,
                    phone_payer='',
                    status='success',
                    processed_at=timezone.now(),
                    description=data.get('description', f'Achat via portefeuille pour {publication.title if publication else "Abonnement"}'),
                    metadata={'mode_paiement': 'wallet'}
                )
                
                # Activer l'abonnement si type_transaction == 'subscription'
                if type_tx == 'subscription' and abonnement:
                    abonnement.activate(tx.reference)

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

        # Appel Movapay pour mode_paiement == 'movapay'
        movapay_result = movapay_service.initier_paiement(
            montant=float(montant),
            phone=data.get('phone', ''),
            reference=reference,
            description=data.get('description', ''),
        )

        # Créer la transaction en attente
        tx = Transaction.objects.create(
            reference=reference,
            payer=request.user,
            beneficiaire=beneficiaire,
            publication=publication,
            abonnement=abonnement,
            type_transaction=type_tx,
            montant_brut=montant,
            commission=commission,
            montant_net=montant_net,
            phone_payer=data.get('phone', ''),
            status='pending',
            description=data.get('description', ''),
            metadata=movapay_result,
        )


        return Response({
            'transaction': TransactionSerializer(tx).data,
            'payment_url': movapay_result.get('payment_url', ''),
            'movapay_ref': movapay_result.get('movapay_ref', ''),
            'message': movapay_result.get('message', ''),
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

        # Vérifier auprès de Movapay
        result = movapay_service.verifier_paiement(
            reference=data['reference'],
            movapay_ref=data.get('movapay_ref', tx.movapay_ref),
        )

        if result.get('status') == 'success' and tx.status == 'pending':
            with db_transaction.atomic():
                tx.status = 'success'
                tx.movapay_ref = result.get('movapay_ref', tx.movapay_ref)
                tx.processed_at = timezone.now()
                tx.save()

                if tx.type_transaction == 'recharge':
                    # Créditer le solde portefeuille du client
                    payer = tx.payer
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

        return Response({
            'transaction': TransactionSerializer(tx).data,
            'movapay_status': result.get('status', 'unknown'),
            'message': result.get('message', ''),
        })


class WebhookView(APIView):
    """Webhook Movapay — notification de paiement.

    Ce point d'accès doit rester ouvert (AllowAny) car c'est Movapay, et non
    un utilisateur connecté, qui l'appelle. La sécurité repose donc entièrement
    sur la vérification de signature ci-dessous : sans elle, n'importe qui
    pouvait auparavant simuler une confirmation de paiement et créditer
    frauduleusement un compte.
    """
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        signature = request.headers.get('X-Movapay-Signature', '')
        if not verify_webhook_signature(request.body, signature):
            logger.warning("Webhook Movapay rejeté : signature invalide ou manquante.")
            return Response({'error': 'Signature invalide.'}, status=status.HTTP_401_UNAUTHORIZED)

        data = request.data
        reference = data.get('external_ref', '')
        movapay_ref = data.get('transaction_id', '')
        movapay_status = data.get('status', '').lower()

        if not reference:
            return Response({'error': 'Référence manquante.'}, status=400)

        try:
            tx = Transaction.objects.get(reference=reference)
        except Transaction.DoesNotExist:
            return Response({'error': 'Transaction introuvable.'}, status=404)

        status_map = {'completed': 'success', 'paid': 'success', 'failed': 'failed', 'cancelled': 'cancelled'}
        new_status = status_map.get(movapay_status, 'pending')

        if new_status == 'success' and tx.status == 'pending':
            with db_transaction.atomic():
                tx.status = 'success'
                tx.movapay_ref = movapay_ref
                tx.processed_at = timezone.now()
                tx.save()
                
                if tx.type_transaction == 'recharge':
                    # Créditer le solde portefeuille du client
                    payer = tx.payer
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


class DemanderRetraitView(generics.CreateAPIView):
    serializer_class = DemandeRetraitCreateSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
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
                # Débiter le solde
                profile = demande.editeur.publisher_profile
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
