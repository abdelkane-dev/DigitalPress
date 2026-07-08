from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    CustomTokenObtainPairView, RegisterView, ProfileView,
    ChangePasswordView, UserListView, UserDetailView,
    PublisherProfileView, PublishersListView, PublicPublishersListView,
    AdminIssueWarningView, AdminPosterWarningsListView, MyWarningsView,
    PasswordResetRequestView, PasswordResetVerifyView, PasswordResetConfirmView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('me/', ProfileView.as_view(), name='profile'),
    path('me/change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('me/publisher-profile/', PublisherProfileView.as_view(), name='publisher_profile'),
    path('me/warnings/', MyWarningsView.as_view(), name='my_warnings'),
    path('users/', UserListView.as_view(), name='user_list'),
    path('users/<int:pk>/', UserDetailView.as_view(), name='user_detail'),
    path('publishers/', PublishersListView.as_view(), name='publishers_list'),
    path('publishers/public/', PublicPublishersListView.as_view(), name='public_publishers_list'),
    path('publishers/<int:pk>/warnings/', AdminPosterWarningsListView.as_view(), name='publisher_warnings_admin'),
    path('warnings/', AdminPosterWarningsListView.as_view(), name='warnings_admin_all'),
    path('warnings/issue/', AdminIssueWarningView.as_view(), name='issue_warning'),
    path('password-reset/request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset/verify/', PasswordResetVerifyView.as_view(), name='password_reset_verify'),
    path('password-reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
]
