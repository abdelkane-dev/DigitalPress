class ApiConstants {
  // Auth
  static const String login = 'accounts/login/';
  static const String register = 'accounts/register/';
  static const String tokenRefresh = 'accounts/token/refresh/';
  static const String profile = 'accounts/me/';
  static const String users = 'accounts/users/';
  static const String publicPublishers = 'accounts/publishers/public/';
  static String publicPublisherDetail(int publisherId) =>
      'accounts/publishers/public/$publisherId/';
  static const String passwordResetRequest = 'accounts/password-reset/request/';
  static const String passwordResetVerify = 'accounts/password-reset/verify/';
  static const String passwordResetConfirm = 'accounts/password-reset/confirm/';

  // Modération / avertissements éditeurs
  static const String myWarnings = 'accounts/me/warnings/';
  static const String issueWarning = 'accounts/warnings/issue/';
  static String publisherWarnings(String publisherId) =>
      'accounts/publishers/$publisherId/warnings/';

  // Publications / Contenus
  static const String publications = 'publications/';
  static const String myPublications = 'publications/my/';
  static const String createPublication = 'publications/my/';
  static const String categories = 'publications/categories/';
  static const String adminReviews = 'publications/admin/reviews/';
  static String publicationFile(String id) => 'publications/$id/file/';
  static const String mediaUpload = 'publications/upload-media/';

  // Abonnements
  static const String abonnements = 'abonnements/';
  static const String myAbonnements = 'abonnements/my/';
  static const String createAbonnement = 'abonnements/create/';

  // Paiements
  static const String initierPaiement = 'paiements/initier/';
  static const String verifierPaiement = 'paiements/verifier/';
  static const String mesTransactions = 'paiements/transactions/';

  // Comptabilité
  static const String journalAdmin = 'admin/comptabilite/journal/';
  static const String journalEntreprise = 'entreprise/comptabilite/journal/';
  static const String soldeEditeur = 'entreprise/comptabilite/solde/';
  static const String demandeRetrait = 'paiements/retrait/demander/';
  static const String mesDemandesRetrait = 'paiements/retrait/mes-demandes/';
  static const String adminDemandesRetrait = 'paiements/admin/retraits/';
  static const String adminSoldesEditeurs = 'admin/editeurs/soldes/';
  static const String reconciliation = 'admin/comptabilite/reconciliation/';
  static const String exportCsv = 'admin/comptabilite/export/';
  static const String exportCsvEditeur = 'entreprise/comptabilite/export/';
  static const String dashboardStats = 'admin/dashboard/stats/';
  static const String topEditeurs = 'admin/dashboard/top-editeurs/';
  static const String evolutionVentes = 'admin/dashboard/evolution-ventes/';

  // Notifications
  static const String notifications = 'notifications/';
  static const String registerFcm = 'notifications/fcm/register/';

  // Mes Conversations (remplace l'ancienne page Favoris)
  static const String conversations = 'publications/conversations/';
  static String conversationMarkRead(int id) =>
      'publications/conversations/$id/read/';
  static String conversationHide(int id) =>
      'publications/conversations/$id/hide/';

  // Conversation d'un article : avis (étoiles) + commentaires façon Facebook
  static String conversationFeed(int publicationId) =>
      'publications/$publicationId/conversation-feed/';
  static String commentAdd(int publicationId) =>
      'publications/$publicationId/comments/add/';
  static String commentDelete(int commentId) =>
      'publications/comments/$commentId/';

  // Favoris & catégories personnelles du Lecteur (playlists façon YouTube)
  static const String readerCategories = 'publications/reader-categories/';
  static String readerCategoryDelete(int id) =>
      'publications/reader-categories/$id/';
  static const String favorites = 'publications/favorites/';
  static const String favoriteAdd = 'publications/favorites/add/';
  static String favoriteRemove(int publicationId) =>
      'publications/favorites/$publicationId/';

  // Fonctionnalités à venir (remplace la page Catégories pour Admin/Éditeur)
  static const String roadmap = 'roadmap/';
  static String roadmapStatus(int id) => 'roadmap/$id/status/';
  static String roadmapDelete(int id) => 'roadmap/$id/';
}
