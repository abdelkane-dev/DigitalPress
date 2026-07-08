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

import 'package:digital_press/screens/admin/admin_statistics_screen.dart';
import 'package:digital_press/screens/admin/admin_dashboard_screen.dart';
import 'package:digital_press/screens/admin/manage_posters_screen.dart';
import 'package:digital_press/screens/admin/create_poster_screen.dart';
import 'package:digital_press/screens/admin/admin_comptabilite_screen.dart';
import 'package:digital_press/screens/admin/manage_users_screen.dart';
import 'package:digital_press/screens/admin/manage_categories_screen.dart';
import 'package:digital_press/screens/admin/manage_reviews_screen.dart';

import 'package:digital_press/screens/poster/poster_dashboard_screen.dart';
import 'package:digital_press/screens/poster/create_articles_screen.dart';
import 'package:digital_press/screens/poster/my_articles_screen.dart';
import 'package:digital_press/screens/poster/poster_statistics_screen.dart';
import 'package:digital_press/screens/poster/poster_warnings_screen.dart';
import 'package:digital_press/screens/poster/manage_plans_screen.dart';
import 'package:digital_press/screens/poster/poster_profile_screen.dart';

import 'package:digital_press/screens/profile/client_wallet_screen.dart';
import 'package:digital_press/screens/profile/editeur_comptabilite_screen.dart';

import '../services/auth_service.dart';

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
        path: '/profile/wallet',
        builder: (context, state) => const ClientWalletScreen(),
      ),
      GoRoute(
        path: '/poster',
        builder: (context, state) => const PosterDashboardScreen(),
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
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
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
        path: '/admin/manage-categories',
        builder: (context, state) => const ManageCategoriesScreen(),
      ),
      GoRoute(
        path: '/admin/manage-reviews',
        builder: (context, state) => const ManageReviewsScreen(),
      ),
    ],
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isPosterRoute = state.matchedLocation.startsWith('/poster');

      if (!isLoggedIn && !isAuthRoute) {
        return '/auth/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      if (user != null) {
        final isAdmin = user.isAdmin;
        final isPublisher = user.isPublisher;

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
      }

      return null;
    },
  );
});
