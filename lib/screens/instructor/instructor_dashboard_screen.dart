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
  String _nombre = '';
  int _misClases = 0;
  int _misAlumnos = 0;
  int _clasesHoy = 0;
  List<dynamic> _proximas = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final perfil = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();

      final clases = await _supabase
          .from('clases')
          .select('id')
          .eq('instructor_id', user.id)
          .eq('activa', true);

      final reservas = await _supabase
          .from('reservas')
          .select('usuario_id, clase:clases!inner(instructor_id)')
          .eq('clase.instructor_id', user.id)
          .eq('estado', 'confirmada');

      final alumnosUnicos = <String>{};
      for (final r in reservas) {
        alumnosUnicos.add(r['usuario_id'].toString());
      }

      final hoy =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

      final hoyData = await _supabase
          .from('clases')
          .select('id')
          .eq('instructor_id', user.id)
          .eq('fecha', hoy)
          .eq('activa', true);

      final proximas = await _supabase
          .from('clases')
          .select('nombre, fecha, hora_inicio, hora_fin, ubicacion')
          .eq('instructor_id', user.id)
          .eq('activa', true)
          .gte('fecha', hoy)
          .order('fecha', ascending: true)
          .order('hora_inicio', ascending: true)
          .limit(4);

      if (mounted) {
        setState(() {
          _nombre = perfil['nombre_completo'] ?? 'Instructor';
          _misClases = clases.length;
          _misAlumnos = alumnosUnicos.length;
          _clasesHoy = hoyData.length;
          _proximas = proximas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Diálogo de confirmación de cierre de sesión ───────────────────────────
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.orange, size: 38),
              ),
              const SizedBox(height: 18),
              const Text(
                '¿Cerrar sesión?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '¿Estás seguro de que deseas salir de tu cuenta?',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('No, quedarme',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sí, salir',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _supabase.auth.signOut();
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
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('¡Hola, $_nombre!',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              const Text('Panel de Instructor',
                                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        // Botón de cerrar sesión con confirmación
                        IconButton(
                          icon: const Icon(Icons.logout),
                          color: AppColors.textSecondary,
                          onPressed: _confirmLogout,   // ← usa diálogo
                          tooltip: 'Cerrar sesión',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats
                    Row(
                      children: [
                        _stat('Mis Clases', _misClases, Icons.fitness_center, AppColors.primary),
                        const SizedBox(width: 12),
                        _stat('Alumnos', _misAlumnos, Icons.people, Colors.green.shade600),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _stat('Clases Hoy', _clasesHoy, Icons.today, Colors.orange.shade700),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const Text('Mis Próximas Clases',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    if (_proximas.isEmpty)
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
                      ..._proximas.map((c) => _claseCard(c)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color color) {
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
                Text(value.toString(),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _claseCard(dynamic c) {
    String hi = c['hora_inicio']?.toString() ?? '';
    String hf = c['hora_fin']?.toString() ?? '';
    if (hi.length > 5) hi = hi.substring(0, 5);
    if (hf.length > 5) hf = hf.substring(0, 5);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['nombre'] ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${c['fecha']}  •  $hi - $hf',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if ((c['ubicacion'] ?? '').toString().isNotEmpty)
                  Text(c['ubicacion'],
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}