from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User  # On importe seulement User ici

class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ['username', 'email', 'role', 'kyc_status']
    fieldsets = UserAdmin.fieldsets + (
        ('Info Zinote', {'fields': ('role', 'company_name', 'kyc_status', 'status')}),
    )

admin.site.register(User, CustomUserAdmin)