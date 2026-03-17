import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';

class CommunicationsScreen extends StatefulWidget {
  const CommunicationsScreen({super.key});

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _communications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCommunications();
  }

  Future<void> _fetchCommunications() async {
    try {
      final data = await _supabase
          .from('comunicaciones')
          .select('*, autor:perfiles(nombre_completo)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _communications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showCreateDialog() {
    final asuntoController = TextEditingController();
    final contenidoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedGrupo = 'todos';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Mensaje General'),
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
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final currentUser = _supabase.auth.currentUser;
                  if (currentUser == null) return;

                  try {
                    await _supabase.from('comunicaciones').insert({
                      'asunto': asuntoController.text,
                      'contenido': contenidoController.text,
                      'autor_id': currentUser.id,
                      'grupo_destinatario': selectedGrupo,
                      'tipo': 'general',
                    });
                    RefreshNotifier.notifyAdmin();
                    RefreshNotifier.notifyClient(); // In case we want to notify client shell conceptually
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
                    child: Text('Comunicaciones',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _communications.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.mail_outline, size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 16),
                              Text('No hay mensajes', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _communications.length,
                          itemBuilder: (context, index) {
                            final comm = _communications[index];
                            final title = comm['asunto'] ?? 'Sin asunto';
                            final msg = comm['contenido'] ?? '';
                            final date = comm['created_at'] != null ? _formatDate(comm['created_at']) : '';
                            final autor = comm['autor']?['nombre_completo'] ?? 'Admin';
                            final grupo = (comm['grupo_destinatario'] ?? 'todos').toString().toUpperCase();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 0.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                        onPressed: () => _deleteCommunication(comm['id'].toString()),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(msg, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Por: $autor', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          grupo,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        tooltip: 'Nuevo Mensaje',
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }
}
