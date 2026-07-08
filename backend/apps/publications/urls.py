from django.urls import path
from .views import (
    CategoryListView, CategoryDetailView, PublicationListView, PublicationDetailView,
    PublisherPublicationsView, PublicationUpdateView,
    AdminPublicationsView, ReviewCreateView, ReviewListView,
    AdminReviewListView, AdminReviewDeleteView, PublicationFileAccessView,
    ConversationsListView, ConversationMarkReadView, ConversationHideView,
    ReaderCategoriesView, ReaderCategoryFavoriteToggleView,
)

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('categories/<int:pk>/', CategoryDetailView.as_view(), name='category_detail'),
    path('', PublicationListView.as_view(), name='publication_list'),
    path('<int:pk>/', PublicationDetailView.as_view(), name='publication_detail'),
    path('<int:pk>/file/', PublicationFileAccessView.as_view(), name='publication_file_access'),
    path('<int:pk>/reviews/', ReviewListView.as_view(), name='review_list'),
    path('<int:pk>/reviews/add/', ReviewCreateView.as_view(), name='review_add'),
    path('my/', PublisherPublicationsView.as_view(), name='my_publications'),
    path('my/<int:pk>/', PublicationUpdateView.as_view(), name='publication_update'),
    path('conversations/', ConversationsListView.as_view(), name='conversations_list'),
    path('conversations/<int:pk>/read/', ConversationMarkReadView.as_view(), name='conversation_mark_read'),
    path('conversations/<int:pk>/hide/', ConversationHideView.as_view(), name='conversation_hide'),
    path('reader/categories/', ReaderCategoriesView.as_view(), name='reader_categories'),
    path('reader/categories/<int:pk>/favorite/', ReaderCategoryFavoriteToggleView.as_view(), name='reader_category_favorite_toggle'),
    path('admin/', AdminPublicationsView.as_view(), name='admin_publications'),
    path('admin/reviews/', AdminReviewListView.as_view(), name='admin_reviews'),
    path('admin/reviews/<int:pk>/', AdminReviewDeleteView.as_view(), name='admin_review_delete'),
]
