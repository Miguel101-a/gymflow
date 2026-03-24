import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';

class ClassDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const ClassDetailScreen({super.key, required this.classData});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _bookClass() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debe iniciar sesión para reservar.'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Comprobar si ya tiene una reserva activa
      final existingList = await _supabase
          .from('reservas')
          .select('id, estado')
          .eq('usuario_id', user.id)
          .eq('clase_id', widget.classData['id']);

      final hasActive = (existingList as List).any((r) =>
          r['estado'] == 'confirmada' ||
          r['estado'] == 'activa' ||
          r['estado'] == 'lista_de_espera');

      if (hasActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ya tienes una reserva activa para esta clase.'),
                backgroundColor: AppColors.error),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      // 2. Comprobar capacidad
      final checkCapacity = await _supabase
          .from('reservas')
          .select('id')
          .eq('clase_id', widget.classData['id'])
          .eq('estado', 'confirmada');

      final currentReservations = (checkCapacity as List).length;
      final maxCapacity = widget.classData['capacidad_maxima'] ?? 20;
      final finalState =
          currentReservations >= maxCapacity ? 'lista_de_espera' : 'confirmada';

      // 3. Crear reserva en tabla "reservas"
      await _supabase.from('reservas').insert({
        'usuario_id': user.id,
        'clase_id': widget.classData['id'],
        'estado': finalState,
      });

      // 4. Intentar insertar en tabla "estudiantes"
      // Se hace en un try-catch independiente para que un fallo aquí
      // NO cancele la reserva ya creada correctamente en el paso 3.
      try {
        final codigo =
            'EST-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
        await _supabase.from('estudiantes').insert({
          'perfil_id': user.id,
          'clase_id': widget.classData['id'],
          'codigo_estudiante': codigo,
          'estado': finalState,
        });
      } catch (e) {
        // Si falla la inserción en estudiantes (ej. por RLS),
        // la reserva ya fue guardada — solo registra el error silenciosamente.
        debugPrint('Advertencia: no se pudo insertar en estudiantes: $e');
      }

      RefreshNotifier.notifyClient();

      if (mounted) {
        if (finalState == 'lista_de_espera') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Clase llena. Añadido a la lista de espera.'),
                backgroundColor: AppColors.warning),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('¡Clase reservada exitosamente!'),
                backgroundColor: AppColors.success),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al reservar: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classData = widget.classData;
    final nombre = classData['nombre'] ?? 'Clase sin nombre';
    final descripcion = classData['descripcion'] ?? 'Sin descripción disponible.';
    final instructor =
        classData['instructor']?['nombre_completo'] ?? 'Instructor asignado';
    final capacidadMaxima = classData['capacidad_maxima'] ?? 0;
    final ubicacion = classData['ubicacion'] ?? 'Por definir';
    final nivel = classData['nivel'] ?? 'Todos los Niveles';
    final duracionMinutos = classData['duracion_minutos'];

    String duration = duracionMinutos != null ? '$duracionMinutos min' : 'N/A';
    String startTimeStr = classData['hora_inicio']?.toString() ?? 'N/A';
    String endTimeStr = classData['hora_fin']?.toString() ?? 'N/A';
    String dateStr = classData['fecha']?.toString() ?? 'Fecha no disponible';

    if (startTimeStr.length > 5) startTimeStr = startTimeStr.substring(0, 5);
    if (endTimeStr.length > 5) endTimeStr = endTimeStr.substring(0, 5);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 280,
                        width: double.infinity,
                        color: AppColors.chipBackground,
                        child: classData['imagen_url'] != null
                            ? Image.network(
                                classData['imagen_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, st) => const Center(
                                  child: Icon(Icons.fitness_center,
                                      size: 64, color: AppColors.primary),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.fitness_center,
                                    size: 64, color: AppColors.primary)),
                      ),
                      Container(
                        height: 280,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7)
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.arrow_back,
                                      color: AppColors.white, size: 20),
                                ),
                              ),
                              const Text('Detalles de la Clase',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.white)),
                              GestureDetector(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.share,
                                      color: AppColors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20, left: 20, right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(nivel.toString().toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 8),
                            Text(nombre,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        _buildInfoChip(Icons.access_time, duration),
                        _buildInfoChip(Icons.bar_chart, nivel.toString()),
                        _buildInfoChip(Icons.people_outline,
                            '$capacidadMaxima Plazas Máximas'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sobre esta clase',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Text(descripcion,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Tu Instructor',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.chipBackground,
                            child: Icon(Icons.person,
                                size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(instructor,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                const Text('Instructor de la Clase',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Hora y Ubicación',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  _buildScheduleItem(Icons.calendar_today, dateStr,
                      '$startTimeStr - $endTimeStr'),
                  _buildScheduleItem(
                      Icons.location_on_outlined, ubicacion, 'Gimnasio'),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _bookClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.white, strokeWidth: 2))
                      : const Text('Reservar Clase',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}