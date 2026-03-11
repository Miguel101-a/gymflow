import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _name = '';
  String _email = '';
  String _role = '';
  String _telefono = '';
  String _tipoMembresia = '';
  List<dynamic> _recentBookings = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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

      // Fetch recent reservations
      List<dynamic> bookings = [];
      try {
        bookings = await _supabase
            .from('reservas')
            .select('*, clase:clases(nombre, fecha, hora_inicio, precio)')
            .eq('usuario_id', user.id)
            .order('created_at', ascending: false)
            .limit(3);
      } catch (_) {
        // ok if no reservations
      }

      if (mounted) {
        setState(() {
          _name = profile['nombre_completo'] ?? 'Sin Nombre';
          _role = profile['rol'] ?? 'cliente';
          _email = user.email ?? '';
          _telefono = profile['telefono'] ?? 'No especificado';
          _tipoMembresia = profile['tipo_membresia'] ?? 'basica';
          _recentBookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
              // Header
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
                    const Expanded(
                      child: Text('Perfil del Cliente', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: _signOut,
                      child: const Icon(Icons.logout, size: 24, color: AppColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Avatar
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.chipBackground,
                    child: Icon(Icons.person, size: 56, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: AppColors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Rol: ${_role.toUpperCase()}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Membresía: ${_tipoMembresia.toUpperCase()}', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              const SizedBox(height: 20),
              // Edit Profile button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/editProfile');
                      // Refresh profile after editing
                      _fetchProfile();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar Perfil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Contact info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildContactItem(Icons.email_outlined, 'CORREO ELECTRÓNICO', _email),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildContactItem(Icons.phone_outlined, 'TELÉFONO', _telefono),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Recent bookings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reservas Recientes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      child: const Text('Ver Todo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _recentBookings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: const Center(
                          child: Text('No tienes reservas aún', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    )
                  : Column(
                      children: _recentBookings.map((booking) {
                        final clase = booking['clase'] ?? {};
                        final className = clase['nombre'] ?? 'Clase';
                        final fecha = clase['fecha']?.toString() ?? '';
                        final horaInicio = clase['hora_inicio']?.toString() ?? '';
                        final precio = clase['precio']?.toString() ?? '-';
                        final estado = (booking['estado'] ?? 'confirmada').toString().toUpperCase();
                        final statusColor = estado == 'CONFIRMADA'
                            ? AppColors.success
                            : estado == 'CANCELADA'
                                ? AppColors.error
                                : AppColors.warning;

                        return _buildBookingItem(
                          className,
                          '$fecha • $horaInicio',
                          '\$$precio',
                          estado,
                          statusColor,
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
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
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildBookingItem(String name, String date, String price, String status, Color statusColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Icon(Icons.fitness_center, color: AppColors.primary, size: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
          ),
          Text(price, style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: status == 'CANCELADA' ? AppColors.textTertiary : AppColors.textPrimary,
            decoration: status == 'CANCELADA' ? TextDecoration.lineThrough : null,
          )),
        ],
      ),
    );
  }
}
