import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';

enum _CommFilter { todos, noLeidos, leidos, importantes, archivados }

class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  final _supabase = Supabase.instance.client;

  List<dynamic> _communications = [];
  List<dynamic> _students = [];
  bool _isLoading = true;
  bool _showStudents = false;
  _CommFilter _filter = _CommFilter.todos;
  final _studentSearchController = TextEditingController();
  String _studentQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _studentSearchController.addListener(() {
      setState(() => _studentQuery = _studentSearchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchCommunications(), _fetchStudents()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchCommunications() async {
    try {
      final data = await _supabase
          .from('comunicaciones')
          .select('*, autor:perfiles!comunicaciones_autor_id_fkey(nombre_completo), destinatario:perfiles!comunicaciones_usuario_id_fkey(nombre_completo)')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _communications = data);
    } catch (_) {
      // Fallback sin alias por si las FKs no tienen nombres definidos
      try {
        final data = await _supabase
            .from('comunicaciones')
            .select('*, autor:perfiles(nombre_completo)')
            .order('created_at', ascending: false);
        if (mounted) setState(() => _communications = data);
      } catch (_) {}
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final data = await _supabase
          .from('perfiles')
          .select('id, nombre_completo, email, avatar_url')
          .eq('rol', 'cliente')
          .order('nombre_completo', ascending: true);
      if (mounted) setState(() => _students = data);
    } catch (_) {}
  }

  List<dynamic> get _filteredCommunications {
    return _communications.where((c) {
      switch (_filter) {
        case _CommFilter.todos:
          return c['archivada'] != true;
        case _CommFilter.noLeidos:
          return c['leida'] != true && c['archivada'] != true;
        case _CommFilter.leidos:
          return c['leida'] == true && c['archivada'] != true;
        case _CommFilter.importantes:
          return c['importante'] == true && c['archivada'] != true;
        case _CommFilter.archivados:
          return c['archivada'] == true;
      }
    }).toList();
  }

  List<dynamic> get _filteredStudents {
    if (_studentQuery.isEmpty) return _students;
    return _students.where((s) {
      final name = (s['nombre_completo'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(_studentQuery) || email.contains(_studentQuery);
    }).toList();
  }

  Future<void> _toggleImportant(Map comm) async {
    final id = comm['id'];
    final next = !(comm['importante'] == true);
    try {
      await _supabase.from('comunicaciones').update({'importante': next}).eq('id', id);
      _fetchCommunications();
    } catch (e) {
      _showError('No se pudo actualizar: $e');
    }
  }

  Future<void> _toggleArchived(Map comm) async {
    final id = comm['id'];
    final next = !(comm['archivada'] == true);
    try {
      await _supabase.from('comunicaciones').update({'archivada': next}).eq('id', id);
      _fetchCommunications();
    } catch (e) {
      _showError('No se pudo actualizar: $e');
    }
  }

  Future<void> _markAsRead(Map comm) async {
    final id = comm['id'];
    try {
      await _supabase.from('comunicaciones').update({'leida': true}).eq('id', id);
      _fetchCommunications();
    } catch (_) {}
  }

  Future<void> _deleteCommunication(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Mensaje'),
        content: const Text('¿Estás seguro de que deseas eliminar este mensaje?'),
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
        await _supabase.from('comunicaciones').delete().eq('id', id);
        RefreshNotifier.notifyAdmin();
        _fetchCommunications();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mensaje eliminado'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        _showError('Error al eliminar: $e');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _showCreateDialog({Map<String, dynamic>? targetStudent}) {
    final asuntoController = TextEditingController();
    final contenidoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedGrupo = targetStudent != null ? 'clase_especifica' : 'todos';
    bool marcarImportante = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(targetStudent != null
              ? 'Mensaje a ${targetStudent['nombre_completo'] ?? 'estudiante'}'
              : 'Nuevo Mensaje General'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: asuntoController,
                    decoration: const InputDecoration(labelText: 'Asunto'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: contenidoController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Contenido del Mensaje'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  if (targetStudent == null)
                    DropdownButtonFormField<String>(
                      initialValue: selectedGrupo,
                      decoration: const InputDecoration(labelText: 'Destinatarios'),
                      items: const [
                        DropdownMenuItem(value: 'todos', child: Text('Todos')),
                        DropdownMenuItem(value: 'profesores', child: Text('Profesores')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedGrupo = v);
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo para: ${targetStudent['nombre_completo'] ?? targetStudent['email'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: marcarImportante,
                    onChanged: (v) => setDialogState(() => marcarImportante = v ?? false),
                    title: const Text('Marcar como importante', style: TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final currentUser = _supabase.auth.currentUser;
                if (currentUser == null) return;

                try {
                  final payload = <String, dynamic>{
                    'asunto': asuntoController.text,
                    'contenido': contenidoController.text,
                    'autor_id': currentUser.id,
                    'grupo_destinatario': selectedGrupo,
                    'tipo': 'general',
                    'importante': marcarImportante,
                  };
                  if (targetStudent != null) {
                    payload['usuario_id'] = targetStudent['id'];
                  }
                  await _supabase.from('comunicaciones').insert(payload);
                  RefreshNotifier.notifyAdmin();
                  RefreshNotifier.notifyClient();
                  if (context.mounted) {
                    Navigator.pop(context);
                    _fetchCommunications();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mensaje enviado'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  int _countFor(_CommFilter f) {
    return _communications.where((c) {
      switch (f) {
        case _CommFilter.todos:
          return c['archivada'] != true;
        case _CommFilter.noLeidos:
          return c['leida'] != true && c['archivada'] != true;
        case _CommFilter.leidos:
          return c['leida'] == true && c['archivada'] != true;
        case _CommFilter.importantes:
          return c['importante'] == true && c['archivada'] != true;
        case _CommFilter.archivados:
          return c['archivada'] == true;
      }
    }).length;
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
              child: const Row(
                children: [
                  Expanded(
                    child: Text('Comunicaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            // Filtros
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(_CommFilter.todos, 'Todos'),
                    _buildFilterChip(_CommFilter.noLeidos, 'No leídos'),
                    _buildFilterChip(_CommFilter.leidos, 'Leídos'),
                    _buildFilterChip(_CommFilter.importantes, 'Importantes'),
                    _buildFilterChip(_CommFilter.archivados, 'Archivados'),
                  ],
                ),
              ),
            ),
            // Toggle estudiantes
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                onTap: () => setState(() => _showStudents = !_showStudents),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Enviar mensaje personalizado a un estudiante (${_students.length})',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      const Spacer(),
                      Icon(
                        _showStudents ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showStudents) _buildStudentsPanel(),
            // Lista de mensajes
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(child: _buildCommunicationsList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(),
        backgroundColor: AppColors.primary,
        tooltip: 'Nuevo Mensaje a Todos',
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildFilterChip(_CommFilter f, String label) {
    final selected = _filter == f;
    final count = _countFor(f);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.backgroundLight,
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildStudentsPanel() {
    final list = _filteredStudents;
    return Container(
      color: AppColors.white,
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _studentSearchController,
            decoration: InputDecoration(
              hintText: 'Buscar estudiante...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
              filled: true,
              fillColor: AppColors.backgroundLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('No hay estudiantes',
                        style: TextStyle(color: AppColors.textTertiary)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i] as Map<String, dynamic>;
                      final name = s['nombre_completo'] ?? 'Sin nombre';
                      final email = s['email'] ?? '';
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.chipBackground,
                          backgroundImage: (s['avatar_url'] != null &&
                                  s['avatar_url'].toString().isNotEmpty)
                              ? NetworkImage(s['avatar_url'])
                              : null,
                          child: (s['avatar_url'] == null ||
                                  s['avatar_url'].toString().isEmpty)
                              ? Text(
                                  name.toString().isNotEmpty
                                      ? name.toString()[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(email,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textTertiary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, size: 18, color: AppColors.primary),
                          tooltip: 'Enviar mensaje',
                          onPressed: () => _showCreateDialog(targetStudent: s),
                        ),
                        onTap: () => _showCreateDialog(targetStudent: s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationsList() {
    final list = _filteredCommunications;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mail_outline, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _filter == _CommFilter.archivados
                  ? 'No hay mensajes archivados'
                  : _filter == _CommFilter.leidos
                      ? 'No hay mensajes leídos'
                      : _filter == _CommFilter.noLeidos
                          ? 'No hay mensajes sin leer'
                          : _filter == _CommFilter.importantes
                              ? 'No hay mensajes importantes'
                              : 'No hay mensajes',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final comm = list[index] as Map<String, dynamic>;
          return _buildCommCard(comm);
        },
      ),
    );
  }

  Widget _buildCommCard(Map<String, dynamic> comm) {
    final title = comm['asunto'] ?? 'Sin asunto';
    final msg = comm['contenido'] ?? '';
    final date = comm['created_at'] != null ? _formatDate(comm['created_at']) : '';
    final autor = comm['autor']?['nombre_completo'] ?? 'Admin';
    final destinatario = comm['destinatario']?['nombre_completo'];
    final grupo = (comm['grupo_destinatario'] ?? 'todos').toString();
    final isImportante = comm['importante'] == true;
    final isArchivada = comm['archivada'] == true;
    final isLeida = comm['leida'] == true;
    final tipo = comm['tipo']?.toString();

    String grupoLabel;
    if (grupo == 'clase_especifica') {
      grupoLabel = destinatario != null ? 'A: $destinatario' : 'PERSONAL';
    } else {
      grupoLabel = grupo.toUpperCase();
    }

    Color tipoColor = AppColors.primary;
    if (tipo == 'cancelacion') tipoColor = AppColors.error;
    if (tipo == 'clase_creada') tipoColor = AppColors.success;

    return GestureDetector(
      onTap: () {
        if (!isLeida) _markAsRead(comm);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isImportante
                ? AppColors.warning
                : (isLeida ? AppColors.border : AppColors.primary),
            width: isImportante || !isLeida ? 1.2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isImportante)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.star, color: AppColors.warning, size: 18),
                  ),
                if (!isLeida)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isImportante ? Icons.star : Icons.star_border,
                    color: isImportante ? AppColors.warning : AppColors.textTertiary,
                  ),
                  tooltip: isImportante ? 'Quitar importante' : 'Marcar importante',
                  onPressed: () => _toggleImportant(comm),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    isArchivada ? Icons.unarchive_outlined : Icons.archive_outlined,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: isArchivada ? 'Desarchivar' : 'Archivar',
                  onPressed: () => _toggleArchived(comm),
                ),
                IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Eliminar',
                  onPressed: () => _deleteCommunication(comm['id'].toString()),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(msg,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Por: $autor',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tipoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    grupoLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: tipoColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(date,
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }
}
