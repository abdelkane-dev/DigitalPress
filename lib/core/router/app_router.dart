import 'dart:async';

import 'package:flutter/material.dart';
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
  // ⚠️ FIX CRITIQUE : on utilise ref.read (et non ref.watch) pour
  // authStateProvider. Le ref.watch invalidait ce provider à CHAQUE
  // émission du stream (refreshProfile(), WebSocket, etc.), recréant
  // le GoRouter à initialLocation '/' → retour forcé à l'accueil.
  // Le refreshListenable ci-dessous gère déjà la re-évaluation des
  // redirections quand l'auth state change réellement.

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
    initialLocation: '/auth/login',
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
        path: '/accounts/auth/facebook/callback',
        builder: (context, state) => const AuthLoginScreen(),
      ),
      GoRoute(
        path: '/_=_',
        builder: (context, state) => const AuthLoginScreen(),
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
      // On lit l'authState à chaque appel de redirect (pas au moment
      // de la création du provider) pour éviter la recreation du router.
      final authState = ref.read(authStateProvider);
      // ─── CORRECTIF : flash sur l'écran de connexion à chaque lancement ──
      if (authState.isLoading && !authState.hasValue) {
        return null;
      }

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth') ||
          location.startsWith('/accounts/auth') ||
          location == '/_=_' ||
          location.contains('_=_');
      final isAdminRoute = location.startsWith('/admin');
      final isPosterRoute = location.startsWith('/poster');

      // ── Tout utilisateur non connecté → redirection directe vers la page de connexion ──
      if (!isLoggedIn && !isAuthRoute) {
        lastSeenAuthKey = null;
        return '/auth/login';
      }

      // ── Connecté sur route auth → accueil ────────────────────────────────
      if (isLoggedIn && isAuthRoute) {
        lastSeenAuthKey = _authKey(user);
        return '/';
      }

      if (user != null) {
        final authKey = _authKey(user);
        // ── On ne re-déclenche les redirections par rôle QUE lors d'un vrai
        // changement d'état (connexion, changement de rôle, etc.).
        // Cela évite que le FilePicker/updateProfile/WebSocket ne cause un
        // rechargement de page en réévaluant les redirections inutilement.
        final transitioned = authKey != lastSeenAuthKey;
        lastSeenAuthKey = authKey;

        if (!transitioned) {
          // Pas de changement d'état → on ne touche pas à la navigation.
          return null;
        }

        final isAdmin = user.isAdmin;
        final isPublisher = user.isPublisher;
        final isSubscribeRoute = location == '/poster/subscribe';

        // Un non-admin essaie d'accéder à une route admin
        if (isAdminRoute && !isAdmin) return '/';

        // Un non-éditeur essaie d'accéder à une route poster
        if (isPosterRoute && !isPublisher && !isAdmin) return '/';

        // Un admin n'a pas accès aux routes éditeur (et vice-versa)
        if (isPosterRoute && isAdmin) return '/';
        if (isAdminRoute && isPublisher) return '/';

        // Éditeur suspendu : seulement si on tente d'accéder au dashboard
        // principal /poster (pas les sous-routes comme create-article, etc.)
        if (isPublisher &&
            !user.isPublisherActive &&
            !isAuthRoute &&
            !isSubscribeRoute &&
            location == '/poster') {
          return '/poster/subscribe';
        }
      }

      return null;
    },
    errorBuilder: (context, state) {
      if (state.uri.toString().contains('_=_') ||
          state.uri.path.contains('_=_') ||
          state.uri.path.contains('callback') ||
          state.uri.path.contains('facebook')) {
        return const AuthLoginScreen();
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Page introuvable', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Accueil'),
              ),
            ],
          ),
        ),
      );
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
