from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, PublisherProfile, PosterWarning, PasswordResetCode


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
