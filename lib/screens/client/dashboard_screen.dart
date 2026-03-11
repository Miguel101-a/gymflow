import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import 'client_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;
  String _userName = '';
  bool _isLoading = true;
  List<dynamic> _upcomingClasses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Load profile
      final profile = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();
      
      // Load upcoming reservations with class info
      final reservations = await _supabase
          .from('reservas')
          .select('*, clase:clases(*, instructor:perfiles(nombre_completo))')
          .eq('usuario_id', user.id)
          .eq('estado', 'confirmada')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _userName = profile['nombre_completo'] ?? 'Usuario';
          _upcomingClasses = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Usuario';
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días,';
    if (hour < 18) return 'Buenas tardes,';
    return 'Buenas noches,';
  }

  void _navigateToClassList() {
    // Access the ClientShell and switch to class list tab (index 1)
    final shellState = context.findAncestorStateOfType<ClientShellState>();
    if (shellState != null) {
      shellState.switchTab(1);
    }
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No tienes notificaciones nuevas'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showProfileMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        100,
        16,
        0,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline, size: 20),
            title: Text('Mi perfil', style: TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reservations',
          child: ListTile(
            leading: Icon(Icons.calendar_today_outlined, size: 20),
            title: Text('Mis reservas', style: TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, size: 20, color: AppColors.error),
            title: Text('Cerrar sesión', style: TextStyle(fontSize: 14, color: AppColors.error)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'profile') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) {
          shellState.switchTab(3);
        }
      } else if (value == 'reservations') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) {
          shellState.switchTab(2);
        }
      } else if (value == 'logout') {
        _signOut();
      }
    });
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showProfileMenu,
                      child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.chipBackground,
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showNotifications,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Ready message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: AppColors.textPrimary),
                    children: [
                      const TextSpan(text: '¿Listo para tu\npróxima '),
                      const TextSpan(text: 'sesión', style: TextStyle(color: AppColors.primary)),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Reserve button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton.icon(
                  onPressed: _navigateToClassList,
                  icon: const Text('Reservar Nueva Clase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  label: const Icon(Icons.calendar_month_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Upcoming Classes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tus Próximas Clases', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () {
                        final shellState = context.findAncestorStateOfType<ClientShellState>();
                        if (shellState != null) shellState.switchTab(2);
                      },
                      child: const Text('Ver Todo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _upcomingClasses.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: const Center(
                          child: Column(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text('No tienes clases reservadas', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                              SizedBox(height: 4),
                              Text('Reserva tu primera clase ahora', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _upcomingClasses.length,
                        itemBuilder: (context, index) {
                          final reservation = _upcomingClasses[index];
                          final clase = reservation['clase'] ?? {};
                          final nombre = clase['nombre'] ?? 'Clase';
                          final instructorName = clase['instructor']?['nombre_completo'] ?? 'Instructor';
                          final fecha = clase['fecha'] ?? '';
                          final horaInicio = clase['hora_inicio'] ?? '';

                          return Padding(
                            padding: EdgeInsets.only(right: index < _upcomingClasses.length - 1 ? 16 : 0),
                            child: _buildClassCard(
                              context,
                              nombre,
                              instructorName,
                              '$fecha • $horaInicio',
                              null,
                              clase,
                            ),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 28),
              // Weekly Activity
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Actividad Semanal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RESERVAS ACTIVAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontFamily: 'Inter', color: AppColors.textPrimary),
                                children: [
                                  TextSpan(text: '${_upcomingClasses.length}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
                                  const TextSpan(text: ' clases', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: CircularProgressIndicator(
                                value: _upcomingClasses.isEmpty ? 0 : (_upcomingClasses.length / 5).clamp(0.0, 1.0),
                                strokeWidth: 6,
                                backgroundColor: AppColors.border,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            Center(
                              child: Text(
                                '${((_upcomingClasses.isEmpty ? 0 : (_upcomingClasses.length / 5) * 100).round())}%',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Updates
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Actualizaciones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              _buildUpdateItem(
                Icons.info_outline,
                AppColors.primary,
                'Bienvenido a GymFlow',
                'Reserva tus clases favoritas y mantén el control de tu entrenamiento.',
                'Ahora',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassCard(BuildContext context, String title, String instructor, String time, String? badge, Map<String, dynamic> classData) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/classDetail',
        arguments: classData,
      ),
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: AppColors.chipBackground,
                    child: const Center(child: Icon(Icons.fitness_center, size: 40, color: AppColors.primary)),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge, style: const TextStyle(color: AppColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.more_horiz, color: AppColors.textTertiary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(time, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(instructor, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateItem(IconData icon, Color color, String title, String message, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
