import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class InstructorDashboardScreen extends StatefulWidget {
  const InstructorDashboardScreen({super.key});

  @override
  State<InstructorDashboardScreen> createState() =>
      _InstructorDashboardScreenState();
}

class _InstructorDashboardScreenState
    extends State<InstructorDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _instructorName = '';
  int _totalMisClases = 0;
  int _totalMisAlumnos = 0;
  int _clasesHoy = 0;
  List<dynamic> _proximasClases = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Nombre del instructor
      final perfil = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();

      // Mis clases totales
      final misClases = await _supabase
          .from('clases')
          .select('id')
          .eq('instructor_id', user.id)
          .eq('activa', true);

      // Alumnos únicos en mis clases
      final misAlumnos = await _supabase
          .from('reservas')
          .select('usuario_id, clase:clases!inner(instructor_id)')
          .eq('clase.instructor_id', user.id)
          .eq('estado', 'confirmada');

      // IDs únicos de alumnos
      final alumnosSet = <String>{};
      for (final r in misAlumnos) {
        alumnosSet.add(r['usuario_id'].toString());
      }

      // Clases de hoy
      final hoy =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      final hoyClases = await _supabase
          .from('clases')
          .select('id')
          .eq('instructor_id', user.id)
          .eq('fecha', hoy)
          .eq('activa', true);

      // Próximas 3 clases
      final proximas = await _supabase
          .from('clases')
          .select('nombre, fecha, hora_inicio, hora_fin, ubicacion, capacidad_maxima')
          .eq('instructor_id', user.id)
          .eq('activa', true)
          .gte('fecha', hoy)
          .order('fecha', ascending: true)
          .order('hora_inicio', ascending: true)
          .limit(3);

      if (mounted) {
        setState(() {
          _instructorName = perfil['nombre_completo'] ?? 'Instructor';
          _totalMisClases = misClases.length;
          _totalMisAlumnos = alumnosSet.length;
          _clasesHoy = hoyClases.length;
          _proximasClases = proximas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('¡Hola, $_instructorName!',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Panel de Instructor',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        // Cerrar sesión
                        IconButton(
                          icon: const Icon(Icons.logout),
                          color: AppColors.textSecondary,
                          onPressed: () async {
                            await _supabase.auth.signOut();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Estadísticas ─────────────────────────────────────────
                    Row(
                      children: [
                        _buildStatCard('Mis Clases', _totalMisClases.toString(),
                            Icons.fitness_center, AppColors.primary),
                        const SizedBox(width: 12),
                        _buildStatCard('Mis Alumnos',
                            _totalMisAlumnos.toString(), Icons.people, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard('Clases Hoy', _clasesHoy.toString(),
                            Icons.today, Colors.orange),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Próximas clases ──────────────────────────────────────
                    const Text('Mis Próximas Clases',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    if (_proximasClases.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('No tienes clases próximas',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ..._proximasClases.map((clase) => _buildClaseCard(clase)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaseCard(dynamic clase) {
    final nombre = clase['nombre'] ?? '';
    final fecha = clase['fecha']?.toString() ?? '';
    final horaInicio = (clase['hora_inicio']?.toString() ?? '').length > 5
        ? (clase['hora_inicio'].toString()).substring(0, 5)
        : clase['hora_inicio']?.toString() ?? '';
    final horaFin = (clase['hora_fin']?.toString() ?? '').length > 5
        ? (clase['hora_fin'].toString()).substring(0, 5)
        : clase['hora_fin']?.toString() ?? '';
    final ubicacion = clase['ubicacion'] ?? 'Sin ubicación';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('$fecha  •  $horaInicio - $horaFin',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                Text(ubicacion,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}