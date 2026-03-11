import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class ManageClassScreen extends StatefulWidget {
  const ManageClassScreen({super.key});

  @override
  State<ManageClassScreen> createState() => _ManageClassScreenState();
}

class _ManageClassScreenState extends State<ManageClassScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
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
          
      _fetchClasses();
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
                            final ubicacion = cl['ubicacion'] ?? 'N/A';
                            final nivel = cl['nivel'] ?? 'todos';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: activa ? AppColors.border : AppColors.error.withOpacity(0.3),
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
                                            if (result == true) _fetchClasses();
                                          } else if (value == 'delete') {
                                            _deleteClass(cl['id'].toString());
                                          } else if (value == 'toggle') {
                                            _toggleActive(cl['id'].toString(), activa);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Text(activa ? 'Desactivar' : 'Activar'),
                                          ),
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
                                      color: activa ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activa ? 'ACTIVA' : 'INACTIVA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: activa ? AppColors.success : AppColors.error,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/admin/class_form');
          if (result == true) _fetchClasses();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }
}
