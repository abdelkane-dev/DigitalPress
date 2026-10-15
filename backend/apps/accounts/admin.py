from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils import timezone
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode, PublisherVerification


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['username', 'email', 'name', 'role', 'is_verified', 'date_joined']
    list_filter = ['role', 'is_verified', 'is_active']
    search_fields = ['username', 'email', 'name']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Informations Digital Press', {'fields': ('role', 'name', 'phone', 'avatar', 'is_verified')}),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Informations Digital Press', {'fields': ('role', 'name', 'phone')}),
    )


@admin.register(PublisherProfile)
class PublisherProfileAdmin(admin.ModelAdmin):
    list_display = ['company_name', 'user', 'solde', 'total_earned', 'commission_rate', 'is_active']
    list_filter = ['is_active']
    search_fields = ['company_name', 'user__username']
    readonly_fields = ['solde', 'total_earned']


@admin.register(PosterWarning)
class PosterWarningAdmin(admin.ModelAdmin):
    list_display = ['publisher', 'severity', 'issued_by', 'created_at']
    list_filter = ['severity', 'created_at']
    search_fields = ['publisher__username', 'reason']
    readonly_fields = ['created_at']


@admin.register(PasswordResetCode)
class PasswordResetCodeAdmin(admin.ModelAdmin):
    list_display = ['user', 'is_used', 'attempts', 'created_at', 'expires_at']
    list_filter = ['is_used']
    readonly_fields = ['code_hash', 'created_at']


@admin.register(PublisherVerification)
class PublisherVerificationAdmin(admin.ModelAdmin):
    list_display = ['legal_company_name', 'user', 'status', 'submitted_at', 'is_overdue_display']
    list_filter = ['status', 'country']
    search_fields = ['legal_company_name', 'user__username', 'registration_number', 'tax_id']
    readonly_fields = ['submitted_at', 'updated_at', 'reviewed_at', 'reviewed_by']
    actions = ['approve_selected', 'reject_selected']

    def is_overdue_display(self, obj):
        return obj.is_overdue
    is_overdue_display.boolean = True
    is_overdue_display.short_description = 'En retard (>24h)'

    @admin.action(description="Approuver les dossiers sélectionnés")
    def approve_selected(self, request, queryset):
        from apps.notifications.models import Notification
        from apps.accounts.models import PublisherProfile
        from django.core.mail import send_mail
        from django.conf import settings

        count = 0
        for verification in queryset.filter(status='pending'):
            verification.status = 'approved'
            verification.reviewed_at = timezone.now()
            verification.reviewed_by = request.user
            verification.save(update_fields=['status', 'reviewed_at', 'reviewed_by', 'updated_at'])
            publisher = verification.user
            # ─── CORRECTIF : cette action groupée oubliait de promouvoir
            # réellement le compte (role, is_verified, PublisherProfile) —
            # contrairement à AdminPublisherVerificationReviewView.post()
            # utilisée par l'app, qui le fait. Un dossier approuvé ici
            # laissait l'éditeur bloqué côté app malgré le statut "approved".
            publisher.role = 'publisher'
            publisher.is_verified = True
            publisher.save(update_fields=['role', 'is_verified'])
            PublisherProfile.objects.get_or_create(
                user=publisher,
                defaults={'company_name': verification.legal_company_name or publisher.name or publisher.username}
            )
            Notification.objects.create(
                user=publisher, type_notif='verification_reviewed',
                title='Vérification confirmée !',
                message="Votre dossier a été validé. Vous pouvez commencer à publier dès "
                        "maintenant, gratuitement — aucun abonnement à choisir.",
            )
            if publisher.email:
                send_mail(
                    'DigitalPress — Votre compte éditeur est vérifié',
                    f"Bonjour {publisher.name or publisher.username},\n\n"
                    "Votre dossier de vérification a été validé. Connectez-vous à l'application "
                    "pour commencer à publier — c'est gratuit et automatique.\n\nL'équipe DigitalPress",
                    settings.DEFAULT_FROM_EMAIL, [publisher.email], fail_silently=True,
                )
            count += 1
        self.message_user(request, f"{count} dossier(s) approuvé(s), notification + email envoyés.")

    @admin.action(description="Rejeter les dossiers sélectionnés")
    def reject_selected(self, request, queryset):
        from apps.notifications.models import Notification
        from django.core.mail import send_mail
        from django.conf import settings

        count = 0
        for verification in queryset.filter(status='pending'):
            verification.status = 'rejected'
            verification.rejection_reason = verification.rejection_reason or 'Voir votre espace éditeur pour plus de détails.'
            verification.reviewed_at = timezone.now()
            verification.reviewed_by = request.user
            verification.save(update_fields=['status', 'rejection_reason', 'reviewed_at', 'reviewed_by', 'updated_at'])
            publisher = verification.user
            Notification.objects.create(
                user=publisher, type_notif='verification_reviewed',
                title='Vérification refusée',
                message=f"Votre dossier a été refusé. Motif : {verification.rejection_reason}",
            )
            if publisher.email:
                send_mail(
                    'DigitalPress — Votre dossier de vérification a été refusé',
                    f"Bonjour {publisher.name or publisher.username},\n\n"
                    f"Votre dossier a été refusé. Motif : {verification.rejection_reason}\n\n"
                    "Vous pouvez corriger et le soumettre à nouveau.\n\nL'équipe DigitalPress",
                    settings.DEFAULT_FROM_EMAIL, [publisher.email], fail_silently=True,
                )
            count += 1
        self.message_user(request, f"{count} dossier(s) rejeté(s), notification + email envoyés. "
                                    "Pour un motif personnalisé par dossier, utilisez plutôt "
                                    "l'écran admin de l'application.")
