from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.http import HttpResponse
from django.db.models import Sum, Count, Q
from django.utils import timezone
from datetime import timedelta
from .models import EcritureComptable, ReconciliationComptable
from .serializers import EcritureComptableSerializer, ReconciliationComptableSerializer
from .utils import (
    calculer_reconciliation, export_journal_csv,
    export_transactions_csv, get_dashboard_stats,
)
from apps.accounts.permissions import IsAdmin, IsPublisher


# ─── ADMIN ────────────────────────────────────────────────────────────────────

class AdminDashboardStatsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        return Response(get_dashboard_stats())


class AdminTopEditeursView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        from apps.accounts.models import PublisherProfile
        from apps.paiements.models import Transaction

        top = (
            Transaction.objects
            .filter(status='success', beneficiaire__role='publisher')
            .values('beneficiaire__id', 'beneficiaire__username')
            .annotate(total_ventes=Sum('montant_brut'), nb_tx=Count('id'))
            .order_by('-total_ventes')[:10]
        )
        results = []
        for item in top:
            uid = item['beneficiaire__id']
            try:
                profile = PublisherProfile.objects.get(user_id=uid)
                company = profile.company_name
            except PublisherProfile.DoesNotExist:
                company = item['beneficiaire__username']
            results.append({
                'user_id': uid,
                'username': item['beneficiaire__username'],
                'company_name': company,
                'total_ventes': str(item['total_ventes']),
                'nb_transactions': item['nb_tx'],
            })
        return Response(results)


class AdminEvolutionVentesView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        from apps.paiements.models import Transaction
        mois = int(request.query_params.get('mois', 12))
        data = []
        now = timezone.now()
        for i in range(mois - 1, -1, -1):
            d = (now.replace(day=1) - timedelta(days=1)) if i > 0 else now
            target = now.replace(day=1) - timedelta(days=30 * i)
            agg = Transaction.objects.filter(
                status='success',
                created_at__year=target.year,
                created_at__month=target.month,
            ).aggregate(
                total=Sum('montant_brut'),
                commissions=Sum('commission'),
                count=Count('id'),
            )
            data.append({
                'mois': target.strftime('%Y-%m'),
                'label': target.strftime('%b %Y'),
                'total': str(agg['total'] or 0),
                'commissions': str(agg['commissions'] or 0),
                'nb_transactions': agg['count'] or 0,
            })
        return Response(data)


class AdminJournalComptableView(generics.ListAPIView):
    serializer_class = EcritureComptableSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        qs = EcritureComptable.objects.all().select_related(
            'editeur', 'client', 'publication', 'transaction'
        )
        type_f = self.request.query_params.get('type')
        mois = self.request.query_params.get('mois')
        annee = self.request.query_params.get('annee')
        reconciled = self.request.query_params.get('reconciled')
        editeur_id = self.request.query_params.get('editeur_id')
        date_from = self.request.query_params.get('date_from')
        date_to = self.request.query_params.get('date_to')

        if type_f:
            qs = qs.filter(type_ecriture=type_f)
        if mois:
            qs = qs.filter(periode_mois=mois)
        if annee:
            qs = qs.filter(periode_annee=annee)
        if reconciled is not None:
            qs = qs.filter(is_reconciled=(reconciled.lower() == 'true'))
        if editeur_id:
            qs = qs.filter(editeur_id=editeur_id)
        if date_from:
            qs = qs.filter(date_ecriture__date__gte=date_from)
        if date_to:
            qs = qs.filter(date_ecriture__date__lte=date_to)
        return qs.order_by('-date_ecriture')


class AdminJournalDetailView(generics.RetrieveUpdateAPIView):
    serializer_class = EcritureComptableSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]
    queryset = EcritureComptable.objects.all()


