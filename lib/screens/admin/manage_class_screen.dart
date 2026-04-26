import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../utils/permissions.dart';

class ManageClassScreen extends StatefulWidget {
  const ManageClassScreen({super.key});

  @override
  State<ManageClassScreen> createState() => _ManageClassScreenState();
}

class _ManageClassScreenState extends State<ManageClassScreen> {
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
    await _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    try {
      final data = await _supabase
          .from('clases')
          .select('*, instructor:perfiles(nombre_completo)')
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

  Future<void> _toggleActive(String classId, bool currentActive) async {
    try {
      await _supabase
          .from('clases')
          .update({'activa': !currentActive, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', classId);
          
      RefreshNotifier.notifyAdmin();
      _fetchClasses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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

      RefreshNotifier.notifyAdmin();
      RefreshNotifier.notifyClient();
      _fetchClasses();

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

  Future<void> _deleteClass(String classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Clase'),
        content: const Text('¿Estás seguro de que deseas eliminar esta clase? Esto no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('clases').delete().eq('id', classId);
        RefreshNotifier.notifyAdmin();
        _fetchClasses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clase eliminada'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppColors.error),
          );
        }
      }
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
                    child: Text('Gestión de Clases',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('Total: ${_classes.length}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // List
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _classes.isEmpty
                    ? const Expanded(child: Center(child: Text('No hay clases registradas')))
                    : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final cl = _classes[index];
                            final nombre = cl['nombre'] ?? 'Sin nombre';
                            final instructor = cl['instructor']?['nombre_completo'] ?? 'Sin instructor';
                            final fecha = cl['fecha']?.toString() ?? '';
                            final horaInicio = cl['hora_inicio']?.toString() ?? '';
                            final horaFin = cl['hora_fin']?.toString() ?? '';
                            final capacidadMaxima = cl['capacidad_maxima'] ?? 0;
                            final activa = cl['activa'] ?? false;
                            final cancelada = cl['cancelada'] == true;
                            final ubicacion = cl['ubicacion'] ?? 'N/A';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: activa ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(nombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            final result = await Navigator.pushNamed(context, '/admin/class_form', arguments: cl);
                                            if (result == true) {
                                              RefreshNotifier.notifyAdmin();
                                              _fetchClasses();
                                            }
                                          } else if (value == 'delete') {
                                            _deleteClass(cl['id'].toString());
                                          } else if (value == 'toggle') {
                                            _toggleActive(cl['id'].toString(), activa);
                                          } else if (value == 'cancel') {
                                            _cancelClass(cl['id'].toString(), cl['nombre']?.toString() ?? 'Sin nombre');
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (_canCancel && !cancelada)
                                            const PopupMenuItem(
                                              value: 'cancel',
                                              child: Row(children: [
                                                Icon(Icons.event_busy, size: 18, color: AppColors.error),
                                                SizedBox(width: 8),
                                                Text('Cancelar clase', style: TextStyle(color: AppColors.error)),
                                              ]),
                                            ),
                                          if (_canCancel && !cancelada)
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(activa ? 'Desactivar' : 'Activar'),
                                            ),
                                          if (_canEdit && !cancelada)
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Editar'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text(instructor, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Text('$fecha • $horaInicio - $horaFin',
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(ubicacion, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text('Cap: $capacidadMaxima',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/admin/class_form');
                if (result == true) {
                  RefreshNotifier.notifyAdmin();
                  _fetchClasses();
                }
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: AppColors.white),
            )
          : null,
    );
  }
}
