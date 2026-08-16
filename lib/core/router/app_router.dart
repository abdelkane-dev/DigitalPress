import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:digital_press/screens/auth/auth_login_screen.dart';
import 'package:digital_press/screens/auth/forgot_password_screen.dart';
import 'package:digital_press/screens/auth/verification_screen.dart';
import 'package:digital_press/screens/auth/reset_new_password_screen.dart';
import 'package:digital_press/screens/home/home_screen.dart';
import 'package:digital_press/screens/reader/reader_screen.dart';
import 'package:digital_press/screens/article/article_comments_screen.dart';

import 'package:digital_press/screens/admin/admin_statistics_screen.dart';
import 'package:digital_press/screens/admin/admin_dashboard_screen.dart';
import 'package:digital_press/screens/admin/admin_verifications_screen.dart';
import 'package:digital_press/screens/admin/admin_categories_screen.dart';
import 'package:digital_press/screens/admin/manage_posters_screen.dart';
import 'package:digital_press/screens/admin/create_poster_screen.dart';
import 'package:digital_press/screens/admin/admin_comptabilite_screen.dart';
import 'package:digital_press/screens/admin/manage_users_screen.dart';
import 'package:digital_press/screens/admin/admin_user_detail_screen.dart';
import 'package:digital_press/screens/admin/manage_reviews_screen.dart';
import 'package:digital_press/screens/admin/admin_featured_screen.dart';
import 'package:digital_press/screens/admin/admin_withdrawals_screen.dart';

import 'package:digital_press/screens/poster/poster_dashboard_screen.dart';
import 'package:digital_press/screens/poster/poster_subscribe_screen.dart';
import 'package:digital_press/screens/poster/poster_my_subscription_screen.dart';
import 'package:digital_press/screens/poster/poster_subscribers_screen.dart';
import 'package:digital_press/screens/poster/poster_verification_screen.dart';
import 'package:digital_press/screens/support/help_support_screen.dart';
import 'package:digital_press/screens/poster/create_articles_screen.dart';
import 'package:digital_press/screens/poster/my_articles_screen.dart';
import 'package:digital_press/screens/poster/poster_statistics_screen.dart';
import 'package:digital_press/screens/poster/poster_warnings_screen.dart';
import 'package:digital_press/screens/poster/manage_plans_screen.dart';
import 'package:digital_press/screens/poster/poster_profile_screen.dart';

import 'package:digital_press/screens/profile/client_wallet_screen.dart';
import 'package:digital_press/screens/profile/editeur_comptabilite_screen.dart';

import 'package:digital_press/screens/profile/profile_screen.dart';
import '../services/auth_service.dart';
import 'package:digital_press/model/user.dart';

