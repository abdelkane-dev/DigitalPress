from django.urls import path
from .views import (
    PlanListView, PlanAdminView, PlanDetailAdminView,
    MyAbonnementsView, AbonnementCreateView, AbonnementActivateView,
    AdminAbonnementsView, PublisherAbonnementsView,
    PublisherPlansView, PublisherPlanDetailView,
    PlatformPlanListView, PlatformPlanAdminView, PlatformPlanAdminDetailView,
    MyPublisherSubscriptionView, PublisherSubscribeView, AdminPublisherSubscriptionsView,
    PublisherSubscriberManageView,
)

urlpatterns = [
    path('plans/', PlanListView.as_view(), name='plan_list'),
    path('plans/admin/', PlanAdminView.as_view(), name='plan_admin'),
    path('plans/admin/<int:pk>/', PlanDetailAdminView.as_view(), name='plan_admin_detail'),
    # Gestion des plans par les éditeurs
    path('plans/editeur/', PublisherPlansView.as_view(), name='publisher_plans'),
    path('plans/editeur/<int:pk>/', PublisherPlanDetailView.as_view(), name='publisher_plan_detail'),
    path('my/', MyAbonnementsView.as_view(), name='my_abonnements'),
    path('create/', AbonnementCreateView.as_view(), name='abonnement_create'),
    path('<int:pk>/activate/', AbonnementActivateView.as_view(), name='abonnement_activate'),
    path('admin/', AdminAbonnementsView.as_view(), name='admin_abonnements'),
    path('publisher/', PublisherAbonnementsView.as_view(), name='publisher_abonnements'),
    # Gestion des abonnés par l'éditeur : retirer / bannir.
    path('publisher/<int:pk>/<str:action>/', PublisherSubscriberManageView.as_view(), name='publisher_subscriber_manage'),
    # Abonnement plateforme (éditeur -> plateforme, obligatoire)
    path('platform-plans/', PlatformPlanListView.as_view(), name='platform_plan_list'),
    path('platform-plans/admin/', PlatformPlanAdminView.as_view(), name='platform_plan_admin'),
    path('platform-plans/admin/<int:pk>/', PlatformPlanAdminDetailView.as_view(), name='platform_plan_admin_detail'),
    path('platform-subscription/me/', MyPublisherSubscriptionView.as_view(), name='my_platform_subscription'),
    path('platform-subscription/subscribe/', PublisherSubscribeView.as_view(), name='platform_subscribe'),
    path('platform-subscription/admin/', AdminPublisherSubscriptionsView.as_view(), name='admin_platform_subscriptions'),
]
