// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/google_profile_setup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/suspended_screen.dart';
import 'screens/venues/venue_locator_screen.dart';
import 'screens/scout/scout_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/athlete_register_screen.dart';
import 'screens/auth/coach_register_screen.dart';
import 'screens/auth/organizer_register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/events/create_event_screen.dart';
import 'screens/events/my_events_screen.dart';
import 'screens/events/record_match_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/edit_teams_screen.dart';
import 'screens/events/edit_event_screen.dart';
import 'screens/stats/add_stats_screen.dart';
import 'screens/tournaments/create_tournament_screen.dart';
import 'screens/tournaments/tournament_bracket_screen.dart';
import 'screens/tournaments/tournament_list_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/dashboard/performance_dashboard_screen.dart';
import 'screens/profile/athlete_profile_view_screen.dart';
import 'screens/profile/coach_profile_view_screen.dart';
import 'screens/profile/organizer_profile_view_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/team/team_invites_screen.dart';
import 'screens/team/my_team_screen.dart';
import 'screens/team/athlete_team_screen.dart';
import 'screens/admin/admin_shell_screen.dart';
import 'screens/settings/delete_account_screen.dart';
import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/connectivity_service.dart';
import 'utils/crash_classification.dart';
import 'widgets/no_internet_overlay.dart';

void main() async {
  // runZonedGuarded catches errors raised outside a Flutter callback — a
  // failed async call in a controller, for instance — which FlutterError
  // and PlatformDispatcher hooks never see.
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _initCrashReporting();
    } catch (e, st) {
      // Previously an init failure took down runApp() and left users on a
      // blank screen with nothing reported. Show something explanatory
      // instead, and keep the stack trace for the logs.
      debugPrint('Firebase initialization failed: $e\n$st');
      runApp(const _StartupFailureApp());
      return;
    }

    // Read the saved theme before the first frame. ThemeController also
    // loads it, but asynchronously — which meant a dark-mode user saw the
    // app build in light theme and then snap to dark. Worse, AppTheme's
    // getters are resolved once per build, so any widget built during that
    // gap picked light-mode colours and kept them.
    final startupTheme = await ThemeController.savedThemeMode();
    AppTheme.isDark = startupTheme == ThemeMode.dark;

    runApp(HomegrownApp(initialThemeMode: startupTheme));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _initCrashReporting() async {
  // Debug runs already surface errors in the console, and reporting them
  // would bury real user crashes under development noise.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // A failed image load is filed as non-fatal: the widget falls back to
    // initials and the app carries on, so counting it as a crash only buried
    // the real ones — see crash_classification.dart.
    if (isFatalFlutterError(details.library)) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } else {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
  };

  // Errors from the engine itself, outside the Flutter framework.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Shown only when Firebase cannot start, which makes every screen in the
/// app non-functional. A blank window gives the user nothing to act on.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF07070C),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📡', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 20),
                const Text(
                  "Homegrown couldn't start",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Check your connection and reopen the app. If this keeps '
                  'happening, reinstalling usually fixes it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomegrownApp extends StatelessWidget {
  /// Resolved from SharedPreferences before runApp, so the first frame is
  /// already in the user's chosen theme. ThemeController still owns changes
  /// made while the app is running.
  final ThemeMode initialThemeMode;

  const HomegrownApp({super.key, this.initialThemeMode = ThemeMode.light});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title:                    'Homegrown',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: initialThemeMode,
      builder:   (context, child) => NoInternetOverlay(
          child: child ?? const SizedBox()),
      initialBinding: BindingsBuilder(() {
        Get.put(ConnectivityService());
        Get.put(ThemeController());
        Get.put(AuthController());
      }),
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash',             page: () => const SplashScreen()),
        GetPage(name: '/onboarding',          page: () => const OnboardingScreen()),
        GetPage(name: '/login',              page: () => const LoginScreen()),
        GetPage(name: '/verify-email',            page: () => const EmailVerificationScreen()),
        GetPage(name: '/suspended',               page: () => const SuspendedScreen()),
        GetPage(name: '/google-profile-setup',    page: () => const GoogleProfileSetupScreen()),
        GetPage(name: '/forgot-password',         page: () => const ForgotPasswordScreen()),
        GetPage(name: '/venues',                  page: () => const VenueLocatorScreen()),
        GetPage(name: '/scout',                   page: () => const ScoutScreen()),
        GetPage(name: '/register',           page: () => const RegisterScreen()),
        GetPage(name: '/register/athlete',   page: () => const AthleteRegisterScreen()),
        GetPage(name: '/register/coach',     page: () => const CoachRegisterScreen()),
        GetPage(name: '/register/organizer', page: () => const OrganizerRegisterScreen()),
        GetPage(name: '/home',               page: () => const HomeScreen()),
        GetPage(name: '/events',             page: () => const MyEventsScreen()),
        GetPage(name: '/events/create',      page: () => const CreateEventScreen()),
        GetPage(name: '/events/detail',      page: () => const EventDetailScreen()),
        GetPage(name: '/events/edit-teams',  page: () => const EditTeamsScreen()),
        GetPage(name: '/events/edit',        page: () => const EditEventScreen()),
        GetPage(name: '/matches/record',     page: () => const RecordMatchScreen()),
        GetPage(name: '/tournaments',        page: () => const TournamentListScreen()),
        GetPage(name: '/tournaments/create', page: () => const CreateTournamentScreen()),
        GetPage(name: '/tournaments/detail', page: () => const TournamentBracketScreen()),
        GetPage(name: '/stats/add',          page: () => const AddStatsScreen()),
        GetPage(name: '/leaderboard',        page: () => const LeaderboardScreen()),
        GetPage(name: '/dashboard',          page: () => const PerformanceDashboardScreen()),
        GetPage(name: '/profile',            page: () => const ProfileScreen()),
        // Another athlete's profile, read-only. Takes {'athleteId': uid} as
        // route arguments; ProfileScreen above stays the signed-in user's own.
        GetPage(name: '/profile/athlete',    page: AthleteProfileViewScreen.fromRoute),
        // A coach's profile, read-only. Takes {'coachId': uid} as route
        // arguments — the counterpart an athlete opens from an invite.
        GetPage(name: '/profile/coach',      page: CoachProfileViewScreen.fromRoute),
        // An organizer's profile, read-only. Takes {'organizerId': uid} as
        // route arguments — opened from the byline on an event.
        GetPage(name: '/profile/organizer',  page: OrganizerProfileViewScreen.fromRoute),
        GetPage(name: '/team/invites',        page: () => const TeamInvitesScreen()),
        GetPage(name: '/team/roster',         page: () => const MyTeamScreen()),
        GetPage(name: '/team/mine',           page: () => const AthleteTeamScreen()),
        GetPage(name: '/admin',               page: () => const AdminShellScreen()),
        GetPage(name: '/account/delete',       page: () => const DeleteAccountScreen()),
      ],
    );
  }
}