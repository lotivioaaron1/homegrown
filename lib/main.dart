// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/google_profile_setup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/venues/venue_locator_screen.dart';
import 'screens/scout/scout_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/athlete_register_screen.dart';
import 'screens/auth/coach_register_screen.dart';
import 'screens/auth/organizer_register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/events/create_event_screen.dart';
import 'screens/events/record_match_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/events/edit_teams_screen.dart';
import 'screens/events/edit_event_screen.dart';
import 'screens/stats/add_stats_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/dashboard/performance_dashboard_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/team/team_invites_screen.dart';
import 'screens/team/my_team_screen.dart';
import 'screens/team/athlete_team_screen.dart';
import 'screens/admin/admin_review_screen.dart';
import 'controllers/auth_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/connectivity_service.dart';
import 'widgets/no_internet_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HomegrownApp());
}

class HomegrownApp extends StatelessWidget {
  const HomegrownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title:                    'Homegrown',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
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
        GetPage(name: '/google-profile-setup',    page: () => const GoogleProfileSetupScreen()),
        GetPage(name: '/forgot-password',         page: () => const ForgotPasswordScreen()),
        GetPage(name: '/venues',                  page: () => const VenueLocatorScreen()),
        GetPage(name: '/scout',                   page: () => const ScoutScreen()),
        GetPage(name: '/register',           page: () => const RegisterScreen()),
        GetPage(name: '/register/athlete',   page: () => const AthleteRegisterScreen()),
        GetPage(name: '/register/coach',     page: () => const CoachRegisterScreen()),
        GetPage(name: '/register/organizer', page: () => const OrganizerRegisterScreen()),
        GetPage(name: '/home',               page: () => HomeScreen()),
        GetPage(name: '/events/create',      page: () => const CreateEventScreen()),
        GetPage(name: '/events/detail',      page: () => const EventDetailScreen()),
        GetPage(name: '/events/edit-teams',  page: () => const EditTeamsScreen()),
        GetPage(name: '/events/edit',        page: () => const EditEventScreen()),
        GetPage(name: '/matches/record',     page: () => const RecordMatchScreen()),
        GetPage(name: '/stats/add',          page: () => const AddStatsScreen()),
        GetPage(name: '/leaderboard',        page: () => const LeaderboardScreen()),
        GetPage(name: '/dashboard',          page: () => const PerformanceDashboardScreen()),
        GetPage(name: '/profile',            page: () => const ProfileScreen()),
        GetPage(name: '/team/invites',        page: () => const TeamInvitesScreen()),
        GetPage(name: '/team/roster',         page: () => const MyTeamScreen()),
        GetPage(name: '/team/mine',           page: () => const AthleteTeamScreen()),
        GetPage(name: '/admin',               page: () => const AdminReviewScreen()),
      ],
    );
  }
}