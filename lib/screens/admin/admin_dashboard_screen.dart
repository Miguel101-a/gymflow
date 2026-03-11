import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalStudents = 0;
  int _totalClasses = 0;
  int _totalReservations = 0;
  List<dynamic> _recentReservations = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      // Count students (users with role 'cliente')
      final students = await _supabase
          .from('perfiles')
          .select('id')
          .eq('rol', 'cliente');

      // Count active classes
      final classes = await _supabase
          .from('clases')
          .select('id')
          .eq('activa', true);

      // Count all reservations
      final reservations = await _supabase
          .from('reservas')
          .select('id');

      // Get recent reservations
      final recent = await _supabase
          .from('reservas')
          .select('*, usuario:perfiles(nombre_completo), clase:clases(nombre, fecha, hora_inicio)')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _totalStudents = students.length;
          _totalClasses = classes.length;
          _totalReservations = reservations.length;
          _recentReservations = recent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Panel Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.logout, size: 20, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Stats cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildStatCard('Estudiantes', _totalStudents.toString(), Icons.people, AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Clases', _totalClasses.toString(), Icons.fitness_center, AppColors.success)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildStatCard('Reservas', _totalReservations.toString(), Icons.calendar_today, AppColors.warning)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('', '', Icons.more_horiz, AppColors.textTertiary, isEmpty: true)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Recent Reservations
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Reservas Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              _recentReservations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('No hay reservas recientes', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    )
                  : Column(
                      children: _recentReservations.map((reservation) {
                        final usuario = reservation['usuario']?['nombre_completo'] ?? 'Usuario';
                        final clase = reservation['clase']?['nombre'] ?? 'Clase';
                        final fecha = reservation['clase']?['fecha']?.toString() ?? '';
                        final horaInicio = reservation['clase']?['hora_inicio']?.toString() ?? '';
                        final estado = (reservation['estado'] ?? '').toString();

                        Color statusColor;
                        switch (estado) {
                          case 'confirmada':
                            statusColor = AppColors.success;
                            break;
                          case 'cancelada':
                            statusColor = AppColors.error;
                            break;
                          default:
                            statusColor = AppColors.warning;
                        }

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.chipBackground,
                                child: Icon(Icons.person, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(usuario, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text('$clase • $fecha $horaInicio',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  estado.toUpperCase(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isEmpty = false}) {
    if (isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
