import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../widgets/avatar_picker.dart';

class InstructorProfileScreen extends StatefulWidget {
  const InstructorProfileScreen({super.key});

  @override
  State<InstructorProfileScreen> createState() => _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  String _telefono = '';
  String _especialidad = '';
  String? _avatarUrl;
  double _rating = 0;
  int _clientesActivos = 0;
  int _clasesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    RefreshNotifier.adminRefresh.addListener(_fetchProfile);
  }

  @override
  void dispose() {
    RefreshNotifier.adminRefresh.removeListener(_fetchProfile);
    super.dispose();
  }

  Future<void> _fetchProfile() async {
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

      // Clases del instructor
      List<dynamic> clases = [];
      try {
        clases = await _supabase
            .from('clases')
            .select('id')
            .eq('instructor_id', user.id);
      } catch (_) {}

      // Clientes activos: reservas confirmadas en mis clases (únicos)
      int clientesActivos = 0;
      try {
        if (clases.isNotEmpty) {
          final classIds = clases.map((c) => c['id']).toList();
          final reservas = await _supabase
              .from('reservas')
              .select('usuario_id')
              .inFilter('clase_id', classIds)
              .eq('estado', 'confirmada');
          final unique = <String>{};
          for (final r in reservas) {
            final uid = r['usuario_id']?.toString();
            if (uid != null) unique.add(uid);
          }
          clientesActivos = unique.length;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _name = profile['nombre_completo'] ?? 'Sin Nombre';
          _email = user.email ?? '';
          _telefono = profile['telefono'] ?? 'No especificado';
          _especialidad = profile['especialidad'] ?? 'Sin especificar';
          _avatarUrl = profile['avatar_url'];
          _rating = profile['rating'] != null ? (profile['rating'] as num).toDouble() : 0;
          _clientesActivos = clientesActivos;
          _clasesCount = clases.length;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      child: Text('Perfil del Instructor',
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
              const Text('INSTRUCTOR',
                  style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) {
                    final filled = i < _rating.round();
                    return Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 20,
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(_rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 20),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(child: _buildStatCard(Icons.fitness_center, '$_clasesCount', 'Mis clases')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard(Icons.people_outline, '$_clientesActivos', 'Clientes activos')),
                  ],
                ),
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

              // Edit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/instructor/edit-profile');
                      _fetchProfile();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar Perfil',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Info
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
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildInfoItem(Icons.workspace_premium_outlined, 'ESPECIALIDAD', _especialidad),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Soporte
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/support'),
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
                          child: const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Centro de soporte',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              SizedBox(height: 2),
                              Text('Contáctanos si necesitas ayuda',
                                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              textAlign: TextAlign.center),
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
}
