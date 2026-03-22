import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/update_password_screen.dart';
import 'screens/client/client_shell.dart';
import 'screens/client/class_detail_screen.dart';
import 'screens/client/edit_profile_screen.dart';
import 'screens/client/profile_screen.dart';
import 'screens/client/notifications_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/manage_class_screen.dart';
import 'screens/admin/student_management_screen.dart';
import 'screens/admin/communications_screen.dart';
import 'screens/admin/class_form_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://contgdzeveppbqnttfqo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvbnRnZHpldmVwcGJxbnR0ZnFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTQzNjMsImV4cCI6MjA4ODA3MDM2M30.tFoE5M_-wkeNkelIbO214Dm39TjbAzobO5Eb9lbrK4E',
    authOptions: const FlutterAuthClientOptions(),
  );

  runApp(const GymFlowApp());
}

class GymFlowApp extends StatefulWidget {
  const GymFlowApp({super.key});

  @override
  State<GymFlowApp> createState() => _GymFlowAppState();
}

class _GymFlowAppState extends State<GymFlowApp> {
  final _supabase = Supabase.instance.client;
  bool _handledInitialRoute = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // Maneja recuperación de contraseña primero — supabase_flutter 2.x
      // intercambia el ?code= automáticamente durante initialize() y dispara
      // este evento. Solo hay que escucharlo y navegar.
      if (event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/update-password',
            (route) => false,
          );
        });
        return;
      }

      if (event == AuthChangeEvent.initialSession) {
        if (_handledInitialRoute) return;
        _handledInitialRoute = true;

        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
          return;
        }

        await _navigateByRole(session.user.id);
        return;
      }

      if (event == AuthChangeEvent.signedIn && session != null) {
        if (!_handledInitialRoute) {
          _handledInitialRoute = true;
        }
        await _navigateByRole(session.user.id);
        return;
      }

      if (event == AuthChangeEvent.signedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        });
      }
    });
  }

  Future<void> _navigateByRole(String userId) async {
    try {
      final profile = await _supabase
          .from('perfiles')
          .select('rol')
          .eq('id', userId)
          .single();

      final route = profile['rol'] == 'admin' ? '/admin' : '/client';

      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          route,
          (route) => false,
        );
      });
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymFlow',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/update-password': (context) => const UpdatePasswordScreen(),
        '/client': (context) => const ClientShell(),
        '/classDetail': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ClassDetailScreen(classData: args);
        },
        '/editProfile': (context) => const EditProfileScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/admin': (context) => const AdminRouteGuard(),
        '/manageClass': (context) => const ManageClassScreen(),
        '/students': (context) => const StudentManagementScreen(),
        '/communications': (context) => const CommunicationsScreen(),
        '/admin/class_form': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return ClassFormScreen(classData: args);
        },
      },
    );
  }
}

class AdminRouteGuard extends StatefulWidget {
  const AdminRouteGuard({super.key});

  @override
  State<AdminRouteGuard> createState() => _AdminRouteGuardState();
}

class _AdminRouteGuardState extends State<AdminRouteGuard> {
  final _supabase = Supabase.instance.client;
  bool _isChecking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final profile = await _supabase
          .from('perfiles')
          .select('rol')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      if (profile['rol'] == 'admin') {
        setState(() {
          _isAdmin = true;
          _isChecking = false;
        });
      } else {
        Navigator.pushReplacementNamed(context, '/client');
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAdmin) {
      return const AdminShell();
    }

    return const SizedBox.shrink();
  }
}