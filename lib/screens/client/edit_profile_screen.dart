import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _pesoController;
  late TextEditingController _tallaController;
  late TextEditingController _edadController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _pesoController = TextEditingController();
    _tallaController = TextEditingController();
    _edadController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pesoController.dispose();
    _tallaController.dispose();
    _edadController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await _supabase
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _nameController.text = profile['nombre_completo'] ?? '';
          _emailController.text = user.email ?? '';
          _phoneController.text = profile['telefono'] ?? '';
          _pesoController.text = profile['peso'] != null ? profile['peso'].toString() : '';
          _tallaController.text = profile['talla'] != null ? profile['talla'].toString() : '';
          _edadController.text = profile['edad'] != null ? profile['edad'].toString() : '';
          _avatarUrl = profile['avatar_url'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El nombre no puede estar vacío'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final pesoText = _pesoController.text.trim();
    final tallaText = _tallaController.text.trim();
    final edadText = _edadController.text.trim();

    final double? peso = pesoText.isNotEmpty ? double.tryParse(pesoText) : null;
    final double? talla = tallaText.isNotEmpty ? double.tryParse(tallaText) : null;
    final int? edad = edadText.isNotEmpty ? int.tryParse(edadText) : null;

    if (pesoText.isNotEmpty && peso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peso inválido'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (tallaText.isNotEmpty && talla == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Talla inválida'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (edadText.isNotEmpty && edad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edad inválida'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabase.from('perfiles').update({
        'nombre_completo': _nameController.text.trim(),
        'telefono':
            _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'peso': peso,
        'talla': talla,
        'edad': edad,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      RefreshNotifier.notifyClient();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil actualizado exitosamente'),
              backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: AppColors.error),
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
              // Header
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
                  RefreshNotifier.notifyClient();
                },
              ),
              const SizedBox(height: 8),
              const Text('Cambiar Foto de Perfil',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      label: 'Nombre Completo',
                      hintText: 'Ingresa tu nombre completo',
                      prefixIcon: Icons.person_outline,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Correo Electrónico',
                      hintText: 'tu@email.com',
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
                    const SizedBox(height: 28),
                    const Text('Datos físicos',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Opcionales — se muestran como tarjetas en tu perfil',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Peso (kg)',
                            hintText: '70',
                            prefixIcon: Icons.monitor_weight_outlined,
                            controller: _pesoController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            label: 'Talla (cm)',
                            hintText: '175',
                            prefixIcon: Icons.height,
                            controller: _tallaController,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Edad (años)',
                      hintText: '25',
                      prefixIcon: Icons.cake_outlined,
                      controller: _edadController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 40),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(text: 'Actualizar Perfil', onPressed: _saveProfile),
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