class AdminReconciliationView(generics.ListCreateAPIView):
    serializer_class = ReconciliationComptableSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get_queryset(self):
        return ReconciliationComptable.objects.all().select_related('reconciled_by')

    def create(self, request, *args, **kwargs):
        mois = int(request.data.get('mois', timezone.now().month))
        annee = int(request.data.get('annee', timezone.now().year))

        stats = calculer_reconciliation(annee, mois)

        rec, created = ReconciliationComptable.objects.update_or_create(
            periode_annee=annee,
            periode_mois=mois,
            defaults={
                'total_recettes': stats['total_recettes'],
                'total_commissions': stats['total_commissions'],
                'total_retraits': stats['total_retraits'],
                'total_remboursements': stats['total_remboursements'],
                'solde_theorique': stats['solde_theorique'],
                'solde_reel': stats['solde_reel'],
                'ecart': stats['ecart'],
                'nb_transactions': stats['nb_transactions'],
                'nb_ecritures': stats['nb_ecritures'],
                'status': stats['status'],
            }
        )
        return Response(
            ReconciliationComptableSerializer(rec).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class AdminReconciliationDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ReconciliationComptableSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]
    queryset = ReconciliationComptable.objects.all()

    def perform_update(self, serializer):
        serializer.save(
            reconciled_by=self.request.user,
            reconciled_at=timezone.now(),
        )


class AdminExportJournalView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        qs = EcritureComptable.objects.all().select_related(
            'editeur', 'client', 'publication', 'transaction'
        ).order_by('-date_ecriture')

        mois = request.query_params.get('mois')
        annee = request.query_params.get('annee')
        if mois:
            qs = qs.filter(periode_mois=mois)
        if annee:
            qs = qs.filter(periode_annee=annee)

        fmt = request.query_params.get('format', 'csv')
        if fmt == 'csv':
            csv_content = export_journal_csv(qs)
            response = HttpResponse(csv_content, content_type='text/csv; charset=utf-8')
            filename = f"journal_comptable_{annee or 'all'}_{mois or 'all'}.csv"
            response['Content-Disposition'] = f'attachment; filename="{filename}"'
            return response
        return Response({'error': 'Format non supporté. Utilisez format=csv'}, status=400)


