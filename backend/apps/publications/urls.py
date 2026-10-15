from django.urls import path
from .views import (
    CategoryListView, CategoryDetailView, PublicationListView, PublicationDetailView,
    PublisherPublicationsView, PublicationUpdateView, PublisherStatsExportView,
    PublicationResetStatsView,
    AdminPublicationsView, ReviewCreateView, ReviewListView,
    AdminReviewListView, AdminReviewDeleteView, PublicationFileAccessView,
    ConversationListView, ConversationMarkReadView, ConversationHideView,
    ConversationFeedView, CommentCreateView, CommentDeleteView,
    ReaderCategoryListCreateView, ReaderCategoryDeleteView,
    FavoriteListView, FavoriteAddOrUpdateView, FavoriteRemoveView, MediaUploadView,
    FeaturedPublicationsView, FeaturePublicationView, VerifyFeaturePaymentView,
    AdminFeaturedPromotionsView, PublisherViewsHistoryView,
)

urlpatterns = [
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('categories/<int:pk>/', CategoryDetailView.as_view(), name='category_detail'),

    # « À la une » : vitrine (featured + tendances) et mise en avant payante
    # par l'éditeur. Déclaré avant '<int:pk>/' pour ne pas être capté par
    # la route de détail.
    path('featured/', FeaturedPublicationsView.as_view(), name='featured_publications'),
    path('<int:pk>/feature/', FeaturePublicationView.as_view(), name='feature_publication'),
    path('<int:pk>/feature/verify/', VerifyFeaturePaymentView.as_view(), name='verify_feature_payment'),

    # Admin : modération des mises en avant « À la une »
    path('admin/featured-promotions/', AdminFeaturedPromotionsView.as_view(), name='admin_featured_promotions'),
    # Éditeur : historique des vues (graphique stats)
    path('my/views-history/', PublisherViewsHistoryView.as_view(), name='my_views_history'),

    # "Mes Conversations" (remplace l'ancienne page Favoris) : doit être
    # déclaré avant '<int:pk>/' pour ne pas être capté par cette route.
    path('conversations/', ConversationListView.as_view(), name='conversation_list'),
    path('conversations/<int:pk>/read/', ConversationMarkReadView.as_view(), name='conversation_mark_read'),
    path('conversations/<int:pk>/hide/', ConversationHideView.as_view(), name='conversation_hide'),

    # Favoris & catégories personnelles du Lecteur (playlists façon YouTube).
    # Déclarés avant '<int:pk>/' pour la même raison que ci-dessus.
    path('reader-categories/', ReaderCategoryListCreateView.as_view(), name='reader_category_list_create'),
    path('reader-categories/<int:pk>/', ReaderCategoryDeleteView.as_view(), name='reader_category_delete'),
    path('favorites/', FavoriteListView.as_view(), name='favorite_list'),
    path('favorites/add/', FavoriteAddOrUpdateView.as_view(), name='favorite_add'),
    path('favorites/<int:publication_id>/', FavoriteRemoveView.as_view(), name='favorite_remove'),

    # Modération des commentaires (réponses libres façon Facebook) : l'id
    # ici est celui du Comment, pas de la Publication.
    path('comments/<int:pk>/', CommentDeleteView.as_view(), name='comment_delete'),

    path('', PublicationListView.as_view(), name='publication_list'),
    path('<int:pk>/', PublicationDetailView.as_view(), name='publication_detail'),
    path('<int:pk>/file/', PublicationFileAccessView.as_view(), name='publication_file_access'),
    path('<int:pk>/reviews/', ReviewListView.as_view(), name='review_list'),
    path('<int:pk>/reviews/add/', ReviewCreateView.as_view(), name='review_add'),
    path('<int:pk>/comments/add/', CommentCreateView.as_view(), name='comment_add'),
    path('<int:pk>/conversation-feed/', ConversationFeedView.as_view(), name='conversation_feed'),
    path('my/', PublisherPublicationsView.as_view(), name='my_publications'),
    path('my/stats-export/', PublisherStatsExportView.as_view(), name='stats_export'),
    path('my/<int:pk>/', PublicationUpdateView.as_view(), name='publication_update'),
    path('my/<int:pk>/reset-stats/', PublicationResetStatsView.as_view(), name='publication_reset_stats'),
    path('upload-media/', MediaUploadView.as_view(), name='media_upload'),
    path('admin/', AdminPublicationsView.as_view(), name='admin_publications'),
    path('admin/reviews/', AdminReviewListView.as_view(), name='admin_reviews'),
    path('admin/reviews/<int:pk>/', AdminReviewDeleteView.as_view(), name='admin_review_delete'),
]
