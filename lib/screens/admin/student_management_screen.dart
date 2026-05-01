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
  Set<String> _suspendedIds = {};
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

      Set<String> suspended = {};
      try {
        final statuses = await _supabase.rpc('admin_list_client_status');
        if (statuses is List) {
          for (final s in statuses) {
            if (s is Map && s['suspended'] == true && s['user_id'] != null) {
              suspended.add(s['user_id'].toString());
            }
          }
        }
      } catch (_) {
        // Si la RPC no existe todavía, simplemente todos aparecen como activos
      }

      if (mounted) {
        setState(() {
          _students = data;
          _filteredStudents = data;
          _suspendedIds = suspended;
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
    bool sendConfirmationEmail = false;

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
                  CheckboxListTile(
                    value: sendConfirmationEmail,
                    onChanged: (v) =>
                        setDialog(() => sendConfirmationEmail = v ?? false),
                    title: const Text(
                      'Enviar email de confirmación al cliente',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      sendConfirmationEmail
                          ? 'El cliente recibirá un correo y deberá confirmar antes de iniciar sesión.'
                          : 'La cuenta quedará lista para usar inmediatamente (sin email).',
                      style: const TextStyle(fontSize: 11),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sendConfirmationEmail
                                ? 'Pasa las credenciales al cliente y pídele que confirme su correo.'
                                : 'Entrega las credenciales al cliente; podrá iniciar sesión de inmediato.',
                            style: const TextStyle(
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
                        sendConfirmationEmail: sendConfirmationEmail,
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

  /// Crea cuenta de cliente. Si [sendConfirmationEmail] es true, usa el flujo
  /// estándar de signUp() (el cliente recibe email de confirmación). Si es
  /// false, invoca la función RPC `admin_create_client_confirmed` que crea la
  /// cuenta ya confirmada (solo admin puede ejecutarla).
  Future<bool> _createStudentAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
    required bool sendConfirmationEmail,
  }) async {
    if (sendConfirmationEmail) {
      return _createWithConfirmationEmail(
          name: name, email: email, phone: phone, password: password);
    }
    return _createAutoConfirmed(
        name: name, email: email, phone: phone, password: password);
  }

  /// Flujo con email de confirmación: usa una instancia temporal de
  /// SupabaseClient para no afectar la sesión del admin.
  Future<bool> _createWithConfirmationEmail({
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

      try {
        await tempClient.from('perfiles').upsert({
          'id': newUser.id,
          'nombre_completo': name,
          'email': email,
          'telefono': phone.isEmpty ? null : phone,
          'rol': 'cliente',
        });
      } catch (_) {
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
            content: Text('Email de confirmación enviado a $email'),
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

  /// Flujo auto-confirmado: invoca la función RPC SECURITY DEFINER que crea
  /// el usuario en auth.users con email_confirmed_at ya seteado. Solo admins
  /// pueden invocarla (la función valida el rol del invocador).
  Future<bool> _createAutoConfirmed({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      await _supabase.rpc('admin_create_client_confirmed', params: {
        'p_email': email,
        'p_password': password,
        'p_nombre_completo': name,
        'p_telefono': phone.isEmpty ? null : phone,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cuenta lista para $name. Ya puede iniciar sesión.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return true;
    } on PostgrestException catch (e) {
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
    }
  }

  void _handleAction(String action, Map<String, dynamic> student, bool isSuspended) {
    switch (action) {
      case 'reset_password':
        _showResetPasswordDialog(student);
        break;
      case 'edit':
        _showEditDataDialog(student);
        break;
      case 'toggle_suspend':
        _confirmToggleSuspend(student, isSuspended);
        break;
      case 'delete':
        _confirmDelete(student);
        break;
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.success),
    );
  }

  Future<void> _showResetPasswordDialog(Map<String, dynamic> student) async {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscure = true;
    final name = student['nombre_completo'] ?? 'cliente';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.key, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Resetear contraseña — $name')),
          ]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialog(() => obscure = !obscure),
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
                  controller: confirmCtrl,
                  obscureText: obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar *',
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
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pasa la nueva contraseña al cliente para que pueda iniciar sesión.',
                        style: TextStyle(fontSize: 11, color: AppColors.primary),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => isLoading = true);
                      try {
                        await _supabase
                            .rpc('admin_reset_client_password', params: {
                          'p_user_id': student['id'],
                          'p_new_password': passCtrl.text,
                        });
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('Contraseña actualizada para $name');
                      } on PostgrestException catch (e) {
                        setDialog(() => isLoading = false);
                        _showError('Error: ${e.message}');
                      } catch (e) {
                        setDialog(() => isLoading = false);
                        _showError('Error: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Actualizar',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDataDialog(Map<String, dynamic> student) async {
    final nameCtrl =
        TextEditingController(text: student['nombre_completo'] ?? '');
    final emailCtrl = TextEditingController(text: student['email'] ?? '');
    final phoneCtrl = TextEditingController(text: student['telefono'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.edit_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Editar datos del cliente')),
          ]),
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
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          size: 14, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Estos cambios no afectan el email de inicio de sesión en auth.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialog(() => isLoading = true);
                      try {
                        final updated = await _supabase
                            .from('perfiles')
                            .update({
                              'nombre_completo': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'telefono': phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                            })
                            .eq('id', student['id'])
                            .select('id')
                            .maybeSingle();
                        if (updated == null) {
                          setDialog(() => isLoading = false);
                          _showError(
                              'No se pudo guardar (RLS rechazó la operación).');
                          return;
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('Datos actualizados');
                        _fetchStudents();
                      } on PostgrestException catch (e) {
                        setDialog(() => isLoading = false);
                        _showError('Error: ${e.message}');
                      } catch (e) {
                        setDialog(() => isLoading = false);
                        _showError('Error: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmToggleSuspend(
      Map<String, dynamic> student, bool isSuspended) async {
    final name = student['nombre_completo'] ?? 'cliente';
    final action = isSuspended ? 'reactivar' : 'suspender';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSuspended ? 'Reactivar cuenta' : 'Suspender cuenta'),
        content: Text(
          isSuspended
              ? '¿Reactivar la cuenta de $name? Podrá iniciar sesión nuevamente.'
              : '¿Suspender la cuenta de $name? No podrá iniciar sesión hasta que la reactives.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSuspended ? AppColors.success : AppColors.warning,
            ),
            child: Text(isSuspended ? 'Reactivar' : 'Suspender',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabase.rpc('admin_set_client_active', params: {
        'p_user_id': student['id'],
        'p_active': isSuspended, // si estaba suspendido => reactivar (true)
      });
      _showSuccess('Cuenta ${isSuspended ? "reactivada" : "suspendida"}: $name');
      _fetchStudents();
    } on PostgrestException catch (e) {
      _showError('No se pudo $action: ${e.message}');
    } catch (e) {
      _showError('Error al $action: $e');
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> student) async {
    final name = student['nombre_completo'] ?? 'cliente';
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Expanded(child: Text('Eliminar permanentemente')),
          ]),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Vas a eliminar permanentemente a $name junto con sus reservas, mensajes y pagos asociados.'),
                const SizedBox(height: 8),
                const Text(
                  'Esta acción es irreversible.',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.error),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Escribe ELIMINAR para confirmar',
                  ),
                  validator: (v) =>
                      (v ?? '').trim().toUpperCase() == 'ELIMINAR'
                          ? null
                          : 'Debes escribir ELIMINAR',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx, true);
                    },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabase.rpc('admin_delete_client', params: {
        'p_user_id': student['id'],
      });
      _showSuccess('Cuenta eliminada: $name');
      _fetchStudents();
    } on PostgrestException catch (e) {
      _showError('No se pudo eliminar: ${e.message}');
    } catch (e) {
      _showError('Error al eliminar: $e');
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
                              final student = _filteredStudents[index] as Map<String, dynamic>;
                              final id = student['id']?.toString();
                              final name = student['nombre_completo'] ?? 'Sin nombre';
                              final email = student['email'] ?? '';
                              final phone = student['telefono'] ?? 'Sin teléfono';
                              final membership = student['tipo_membresia'] ?? 'basica';
                              final isSuspended = id != null && _suspendedIds.contains(id);

                              return Opacity(
                                opacity: isSuspended ? 0.55 : 1,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSuspended
                                          ? AppColors.error.withValues(alpha: 0.4)
                                          : AppColors.border,
                                      width: isSuspended ? 1 : 0.5,
                                    ),
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
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(name,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600)),
                                                ),
                                                if (isSuspended) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.error
                                                          .withValues(alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(4),
                                                    ),
                                                    child: const Text('SUSPENDIDA',
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w700,
                                                            color: AppColors.error)),
                                                  ),
                                                ],
                                              ],
                                            ),
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
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: AppColors.textSecondary),
                                        tooltip: 'Acciones',
                                        onSelected: (action) =>
                                            _handleAction(action, student, isSuspended),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'reset_password',
                                            child: Row(children: [
                                              Icon(Icons.key,
                                                  size: 18, color: AppColors.primary),
                                              SizedBox(width: 10),
                                              Text('Resetear contraseña'),
                                            ]),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18, color: AppColors.primary),
                                              SizedBox(width: 10),
                                              Text('Editar datos'),
                                            ]),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle_suspend',
                                            child: Row(children: [
                                              Icon(
                                                isSuspended
                                                    ? Icons.check_circle_outline
                                                    : Icons.block,
                                                size: 18,
                                                color: isSuspended
                                                    ? AppColors.success
                                                    : AppColors.warning,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(isSuspended ? 'Reactivar' : 'Suspender'),
                                            ]),
                                          ),
                                          const PopupMenuDivider(),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(children: [
                                              Icon(Icons.delete_outline,
                                                  size: 18, color: AppColors.error),
                                              SizedBox(width: 10),
                                              Text('Eliminar permanentemente',
                                                  style: TextStyle(
                                                      color: AppColors.error)),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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
