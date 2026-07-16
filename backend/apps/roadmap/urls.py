from django.urls import path
from .views import (
    FeatureItemListCreateView, FeatureItemStatusUpdateView, FeatureItemDeleteView,
)

urlpatterns = [
    path('', FeatureItemListCreateView.as_view(), name='feature_list_create'),
    path('<int:pk>/status/', FeatureItemStatusUpdateView.as_view(), name='feature_status_update'),
    path('<int:pk>/', FeatureItemDeleteView.as_view(), name='feature_delete'),
]
