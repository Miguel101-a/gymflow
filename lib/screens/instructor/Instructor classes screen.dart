import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class InstructorClassesScreen extends StatefulWidget {
  const InstructorClassesScreen({super.key});

  @override
  State<InstructorClassesScreen> createState() =>
      _InstructorClassesScreenState();
}

class _InstructorClassesScreenState extends State<InstructorClassesScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMisClases();
  }

  Future<void> _fetchMisClases() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('clases')
          .select('*')
          .eq('instructor_id', user.id)
          .order('fecha', ascending: true);

      if (mounted) {
        setState(() {
          _classes = data;
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
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Mis Clases',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('${_classes.length} clases',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),

            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()))
                : _classes.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center_outlined,
                                  size: 56, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text('No tienes clases asignadas',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchMisClases,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _classes.length,
                            itemBuilder: (context, index) {
                              final clase = _classes[index];
                              return _buildClaseCard(clase);
                            },
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaseCard(dynamic clase) {
    final nombre = clase['nombre'] ?? '';
    final descripcion = clase['descripcion'] ?? '';
    final fecha = clase['fecha']?.toString() ?? '';
    String horaInicio = clase['hora_inicio']?.toString() ?? '';
    String horaFin = clase['hora_fin']?.toString() ?? '';
    if (horaInicio.length > 5) horaInicio = horaInicio.substring(0, 5);
    if (horaFin.length > 5) horaFin = horaFin.substring(0, 5);
    final ubicacion = clase['ubicacion'] ?? 'Sin ubicación';
    final nivel = clase['nivel'] ?? '';
    final activa = clase['activa'] ?? true;
    final capacidad = clase['capacidad_maxima'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de color superior
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: activa ? AppColors.primary : AppColors.textTertiary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre + estado
                Row(
                  children: [
                    Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activa
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.textTertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activa ? 'ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              activa ? AppColors.success : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 12),
                // Info chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip(Icons.calendar_today, fecha),
                    _chip(Icons.access_time, '$horaInicio - $horaFin'),
                    _chip(Icons.location_on_outlined, ubicacion),
                    _chip(Icons.people_outline, '$capacidad plazas'),
                    if (nivel.isNotEmpty) _chip(Icons.bar_chart, nivel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}