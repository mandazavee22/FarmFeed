import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/constants.dart';
import 'core/api_client.dart';
import 'models/user.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/farmer/farmer_dashboard.dart';
import 'screens/supplier/supplier_dashboard.dart';
import 'core/notification_provider.dart';

// ── Auth State Provider 
class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    if (token != null && token.isNotEmpty) {
      _token = token;
      try {
        final resp = await ApiClient.instance.getMe();
        if (resp['success'] == true) {
          _user = UserModel.fromJson(resp['data']['user']);
        }
      } catch (_) {
        await clearSession();
      }
    }
    notifyListeners();
  }

  Future<void> setSession(String token, UserModel user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
    await prefs.setString(AppConstants.roleKey, user.role);
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.roleKey);
    await prefs.remove(AppConstants.userKey);
    notifyListeners();
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

// ── Router ────────────────────────────────────────────────────────────────────
GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final loc = state.matchedLocation;

      // Never redirect away from splash
      if (loc == '/splash') return null;

      // Not authenticated → go to login
      if (!isAuth && loc != '/login' && loc != '/register') {
        return '/login';
      }

      // Authenticated but on auth screens → redirect to dashboard
      if (isAuth &&
          (loc == '/login' || loc == '/register' || loc == '/splash')) {
        return authProvider.user!.isFarmer ? '/farmer' : '/supplier';
      }

      return null;
    },
    refreshListenable: authProvider,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/farmer', builder: (_, __) => const FarmerDashboard()),
      GoRoute(path: '/supplier', builder: (_, __) => const SupplierDashboard()),
    ],
  );
}

// ── Main ──────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  ApiClient.instance.init();

  final authProvider = AuthProvider();
  final notificationProvider = NotificationProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: notificationProvider),
      ],
      child: FarmFeedApp(authProvider: authProvider),
    ),
  );
}

class FarmFeedApp extends StatelessWidget {
  final AuthProvider authProvider;
  const FarmFeedApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter(authProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: FarmTheme.theme,
      routerConfig: router,
    );
  }
}
