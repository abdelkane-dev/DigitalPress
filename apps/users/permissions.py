# apps/users/permissions.py
from rest_framework import permissions

class IsPublisher(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'publisher'

class IsReader(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'reader'