import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

const _supabaseUrl = 'https://contgdzeveppbqnttfqo.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvbnRnZHpldmVwcGJxbnR0ZnFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0OTQzNjMsImV4cCI6MjA4ODA3MDM2M30.tFoE5M_-wkeNkelIbO214Dm39TjbAzobO5Eb9lbrK4E';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _students.where((s) {
        final name = (s['nombre_completo'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    try {
      final data = await _supabase
          .from('perfiles')
          .select()
          .eq('rol', 'cliente')
          .order('nombre_completo', ascending: true);

      if (mounted) {
        setState(() {
          _students = data;
          _filteredStudents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateStudentDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final passConfirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;
    bool obscurePass = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Crear cuenta de cliente')),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Email inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Contraseña *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setDialog(() => obscurePass = !obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passConfirmCtrl,
                    obscureText: obscurePass,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña *',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v != passCtrl.text) return 'No coincide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'El cliente podrá iniciar sesión con estos datos.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => isCreating = true);
                      final ok = await _createStudentAccount(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        password: passCtrl.text,
                      );
                      if (!mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                        _fetchStudents();
                      } else {
                        setDialog(() => isCreating = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Crear cuenta',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// Crea la cuenta usando una instancia temporal de SupabaseClient para que
  /// la sesión del admin actual no se vea afectada.
  Future<bool> _createStudentAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    SupabaseClient? tempClient;
    try {
      tempClient = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      final res = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {'nombre_completo': name},
      );
      final newUser = res.user;
      if (newUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No se pudo crear el usuario. Es posible que el email ya exista.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return false;
      }

      // Upsert del perfil con datos completos. Si un trigger ya creó el perfil
      // con valores por defecto, este upsert los completa.
      try {
        await tempClient.from('perfiles').upsert({
          'id': newUser.id,
          'nombre_completo': name,
          'email': email,
          'telefono': phone.isEmpty ? null : phone,
          'rol': 'cliente',
        });
      } catch (_) {
        // Si la inserción del perfil falla por RLS, intentamos al menos
        // actualizar desde la sesión admin global.
        try {
          await _supabase.from('perfiles').upsert({
            'id': newUser.id,
            'nombre_completo': name,
            'email': email,
            'telefono': phone.isEmpty ? null : phone,
            'rol': 'cliente',
          });
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta creada para $name'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return true;
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear cuenta: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    } finally {
      try {
        await tempClient?.dispose();
      } catch (_) {}
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
                    child: Text('Gestión de Estudiantes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('Total: ${_students.length}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Search bar
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar estudiantes (nombre, email)...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // List
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _filteredStudents.isEmpty
                    ? const Expanded(child: Center(child: Text('No se encontraron estudiantes')))
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchStudents,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final name = student['nombre_completo'] ?? 'Sin nombre';
                              final email = student['email'] ?? '';
                              final phone = student['telefono'] ?? 'Sin teléfono';
                              final membership = student['tipo_membresia'] ?? 'basica';

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
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.chipBackground,
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text(email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                          const SizedBox(height: 2),
                                          Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        membership.toString().toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateStudentDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Crear cuenta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
