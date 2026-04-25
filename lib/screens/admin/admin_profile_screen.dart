import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../widgets/avatar_picker.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  String _telefono = '';
  String _rango = '';
  String _sedeStaff = '';
  String? _avatarUrl;
  DateTime? _antiguedad;

  @override
  void initState() {
    super.initState();
    _fetch();
    RefreshNotifier.adminRefresh.addListener(_fetch);
  }

  @override
  void dispose() {
    RefreshNotifier.adminRefresh.removeListener(_fetch);
    super.dispose();
  }

  Future<void> _fetch() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final p = await _supabase.from('perfiles').select().eq('id', user.id).single();
      if (mounted) {
        setState(() {
          _name = p['nombre_completo'] ?? 'Sin Nombre';
          _email = user.email ?? '';
          _telefono = p['telefono'] ?? 'No especificado';
          _rango = p['rango'] ?? 'Administrador';
          _sedeStaff = p['sede_staff'] ?? 'Sede principal';
          _avatarUrl = p['avatar_url'];
          if (p['antiguedad'] != null) {
            _antiguedad = DateTime.tryParse(p['antiguedad']);
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _antiguedadText() {
    if (_antiguedad == null) return 'No especificado';
    final now = DateTime.now();
    final diffDays = now.difference(_antiguedad!).inDays;
    final years = diffDays ~/ 365;
    final months = (diffDays % 365) ~/ 30;
    if (years > 0) {
      return '$years año${years > 1 ? 's' : ''}${months > 0 ? ' y $months mes${months > 1 ? 'es' : ''}' : ''}';
    }
    if (months > 0) return '$months mes${months > 1 ? 'es' : ''}';
    return '$diffDays días';
  }

  Future<void> _confirmSignOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Está seguro de salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí')),
        ],
      ),
    );
    if (shouldLogout == true) {
      await _supabase.auth.signOut();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Perfil del Administrador',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: _confirmSignOut,
                      child: const Icon(Icons.logout, size: 24, color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AvatarPicker(
                currentUrl: _avatarUrl,
                onUpdated: (newUrl) {
                  setState(() => _avatarUrl = newUrl);
                  RefreshNotifier.notifyAdmin();
                },
              ),
              const SizedBox(height: 16),
              Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('ADMINISTRADOR',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 20),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildStat(Icons.shield_outlined, _rango, 'Rango')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStat(Icons.business_outlined, _sedeStaff, 'Sede / Staff')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStat(Icons.timer_outlined, _antiguedadText(), 'Antigüedad'),
              ),
              const SizedBox(height: 16),

              // Horario de atención
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.access_time, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text('Horario de atención:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    SizedBox(width: 6),
                    Text('7:00 a. m. – 11:30 p. m.',
                        style: TextStyle(fontSize: 13, color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Editar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/admin/edit-profile');
                      _fetch();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar Perfil',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info de contacto
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoItem(Icons.email_outlined, 'CORREO ELECTRÓNICO', _email),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildInfoItem(Icons.phone_outlined, 'TELÉFONO', _telefono),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Botones admin
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildActionButton(
                      Icons.gavel_outlined,
                      'Reglas del Negocio',
                      'Políticas y normas del gimnasio',
                      () => Navigator.pushNamed(context, '/admin/business-rules'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      Icons.admin_panel_settings_outlined,
                      'Administrar roles',
                      'Cambia roles y asigna permisos',
                      () => Navigator.pushNamed(context, '/admin/roles'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      Icons.settings_outlined,
                      'Configuración general',
                      'Parámetros del gimnasio',
                      () => Navigator.pushNamed(context, '/admin/general-config'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      Icons.headset_mic_outlined,
                      'Centro de soporte',
                      'Información de contacto',
                      () => Navigator.pushNamed(context, '/support'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
