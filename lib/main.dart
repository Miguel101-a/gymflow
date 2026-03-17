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
  String _initialRoute = '/login';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed('/update-password');
      }
    });
  }

  Future<void> _checkInitialAuth() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      try {
        final response = await _supabase
            .from('perfiles')
            .select('rol')
            .eq('id', session.user.id)
            .single();

        if (response['rol'] == 'admin') {
          setState(() {
            _initialRoute = '/admin';
            _isLoading = false;
          });
        } else {
          setState(() {
            _initialRoute = '/client';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _initialRoute = '/login';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _initialRoute = '/login';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'GymFlow',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/update-password': (context) => const UpdatePasswordScreen(),
        '/client': (context) => const ClientShell(),
        '/classDetail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
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
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return ClassFormScreen(classData: args);
        },
      },
    );
  }
}

/// Route guard that checks if the current user is an admin before showing AdminShell.
/// Non-admin users are redirected to /client.
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

      if (mounted) {
        if (profile['rol'] == 'admin') {
          setState(() {
            _isAdmin = true;
            _isChecking = false;
          });
        } else {
          Navigator.pushReplacementNamed(context, '/client');
        }
      }
    } catch (e) {
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
