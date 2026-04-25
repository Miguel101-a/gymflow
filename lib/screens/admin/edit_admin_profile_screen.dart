import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EditAdminProfileScreen extends StatefulWidget {
  const EditAdminProfileScreen({super.key});

  @override
  State<EditAdminProfileScreen> createState() => _EditAdminProfileScreenState();
}

class _EditAdminProfileScreenState extends State<EditAdminProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final p = await _supabase.from('perfiles').select().eq('id', user.id).single();
      if (mounted) {
        setState(() {
          _nameController.text = p['nombre_completo'] ?? '';
          _emailController.text = user.email ?? '';
          _phoneController.text = p['telefono'] ?? '';
          _avatarUrl = p['avatar_url'];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío'), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _supabase.from('perfiles').update({
        'nombre_completo': _nameController.text.trim(),
        'telefono': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      RefreshNotifier.notifyAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
                    const Expanded(
                      child: Text('Editar Perfil',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 24),
              AvatarPicker(
                currentUrl: _avatarUrl,
                onUpdated: (newUrl) {
                  setState(() => _avatarUrl = newUrl);
                  RefreshNotifier.notifyAdmin();
                },
              ),
              const SizedBox(height: 8),
              const Text('Cambiar Foto de Perfil',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    CustomTextField(
                      label: 'Nombre Completo',
                      hintText: 'Tu nombre',
                      prefixIcon: Icons.person_outline,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Correo Electrónico',
                      hintText: '',
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      enabled: false,
                      helperText: 'El correo no se puede cambiar desde aquí',
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Número de Teléfono',
                      hintText: '+591 6XXXXXXX',
                      prefixIcon: Icons.phone_outlined,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rango, Sede/Staff y Antigüedad solo se modifican desde "Administrar roles".',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(text: 'Actualizar Perfil', onPressed: _save),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 14)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
