from django.urls import path
from .views import PublicationListView, PublicationDetailView, PublicationCreateView, PublisherPublicationsView

urlpatterns = [
    path('', PublicationListView.as_view(), name='publications-list'),
    path('<int:pk>/', PublicationDetailView.as_view(), name='publication-detail'),
    path('my/', PublisherPublicationsView.as_view(), name='publisher-publications'),
    path('create/', PublicationCreateView.as_view(), name='publication-create'),
]