/// Utilitaire pour convertir un Stream en Listenable pour GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Fournisseur Riverpod pour la configuration de navigation globale via [GoRouter].
final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final authState = ref.watch(authStateProvider);

  // ─── CORRECTIF : « la page profil m'envoie vers l'accueil » ───────────
  // Les redirections par rôle ci-dessous se déclenchaient à CHAQUE émission
  // du profil (refreshProfile(), WebSocket stats_changed…) : dès qu'on
  // ouvrait la page profil, l'utilisateur était re-routé (éditeur non
  // vérifié → /poster/verification, admin/éditeur → /…) — une "actualisation
  // qui revient vers l'accueil" à chaque ouverture. On ne relance ces
  // redirections que lorsque l'état d'authentification CHANGE RÉELLEMENT
  // (connexion, déconnexion, ou changement de rôle / statut / suspension),
  // pas quand le profil est simplement rafraîchi avec les mêmes valeurs.
  String? lastSeenAuthKey;

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const AuthLoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) =>
            const AuthLoginScreen(initialRegisterMode: true),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/verification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final mode = state.uri.queryParameters['mode'] ?? 'reset';
          return VerificationScreen(email: email, mode: mode);
        },
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final code = state.uri.queryParameters['code'] ?? '';
          return ResetNewPasswordScreen(email: email, code: code);
        },
      ),
      GoRoute(
        path: '/reader/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final isSubscribed = state.extra as bool? ?? false;
          return ReaderScreen(journalId: id, isSubscribed: isSubscribed);
        },
      ),
      GoRoute(
        path: '/article/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id']!) ?? 0;
          final scrollToComments =
              state.uri.queryParameters['scrollToComments'] == 'true';
          return ArticleCommentsScreen(
            articleId: id,
            scrollToComments: scrollToComments,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/wallet',
        builder: (context, state) => const ClientWalletScreen(),
      ),
      GoRoute(
        path: '/poster',
        builder: (context, state) => const PosterDashboardScreen(),
      ),
      GoRoute(
        path: '/poster/subscribe',
        builder: (context, state) => const PosterSubscribeScreen(),
      ),
      GoRoute(
        path: '/poster/my-subscription',
        builder: (context, state) => const PosterMySubscriptionScreen(),
      ),
      GoRoute(
        path: '/poster/subscribers',
        builder: (context, state) => const PosterSubscribersScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/poster/verification',
        builder: (context, state) => const PosterVerificationScreen(),
      ),
      GoRoute(
        path: '/poster/my-articles',
        builder: (context, state) => const MyArticlesScreen(),
      ),
      GoRoute(
        path: '/poster/create-article',
        builder: (context, state) => const CreateArticleScreen(),
      ),
      GoRoute(
        path: '/poster/statistics',
        builder: (context, state) => const PosterStatisticsScreen(),
      ),
      GoRoute(
        path: '/poster/warnings',
        builder: (context, state) => const PosterWarningsScreen(),
      ),
      GoRoute(
        path: '/poster/comptabilite',
        builder: (context, state) => const EditeurComptabiliteScreen(),
      ),
      GoRoute(
        path: '/poster/plans',
        builder: (context, state) => const ManagePlansScreen(),
      ),
      GoRoute(
        path: '/poster/profile',
        builder: (context, state) => const PosterProfileScreen(),
      ),
      GoRoute(
        path: '/publisher/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return PosterProfileScreen(publisherId: id);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/verifications',
        builder: (context, state) => const AdminVerificationsScreen(),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (context, state) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: '/admin/manage-posters',
        builder: (context, state) => const ManagePostersScreen(),
      ),
      GoRoute(
        path: '/admin/create-poster',
        builder: (context, state) => const CreatePosterScreen(),
      ),
      GoRoute(
        path: '/admin/statistics',
        builder: (context, state) => const AdminStatisticsScreen(),
      ),
      GoRoute(
        path: '/admin/comptabilite',
        builder: (context, state) => const AdminComptabiliteScreen(),
      ),
      GoRoute(
        path: '/admin/manage-users',
        builder: (context, state) => const ManageUsersScreen(),
      ),
      GoRoute(
        path: '/admin/user/:id',
        builder: (context, state) => AdminUserDetailScreen(
          userId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/admin/manage-reviews',
        builder: (context, state) => const ManageReviewsScreen(),
      ),
      GoRoute(
        path: '/admin/featured',
        builder: (context, state) => const AdminFeaturedScreen(),
      ),
      GoRoute(
        path: '/admin/withdrawals',
        builder: (context, state) => const AdminWithdrawalsScreen(),
      ),
    ],
    redirect: (context, state) {
      // ─── CORRECTIF : flash sur l'écran de connexion à chaque lancement ──
      // authState est un StreamProvider : au tout premier instant (le temps
      // que _checkInitialState() lise le token stocké + récupère le
      // profil), il est en AsyncLoading SANS valeur, donc `valueOrNull`
      // retournait déjà `null` -> le code croyait l'utilisateur déconnecté
      // et forçait /auth/login, puis redirigeait de nouveau vers '/' une
      // fois la vraie valeur reçue. On ne redirige plus tant qu'aucune
      // valeur n'a encore été émise : l'écran d'accueil affiche son
      // propre indicateur de chargement pendant ce court instant.
      if (authState.isLoading && !authState.hasValue) {
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isPosterRoute = state.matchedLocation.startsWith('/poster');

      if (!isLoggedIn && !isAuthRoute) {
        lastSeenAuthKey = null;
        return '/auth/login';
      }

      if (isLoggedIn && isAuthRoute) {
        lastSeenAuthKey = _authKey(user);
        return '/';
      }

      if (user != null) {
        // Redirections par rôle uniquement sur un vrai changement d'état.
        final authKey = _authKey(user);
        final transitioned = authKey != lastSeenAuthKey;
        lastSeenAuthKey = authKey;
        if (!transitioned) {
          return null;
        }

        final isAdmin = user.isAdmin;
        final isPublisher = user.isPublisher;
        final isSubscribeRoute = state.matchedLocation == '/poster/subscribe';

        if (isAdminRoute && !isAdmin) {
          return '/';
        }

        if (isPosterRoute && !isPublisher) {
          return '/';
        }

        if (isPosterRoute && isAdmin) {
          return '/';
        }

        if (isAdminRoute && isPublisher) {
          return '/';
        }

        // PublisherProfile.is_active passe désormais à True automatiquement
        // dès la création du compte éditeur (accès gratuit, aucun paiement).
        // Il ne peut redevenir False que si un administrateur suspend
        // explicitement le compte : /poster/subscribe sert donc uniquement
        // d'écran "compte suspendu" dans ce cas, plus un écran de paiement.
        //
        // Ordre complet de l'onboarding éditeur (2 étapes) :
        //   1. verification_status != 'approved' -> /poster/verification
        //      (dossier de légitimité, n'empêche pas de publier)
        //   2. compte suspendu par un admin -> /poster/subscribe
        //
        // ─── CORRECTIF « Mon niveau ne s'ouvre plus » ──────────────────
        // La page « Mon niveau » (/poster/my-subscription) est une simple
        // page d'information (palier actuel + progression) : elle doit
        // rester accessible même tant que la vérification de légitimité
        // n'est pas approuvée — c'est justement là que l'éditeur comprend
        // comment fonctionne son palier pendant son dossier. On l'exempte
        // donc de la redirection systématique vers /poster/verification.
        const informationalPosterRoutes = {'/poster/my-subscription'};
        final isVerificationRoute = state.matchedLocation == '/poster/verification';
        if (isPublisher &&
            user.verificationStatus != 'approved' &&
            !isAuthRoute &&
            !isVerificationRoute &&
            !informationalPosterRoutes.contains(state.matchedLocation)) {
          return '/poster/verification';
        }
        if (isPublisher &&
            user.verificationStatus == 'approved' &&
            isVerificationRoute) {
          return user.isPublisherActive ? '/poster' : '/poster/subscribe';
        }
        if (isPublisher &&
            user.verificationStatus == 'approved' &&
            !user.isPublisherActive &&
            !isAuthRoute &&
            !isSubscribeRoute) {
          return '/poster/subscribe';
        }
        if (isPublisher && user.isPublisherActive && isSubscribeRoute) {
          return '/poster';
        }
      }

      return null;
    },
  );
});

/// Clé d'authentification : identité + rôle + statut de vérification +
/// statut d'activité éditeur. Utilisée pour ne déclencher les redirections
/// par rôle que sur un changement réel, et non à chaque rafraîchissement
/// du profil (voir redirect ci-dessus).
String _authKey(User user) {
  return '${user.id}|${user.role}|${user.verificationStatus}|${user.isPublisherActive}';
}
