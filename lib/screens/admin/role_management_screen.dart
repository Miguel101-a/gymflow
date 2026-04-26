import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _users = [];
  String _searchQuery = '';

  static const List<MapEntry<String, String>> _permissions = [
    MapEntry('puede_crear_clases', 'Puede crear clases'),
    MapEntry('puede_editar_clases', 'Puede editar clases'),
    MapEntry('puede_cancelar_clases', 'Puede cancelar clases'),
    MapEntry('puede_ver_alumnos', 'Puede ver alumnos'),
    MapEntry('puede_ver_reportes', 'Puede ver reportes'),
    MapEntry('puede_enviar_comunicados', 'Puede enviar comunicados'),
    MapEntry('puede_administrar_usuarios', 'Puede administrar usuarios'),
    MapEntry('puede_administrar_roles', 'Puede administrar roles'),
    MapEntry('puede_acceder_configuracion', 'Puede acceder a configuración'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _supabase
          .from('perfiles')
          .select('id, nombre_completo, rol, permisos, avatar_url')
          .order('nombre_completo', ascending: true);
      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, bool> _defaultPermsForRole(String rol) {
    if (rol == 'admin') {
      return {for (final e in _permissions) e.key: true};
    }
    if (rol == 'instructor') {
      const instructorTrue = {
        'puede_crear_clases',
        'puede_editar_clases',
        'puede_cancelar_clases',
        'puede_ver_alumnos',
      };
      return {for (final e in _permissions) e.key: instructorTrue.contains(e.key)};
    }
    return {for (final e in _permissions) e.key: false};
  }

  void _openUserDetail(Map<String, dynamic> user) {
    final initialPerms = (user['permisos'] is Map)
        ? Map<String, bool>.from(
            (user['permisos'] as Map).map((k, v) => MapEntry(k.toString(), v == true)))
        : <String, bool>{};
    final fullPerms = {
      for (final e in _permissions) e.key: initialPerms[e.key] ?? false,
    };

    String currentRole = user['rol'] ?? 'cliente';
    final initialRole = currentRole;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> handleSave() async {
              setSheetState(() => isSaving = true);
              try {
                final updatedRow = await _supabase.from('perfiles').update({
                  'rol': currentRole,
                  'permisos': fullPerms,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', user['id'].toString()).select('id').maybeSingle();
                if (!mounted) return;
                if (updatedRow == null) {
                  setSheetState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo guardar. Verifica las políticas de seguridad.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Cambios guardados'),
                      backgroundColor: AppColors.success),
                );
                _fetchUsers();
              } catch (e) {
                setSheetState(() => isSaving = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                );
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(user['nombre_completo'] ?? 'Sin nombre',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 24),
                        const Text('Rol del usuario',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentRole,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                                DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                              ],
                              onChanged: (v) {
                                if (v == null || v == currentRole) return;
                                setSheetState(() {
                                  currentRole = v;
                                  // Si cambia el rol, sugerimos los defaults de ese rol.
                                  fullPerms
                                    ..clear()
                                    ..addAll(_defaultPermsForRole(v));
                                });
                              },
                            ),
                          ),
                        ),
                        if (currentRole != initialRole) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(children: [
                              Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se aplicaron los permisos por defecto del nuevo rol. Ajústalos si quieres antes de guardar.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Text('Permisos específicos',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text(
                            'Marca/desmarca lo que este usuario puede hacer.',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: Column(
                            children: _permissions.map((perm) {
                              return CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                title: Text(perm.value, style: const TextStyle(fontSize: 13)),
                                value: fullPerms[perm.key] ?? false,
                                activeColor: AppColors.primary,
                                onChanged: (v) {
                                  setSheetState(() => fullPerms[perm.key] = v ?? false);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSaving ? null : () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Cancelar',
                                    style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: isSaving ? null : handleSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Guardar cambios',
                                        style: TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _roleColor(String rol) {
    switch (rol) {
      case 'admin':
        return AppColors.error;
      case 'instructor':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      if (_searchQuery.isEmpty) return true;
      final name = (u['nombre_completo'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const Expanded(
                    child: Text('Administrar roles',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No hay usuarios',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final u = filtered[index];
                    final rol = (u['rol'] ?? 'cliente').toString();
                    final hasAvatar =
                        u['avatar_url'] != null && u['avatar_url'].toString().isNotEmpty;
                    return GestureDetector(
                      onTap: () => _openUserDetail(u),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.chipBackground,
                              backgroundImage:
                                  hasAvatar ? NetworkImage(u['avatar_url']) : null,
                              child: !hasAvatar
                                  ? const Icon(Icons.person, color: AppColors.primary)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u['nombre_completo'] ?? 'Sin nombre',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _roleColor(rol).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(rol.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _roleColor(rol))),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
