import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import '../../widgets/avatar_picker.dart';
import 'client_shell.dart';

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
  String? _avatarUrl;
  double? _peso;
  double? _talla;
  int? _edad;
  List<dynamic> _recentBookings = [];
  List<Map<String, dynamic>> _instructoresFavoritos = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    RefreshNotifier.clientRefresh.addListener(_onRefresh);
  }

  void _onRefresh() => _fetchProfile();

  @override
  void dispose() {
    RefreshNotifier.clientRefresh.removeListener(_onRefresh);
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

      List<dynamic> bookings = [];
      try {
        bookings = await _supabase
            .from('reservas')
            .select('*, clase:clases(nombre, fecha, hora_inicio, precio)')
            .eq('usuario_id', user.id)
            .order('created_at', ascending: false)
            .limit(3);
      } catch (_) {}

      // Instructores favoritos: instructores con reservas confirmadas del cliente
      List<Map<String, dynamic>> instructores = [];
      try {
        final reservasConfirmadas = await _supabase
            .from('reservas')
            .select('clase:clases(instructor_id, instructor:perfiles(id, nombre_completo, especialidad, avatar_url))')
            .eq('usuario_id', user.id)
            .eq('estado', 'confirmada');

        final seen = <String>{};
        for (final r in reservasConfirmadas) {
          final clase = r['clase'];
          if (clase == null) continue;
          final inst = clase['instructor'];
          if (inst == null) continue;
          final id = inst['id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) continue;
          seen.add(id);
          instructores.add({
            'id': id,
            'nombre': inst['nombre_completo'] ?? 'Instructor',
            'especialidad': inst['especialidad'] ?? 'Instructor',
            'avatar_url': inst['avatar_url'],
          });
          if (instructores.length >= 5) break;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _name = profile['nombre_completo'] ?? 'Sin Nombre';
          _role = profile['rol'] ?? 'cliente';
          _email = user.email ?? '';
          _telefono = profile['telefono'] ?? 'No especificado';
          _tipoMembresia = profile['tipo_membresia'] ?? 'basica';
          _avatarUrl = profile['avatar_url'];
          _peso = profile['peso'] != null ? (profile['peso'] as num).toDouble() : null;
          _talla = profile['talla'] != null ? (profile['talla'] as num).toDouble() : null;
          _edad = profile['edad'] as int?;
          _recentBookings = bookings;
          _instructoresFavoritos = instructores;
          _isLoading = false;
        });
      }
    } catch (e) {
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
              // Header
              Container(
                color: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        final shellState = context.findAncestorStateOfType<ClientShellState>();
                        if (shellState != null) shellState.openDrawer();
                      },
                      child: const Icon(Icons.menu, size: 24),
                    ),
                    const Expanded(
                      child: Text('Perfil del Cliente',
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

              // Avatar
              AvatarPicker(
                currentUrl: _avatarUrl,
                onUpdated: (newUrl) {
                  setState(() => _avatarUrl = newUrl);
                  RefreshNotifier.notifyClient();
                },
              ),
              const SizedBox(height: 16),
              Text(_name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Rol: ${_role.toUpperCase()}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Membresía: ${_tipoMembresia.toUpperCase()}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              const SizedBox(height: 20),

              // Tarjetas rápidas Peso / Talla / Edad
              if (_peso != null || _talla != null || _edad != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      if (_peso != null)
                        Expanded(child: _buildStatCard(Icons.monitor_weight_outlined, '${_peso!.toStringAsFixed(1)} kg', 'Peso')),
                      if (_peso != null && (_talla != null || _edad != null))
                        const SizedBox(width: 12),
                      if (_talla != null)
                        Expanded(child: _buildStatCard(Icons.height, '${_talla!.toStringAsFixed(0)} cm', 'Talla')),
                      if (_talla != null && _edad != null)
                        const SizedBox(width: 12),
                      if (_edad != null)
                        Expanded(child: _buildStatCard(Icons.cake_outlined, '$_edad años', 'Edad')),
                    ],
                  ),
                ),
              if (_peso != null || _talla != null || _edad != null)
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

              // Editar Perfil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/editProfile');
                      _fetchProfile();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar Perfil',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Información de contacto
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

              // Instructores favoritos
              if (_instructoresFavoritos.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: const [
                      Icon(Icons.star, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text('Instructores Favoritos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _instructoresFavoritos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final inst = _instructoresFavoritos[index];
                      final hasAvatar = inst['avatar_url'] != null && inst['avatar_url'].toString().isNotEmpty;
                      return Container(
                        width: 90,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 0.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.chipBackground,
                              backgroundImage: hasAvatar ? NetworkImage(inst['avatar_url']) : null,
                              child: !hasAvatar
                                  ? const Icon(Icons.person, size: 26, color: AppColors.primary)
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              inst['nombre'].toString().split(' ').first,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Reservas Recientes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Reservas Recientes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: () {
                        final shellState = context.findAncestorStateOfType<ClientShellState>();
                        if (shellState != null) shellState.switchTab(2);
                      },
                      child: const Text('Ver Todo',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                          child: Text('No tienes reservas aún',
                              style: TextStyle(color: AppColors.textSecondary)),
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
                            className, '$fecha • $horaInicio', '\$$precio', estado, statusColor);
                      }).toList(),
                    ),
              const SizedBox(height: 28),

              // Botones de acción
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildActionButton(
                      Icons.notifications_outlined,
                      'Notificaciones',
                      'Gestiona tus preferencias de avisos',
                      () => Navigator.pushNamed(context, '/client/notifications-settings'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      Icons.lock_outlined,
                      'Privacidad y seguridad',
                      'Contraseña y protección de datos',
                      () => Navigator.pushNamed(context, '/client/privacy-security'),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      Icons.headset_mic_outlined,
                      'Centro de soporte',
                      'Contáctanos si necesitas ayuda',
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              textAlign: TextAlign.center),
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
                  Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
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
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildBookingItem(
      String name, String date, String price, String status, Color statusColor) {
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
            child: const Center(
                child: Icon(Icons.fitness_center, color: AppColors.primary, size: 24)),
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
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
          ),
          Text(price,
              style: TextStyle(
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
