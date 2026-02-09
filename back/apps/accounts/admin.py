from django.contrib import admin
from .models import User, PublisherProfile

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ('id','username','email','role')

@admin.register(PublisherProfile)
class PublisherProfileAdmin(admin.ModelAdmin):
    list_display = ('id','user','company_name')
