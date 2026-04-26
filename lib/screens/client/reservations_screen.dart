import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import 'client_shell.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  List<dynamic> _upcomingReservations = [];
  List<dynamic> _pastReservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchReservations();
    RefreshNotifier.clientRefresh.addListener(_onRefresh);
  }

  void _onRefresh() => _fetchReservations();

  @override
  void dispose() {
    RefreshNotifier.clientRefresh.removeListener(_onRefresh);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReservations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final reservations = await _supabase
          .from('reservas')
          .select('*, clase:clases(*, instructor:perfiles(nombre_completo))')
          .eq('usuario_id', user.id)
          .order('created_at', ascending: false);

      final upcoming = <dynamic>[];
      final past = <dynamic>[];

      final sorted = List<dynamic>.from(reservations)
        ..sort((a, b) {
          final ca = a['clase'] ?? {};
          final cb = b['clase'] ?? {};
          final dtA = DateTime.tryParse(
                  '${ca['fecha'] ?? ''} ${ca['hora_inicio'] ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dtB = DateTime.tryParse(
                  '${cb['fecha'] ?? ''} ${cb['hora_inicio'] ?? ''}') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return dtA.compareTo(dtB);
        });

      for (final r in sorted) {
        final estado = r['estado'] ?? '';
        if (estado == 'confirmada' || estado == 'lista_de_espera') {
          upcoming.add(r);
        } else {
          past.add(r);
        }
      }

      past.sort((a, b) {
        final ca = a['clase'] ?? {};
        final cb = b['clase'] ?? {};
        final dtA = DateTime.tryParse(
                '${ca['fecha'] ?? ''} ${ca['hora_inicio'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(
                '${cb['fecha'] ?? ''} ${cb['hora_inicio'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      if (mounted) {
        setState(() {
          _upcomingReservations = upcoming;
          _pastReservations = past;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Verificar si aún se puede cancelar (regla de 12 horas) ───────────────
  bool _canCancel(dynamic reservation) {
    final clase = reservation['clase'] ?? {};
    final fechaStr = clase['fecha']?.toString();
    final horaStr = clase['hora_inicio']?.toString();
    if (fechaStr == null || horaStr == null) return true;

    final claseDateTime = DateTime.tryParse('$fechaStr $horaStr');
    if (claseDateTime == null) return true;

    final horasRestantes = claseDateTime.difference(DateTime.now()).inHours;
    return horasRestantes >= 12; // puede cancelar si faltan 12h o más
  }

  // ── Diálogo de confirmación de cancelación ────────────────────────────────
  Future<void> _confirmAndCancel(dynamic reservation) async {
    final clase = reservation['clase'] ?? {};
    final nombreClase = clase['nombre'] ?? 'esta clase';

    // Bloqueo por regla de 12 horas
    if (!_canCancel(reservation)) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block, color: AppColors.error, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('No es posible cancelar',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text(
                  'Solo puedes cancelar tu reserva hasta 12 horas antes del inicio de la clase.',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Entendido',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline,
                    color: Colors.orange, size: 42),
              ),
              const SizedBox(height: 18),
              const Text('¿Cancelar tu reserva?',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                '¿Estás seguro de que deseas cancelar tu asistencia en "$nombreClase"?',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.amber.shade700, size: 16),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('Esta acción no se puede deshacer.',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('No, mantener',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sí, cancelar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _cancelReservation(reservation['id']);
    }
  }

  Future<void> _cancelReservation(String reservationId) async {
    try {
      await _supabase
          .from('reservas')
          .update({
            'estado': 'cancelada',
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', reservationId);

      RefreshNotifier.notifyClient();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reserva cancelada exitosamente'),
              backgroundColor: AppColors.success),
        );
        _fetchReservations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al cancelar: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final shellState =
                          context.findAncestorStateOfType<ClientShellState>();
                      if (shellState != null) shellState.openDrawer();
                    },
                    child: const Icon(Icons.menu, size: 24),
                  ),
                  const Expanded(
                    child: Text('Mis Reservas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter'),
                tabs: const [
                  Tab(text: 'Próximas'),
                  Tab(text: 'Pasadas'),
                ],
              ),
            ),
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(_upcomingReservations, isUpcoming: true),
                        _buildList(_pastReservations, isUpcoming: false),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<dynamic> reservations, {required bool isUpcoming}) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                isUpcoming
                    ? Icons.calendar_today_outlined
                    : Icons.history,
                size: 48,
                color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              isUpcoming
                  ? 'No tienes reservas próximas'
                  : 'No hay reservas pasadas',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reservations.length,
      itemBuilder: (context, index) {
        final reservation = reservations[index];
        final clase = reservation['clase'] ?? {};
        final nombre = clase['nombre'] ?? 'Clase';
        final instructor =
            clase['instructor']?['nombre_completo'] ?? 'Instructor';
        final fecha = clase['fecha']?.toString() ?? '';
        String horaInicio = clase['hora_inicio']?.toString() ?? '';
        if (horaInicio.length > 5) horaInicio = horaInicio.substring(0, 5);
        final ubicacion = clase['ubicacion'] ?? 'Por definir';
        final canCancel = isUpcoming && _canCancel(reservation);

        Color statusColor;
        String statusLabel;
        switch (reservation['estado']) {
          case 'confirmada':
            statusColor = AppColors.success;
            statusLabel = 'CONFIRMADA';
            break;
          case 'lista_de_espera':
            statusColor = AppColors.warning;
            statusLabel = 'LISTA DE ESPERA';
            break;
          case 'cancelada':
            statusColor = AppColors.error;
            statusLabel = 'CANCELADA';
            break;
          case 'completada':
            statusColor = AppColors.primary;
            statusLabel = 'COMPLETADA';
            break;
          default:
            statusColor = AppColors.textSecondary;
            statusLabel =
                reservation['estado']?.toString().toUpperCase() ?? '';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCard(
            context, reservation, clase,
            nombre, '$fecha • $horaInicio', ubicacion, instructor,
            statusLabel, statusColor,
            isUpcoming: isUpcoming,
            canCancel: canCancel,
          ),
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    dynamic reservation,
    dynamic clase,
    String title,
    String dateTime,
    String location,
    String instructor,
    String status,
    Color statusColor, {
    required bool isUpcoming,
    required bool canCancel,
  }) {
    final capacidad = clase['capacidad_maxima'];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Container(
                width: 120,
                color: AppColors.chipBackground,
                child: clase['imagen_url'] != null &&
                        clase['imagen_url'].toString().isNotEmpty
                    ? Image.network(clase['imagen_url'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.fitness_center,
                                size: 36, color: AppColors.primary)))
                    : const Center(
                        child: Icon(Icons.fitness_center,
                            size: 36, color: AppColors.primary)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _infoRow(Icons.calendar_today, dateTime),
                    const SizedBox(height: 4),
                    _infoRow(Icons.location_on_outlined, location),
                    const SizedBox(height: 4),
                    _infoRow(
                        Icons.person_outline, 'Instructor: $instructor'),
                    if (capacidad != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.people_outline,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('$capacidad plazas',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ]),
                      ),
                    ],
                    // Aviso si ya no se puede cancelar
                    if (isUpcoming && !canCancel) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock,
                                size: 13,
                                color:
                                    AppColors.error.withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Ya no es posible cancelar (menos de 12h)',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushNamed(
                                context, '/classDetail',
                                arguments: clase),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Ver Detalles',
                                style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        if (isUpcoming) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _confirmAndCancel(reservation),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                minimumSize: Size.zero,
                                side: BorderSide(
                                  color: canCancel
                                      ? AppColors.error
                                          .withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: canCancel
                                      ? AppColors.error
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 6),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary))),
    ],
  );
}