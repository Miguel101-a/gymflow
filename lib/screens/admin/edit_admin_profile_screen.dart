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
  late TextEditingController _rangoController;
  late TextEditingController _sedeController;
  String? _avatarUrl;
  DateTime? _antiguedad;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _rangoController = TextEditingController();
    _sedeController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _rangoController.dispose();
    _sedeController.dispose();
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
          _rangoController.text = p['rango'] ?? '';
          _sedeController.text = p['sede_staff'] ?? '';
          _avatarUrl = p['avatar_url'];
          if (p['antiguedad'] != null) {
            _antiguedad = DateTime.tryParse(p['antiguedad'].toString());
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAntiguedad() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _antiguedad ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _antiguedad = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
        'rango': _rangoController.text.trim().isEmpty ? null : _rangoController.text.trim(),
        'sede_staff': _sedeController.text.trim().isEmpty ? null : _sedeController.text.trim(),
        'antiguedad': _antiguedad?.toIso8601String().split('T').first,
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
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Rango / Cargo',
                      hintText: 'Ej. Administrador General',
                      prefixIcon: Icons.workspace_premium_outlined,
                      controller: _rangoController,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Sede / Staff',
                      hintText: 'Ej. Sede Central',
                      prefixIcon: Icons.business_outlined,
                      controller: _sedeController,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickAntiguedad,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Antigüedad (fecha de ingreso)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _antiguedad == null
                                        ? 'Toca para elegir fecha'
                                        : _formatDate(_antiguedad!),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _antiguedad == null
                                          ? AppColors.textTertiary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_antiguedad != null)
                              GestureDetector(
                                onTap: () => setState(() => _antiguedad = null),
                                child: const Icon(Icons.close,
                                    size: 18, color: AppColors.textTertiary),
                              ),
                          ],
                        ),
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
