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

class _ReservationsScreenState extends State<ReservationsScreen> with SingleTickerProviderStateMixin {
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

  void _onRefresh() {
    _fetchReservations();
  }

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

      // Sort reservations by class date and time
      final sortedReservations = List<dynamic>.from(reservations);
      sortedReservations.sort((a, b) {
        final claseA = a['clase'] ?? {};
        final claseB = b['clase'] ?? {};
        final fechaA = claseA['fecha']?.toString() ?? '';
        final horaA = claseA['hora_inicio']?.toString() ?? '';
        final fechaB = claseB['fecha']?.toString() ?? '';
        final horaB = claseB['hora_inicio']?.toString() ?? '';
        
        // Pad hours effectively to be parseable or compare lexicographically
        final dtA = DateTime.tryParse('$fechaA $horaA') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse('$fechaB $horaB') ?? DateTime.fromMillisecondsSinceEpoch(0);
        
        return dtA.compareTo(dtB); // Ascending for upcoming
      });

      for (final r in sortedReservations) {
        final estado = r['estado'] ?? '';
        if (estado == 'confirmada' || estado == 'lista_de_espera') {
          upcoming.add(r);
        } else {
          past.add(r);
        }
      }
      
      // Past reservations should ideally be newest first (descending)
      past.sort((a, b) {
        final claseA = a['clase'] ?? {};
        final claseB = b['clase'] ?? {};
        final fechaA = claseA['fecha']?.toString() ?? '';
        final horaA = claseA['hora_inicio']?.toString() ?? '';
        final fechaB = claseB['fecha']?.toString() ?? '';
        final horaB = claseB['hora_inicio']?.toString() ?? '';
        
        final dtA = DateTime.tryParse('$fechaA $horaA') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse('$fechaB $horaB') ?? DateTime.fromMillisecondsSinceEpoch(0);
        
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

  Future<void> _cancelReservation(String reservationId) async {
    try {
      await _supabase
          .from('reservas')
          .update({'estado': 'cancelada', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', reservationId);

      RefreshNotifier.notifyClient();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva cancelada'), backgroundColor: AppColors.success),
        );
        _fetchReservations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: AppColors.error),
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
                    child: Text('Mis Reservas', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            // Tabs
            Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                tabs: const [
                  Tab(text: 'Próximas'),
                  Tab(text: 'Pasadas'),
                ],
              ),
            ),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReservationList(_upcomingReservations, isUpcoming: true),
                        _buildReservationList(_pastReservations, isUpcoming: false),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationList(List<dynamic> reservations, {required bool isUpcoming}) {
    if (reservations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isUpcoming ? Icons.calendar_today_outlined : Icons.history, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              isUpcoming ? 'No tienes reservas próximas' : 'No hay reservas pasadas',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
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
        final instructor = clase['instructor']?['nombre_completo'] ?? 'Instructor';
        final fecha = clase['fecha']?.toString() ?? '';
        final horaInicio = clase['hora_inicio']?.toString() ?? '';
        final ubicacion = clase['ubicacion'] ?? 'Por definir';
        final estado = (reservation['estado'] ?? '').toString().toUpperCase();
        
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
            statusLabel = estado;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildReservationCard(
            context,
            reservation,
            nombre,
            '$fecha • $horaInicio',
            ubicacion,
            instructor,
            statusLabel,
            statusColor,
            isUpcoming: isUpcoming,
          ),
        );
      },
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    dynamic reservation,
    String title,
    String dateTime,
    String location,
    String instructor,
    String status,
    Color statusColor, {
    required bool isUpcoming,
  }) {
    final clase = reservation['clase'] ?? {};

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder
          Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Center(child: Icon(Icons.self_improvement, size: 48, color: AppColors.primary)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(dateTime, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(location, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Instructor: $instructor', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/classDetail',
                          arguments: clase,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Ver Detalles', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    if (isUpcoming) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _cancelReservation(reservation['id']),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Cancelar', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
