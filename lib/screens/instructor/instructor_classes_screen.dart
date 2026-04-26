import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/permissions.dart';
import '../../utils/refresh_notifier.dart';

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
  bool _canCreate = false;
  bool _canEdit = false;
  bool _canCancel = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionsAndClasses();
    RefreshNotifier.instructorRefresh.addListener(_onRefresh);
  }

  @override
  void dispose() {
    RefreshNotifier.instructorRefresh.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    _loadPermissionsAndClasses();
  }

  Future<void> _loadPermissionsAndClasses() async {
    final perms = await Permissions.load();
    if (mounted) {
      setState(() {
        _canCreate = perms[Permissions.crearClases] ?? false;
        _canEdit = perms[Permissions.editarClases] ?? false;
        _canCancel = perms[Permissions.cancelarClases] ?? false;
      });
    }
    await _fetchMisClases();
  }

  Future<void> _cancelClass(String classId, String className) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Clase'),
        content: Text(
            '¿Cancelar la clase "$className"? Se notificará a todos los alumnos con reserva activa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final currentUser = _supabase.auth.currentUser;
      final now = DateTime.now().toIso8601String();
      await _supabase.from('clases').update({
        'cancelada': true,
        'cancelada_at': now,
        'activa': false,
        'updated_at': now,
      }).eq('id', classId);

      final reservas = await _supabase
          .from('reservas')
          .select('usuario_id, perfiles(notificaciones_activas)')
          .eq('clase_id', classId)
          .eq('estado', 'confirmada');

      final notifs = <Map<String, dynamic>>[];
      for (final r in reservas) {
        final p = r['perfiles'];
        final activas = (p is Map && p['notificaciones_activas'] != null)
            ? p['notificaciones_activas'] == true
            : true;
        if (activas && r['usuario_id'] != null) {
          notifs.add({
            'usuario_id': r['usuario_id'],
            'autor_id': currentUser?.id,
            'clase_id': classId,
            'tipo': 'cancelacion',
            'asunto': 'Clase cancelada',
            'contenido':
                'La clase $className ha sido cancelada. Revisa el calendario para más información.',
            'grupo_destinatario': 'clientes',
          });
        }
      }

      if (notifs.isNotEmpty) {
        await _supabase.from('comunicaciones').insert(notifs);
      }

      _fetchMisClases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clase cancelada (${notifs.length} notificación(es) enviada(s))'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.pushNamed(context, '/admin/class_form');
                _fetchMisClases();
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
    final cancelada = clase['cancelada'] == true;
    final capacidad = clase['capacidad_maxima'] ?? 0;
    final claseId = clase['id']?.toString() ?? '';

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
              color: cancelada
                  ? AppColors.error
                  : (activa ? AppColors.primary : AppColors.textTertiary),
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
                        color: cancelada
                            ? AppColors.error.withValues(alpha: 0.15)
                            : (activa
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.textTertiary.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cancelada
                            ? 'CANCELADA'
                            : (activa ? 'ACTIVA' : 'INACTIVA'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cancelada
                              ? AppColors.error
                              : (activa ? AppColors.success : AppColors.textTertiary),
                        ),
                      ),
                    ),
                    if (!cancelada && (_canEdit || _canCancel))
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.textSecondary, size: 20),
                        onSelected: (v) async {
                          if (v == 'cancel') _cancelClass(claseId, nombre);
                          if (v == 'edit') {
                            final result = await Navigator.pushNamed(
                                context, '/admin/class_form',
                                arguments: clase);
                            if (result == true) _fetchMisClases();
                          }
                        },
                        itemBuilder: (context) => [
                          if (_canEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Editar clase'),
                              ]),
                            ),
                          if (_canCancel)
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(children: [
                                Icon(Icons.event_busy,
                                    size: 18, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Cancelar clase',
                                    style: TextStyle(color: AppColors.error)),
                              ]),
                            ),
                        ],
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