class AdminExportTransactionsView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        from apps.paiements.models import Transaction
        qs = Transaction.objects.all().select_related('payer', 'beneficiaire', 'publication')

        status_f = request.query_params.get('status')
        date_from = request.query_params.get('date_from')
        date_to = request.query_params.get('date_to')
        if status_f:
            qs = qs.filter(status=status_f)
        if date_from:
            qs = qs.filter(created_at__date__gte=date_from)
        if date_to:
            qs = qs.filter(created_at__date__lte=date_to)

        csv_content = export_transactions_csv(qs.order_by('-created_at'))
        response = HttpResponse(csv_content, content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="transactions.csv"'
        return response


class AdminSoldesEditeursView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    def get(self, request):
        from apps.accounts.models import PublisherProfile
        profiles = PublisherProfile.objects.select_related('user').all()
        data = []
        for p in profiles:
            data.append({
                'user_id': p.user.id,
                'username': p.user.username,
                'company_name': p.company_name,
                'solde': str(p.solde),
                'total_earned': str(p.total_earned),
                'commission_rate': str(p.commission_rate),
            })
        return Response(data)


# ─── ÉDITEUR ──────────────────────────────────────────────────────────────────

class EditeurJournalView(generics.ListAPIView):
    serializer_class = EcritureComptableSerializer
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get_queryset(self):
        qs = EcritureComptable.objects.filter(
            editeur=self.request.user
        ).select_related('client', 'publication', 'transaction')
        mois = self.request.query_params.get('mois')
        annee = self.request.query_params.get('annee')
        type_f = self.request.query_params.get('type')
        if mois:
            qs = qs.filter(periode_mois=mois)
        if annee:
            qs = qs.filter(periode_annee=annee)
        if type_f:
            qs = qs.filter(type_ecriture=type_f)
        return qs.order_by('-date_ecriture')


class EditeurSoldeView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        from apps.paiements.models import Transaction, DemandeRetrait
        from apps.accounts.models import PublisherProfile

        profile, _ = PublisherProfile.objects.get_or_create(
            user=request.user,
            defaults={'company_name': request.user.name or request.user.username}
        )

        recettes = EcritureComptable.objects.filter(
            editeur=request.user, type_ecriture='recette'
        ).aggregate(total=Sum('montant'))['total'] or 0

        commissions = EcritureComptable.objects.filter(
            editeur=request.user, type_ecriture='commission'
        ).aggregate(total=Sum('montant'))['total'] or 0

        retraits = Transaction.objects.filter(
            payer=request.user, type_transaction='withdrawal', status='success'
        ).aggregate(total=Sum('montant_brut'))['total'] or 0

        pending_retraits = DemandeRetrait.objects.filter(
            editeur=request.user, status__in=['pending', 'approved', 'processing']
        ).aggregate(total=Sum('montant'))['total'] or 0

        return Response({
            'solde_disponible': str(profile.solde),
            'total_earned': str(profile.total_earned),
            'total_recettes_brutes': str(recettes),
            'total_commissions_deduites': str(commissions),
            'total_retraits_effectues': str(retraits),
            'retraits_en_attente': str(pending_retraits),
            'commission_rate': str(profile.commission_rate),
        })


class EditeurHistoriqueTransactionsView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def list(self, request, *args, **kwargs):
        from apps.paiements.models import Transaction
        from apps.paiements.serializers import TransactionSerializer

        qs = Transaction.objects.filter(
            Q(beneficiaire=request.user) | Q(payer=request.user)
        ).select_related('payer', 'beneficiaire', 'publication').order_by('-created_at')

        type_f = request.query_params.get('type')
        status_f = request.query_params.get('status')
        if type_f:
            qs = qs.filter(type_transaction=type_f)
        if status_f:
            qs = qs.filter(status=status_f)

        return Response(TransactionSerializer(qs, many=True).data)


class EditeurExportView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        qs = EcritureComptable.objects.filter(
            editeur=request.user
        ).select_related('client', 'publication', 'transaction').order_by('-date_ecriture')

        mois = request.query_params.get('mois')
        annee = request.query_params.get('annee')
        if mois:
            qs = qs.filter(periode_mois=mois)
        if annee:
            qs = qs.filter(periode_annee=annee)

        csv_content = export_journal_csv(qs)
        response = HttpResponse(csv_content, content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="mon_journal_comptable.csv"'
        return response


class EditeurStatsVentesView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsPublisher]

    def get(self, request):
        from apps.paiements.models import Transaction
        from apps.publications.models import Publication

        now = timezone.now()
        mois = int(request.query_params.get('mois', 12))

        tx_base = Transaction.objects.filter(
            beneficiaire=request.user, status='success'
        )

        monthly = []
        for i in range(mois - 1, -1, -1):
            target = now.replace(day=1) - timedelta(days=30 * i)
            agg = tx_base.filter(
                created_at__year=target.year,
                created_at__month=target.month,
            ).aggregate(
                total=Sum('montant_net'),
                count=Count('id'),
            )
            monthly.append({
                'mois': target.strftime('%Y-%m'),
                'label': target.strftime('%b %Y'),
                'revenus': str(agg['total'] or 0),
                'nb_ventes': agg['count'] or 0,
            })

        top_pubs = (
            tx_base
            .filter(publication__isnull=False)
            .values('publication__id', 'publication__title')
            .annotate(total=Sum('montant_net'), count=Count('id'))
            .order_by('-total')[:5]
        )

        return Response({
            'evolution_mensuelle': monthly,
            'top_publications': list(top_pubs),
            'total_all_time': str(tx_base.aggregate(t=Sum('montant_net'))['t'] or 0),
            'nb_publications': Publication.objects.filter(publisher=request.user).count(),
        })
