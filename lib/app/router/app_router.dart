import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/application/auth_state_provider.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/terms_page.dart';
import '../../features/driver_home/presentation/pages/driver_home_page.dart';
import '../../features/guardian_home/presentation/pages/guardian_home_page.dart';
import '../../features/faq/presentation/pages/faq_page.dart';
import '../../app/core/constants/status_constants.dart';

// ---------------------------------------------------------------------------
// RouterNotifier bridges Riverpod → GoRouter refreshListenable
// ---------------------------------------------------------------------------

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      notifyListeners();
    });
  }
}

// ---------------------------------------------------------------------------
// Route paths
// ---------------------------------------------------------------------------

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const terms = '/terms';
  static const termsDone = '/terms-done';
  static const driverHome = '/driver';
  static const guardianHome = '/guardian';
  static const faq = '/faq';
}

// ---------------------------------------------------------------------------
// Terms provider — checks shared_preferences
// ---------------------------------------------------------------------------

final termsAcceptedProvider =
    StateNotifierProvider<TermsNotifier, bool>((ref) {
  return TermsNotifier();
});

class TermsNotifier extends StateNotifier<bool> {
  TermsNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('terms_accepted') ?? false;
  }

  void markAccepted() {
    state = true;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;

      final isPublicRoute = loc == AppRoutes.splash ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register;

      if (!isAuthenticated && !isPublicRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated) {
        // Handle terms-done: mark as accepted and go home
        if (loc == AppRoutes.termsDone) {
          ref.read(termsAcceptedProvider.notifier).markAccepted();
          return authState.role == UserRole.driver
              ? AppRoutes.driverHome
              : AppRoutes.guardianHome;
        }

        // If on splash/login/register, check terms then redirect home
        if (loc == AppRoutes.splash ||
            loc == AppRoutes.login ||
            loc == AppRoutes.register) {
          final termsAccepted = ref.read(termsAcceptedProvider);
          if (!termsAccepted) return AppRoutes.terms;
          return authState.role == UserRole.driver
              ? AppRoutes.driverHome
              : AppRoutes.guardianHome;
        }

        // Guard by role
        if (loc == AppRoutes.driverHome &&
            authState.role != UserRole.driver) {
          return AppRoutes.guardianHome;
        }
        if (loc == AppRoutes.guardianHome &&
            authState.role == UserRole.driver) {
          return AppRoutes.driverHome;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsPage(),
      ),
      GoRoute(
        path: AppRoutes.termsDone,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.driverHome,
        builder: (context, state) => const DriverHomePage(),
      ),
      GoRoute(
        path: AppRoutes.guardianHome,
        builder: (context, state) => const GuardianHomePage(),
      ),
      GoRoute(
        path: AppRoutes.faq,
        builder: (context, state) => const FaqPage(),
      ),
    ],
  );
});
