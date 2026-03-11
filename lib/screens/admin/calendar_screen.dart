import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _supabase = Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _classesForDay = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClassesForDate();
  }

  Future<void> _fetchClassesForDate() async {
    setState(() => _isLoading = true);
    
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    try {
      final data = await _supabase
          .from('clases')
          .select('*, instructor:perfiles(nombre_completo)')
          .eq('fecha', dateStr)
          .eq('activa', true)
          .order('hora_inicio', ascending: true);

      if (mounted) {
        setState(() {
          _classesForDay = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetchClassesForDate();
  }

  @override
  Widget build(BuildContext context) {
    final months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    
    // Generate the week around selected date
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _changeDate(-7),
                    child: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${months[_selectedDate.month - 1]} ${_selectedDate.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  GestureDetector(
                    onTap: () => _changeDate(7),
                    child: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            // Week row
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final day = startOfWeek.add(Duration(days: index));
                  final isSelected = day.day == _selectedDate.day && day.month == _selectedDate.month;
                  final isToday = day.day == DateTime.now().day && day.month == DateTime.now().month && day.year == DateTime.now().year;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = day);
                      _fetchClassesForDate();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isToday && !isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekdays[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.white : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            // Day label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Clases para ${_selectedDate.day} ${months[_selectedDate.month - 1]}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${_classesForDay.length} clases',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            // Classes list
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _classesForDay.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.event_busy, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                'No hay clases para este día',
                                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _classesForDay.length,
                          itemBuilder: (context, index) {
                            final cl = _classesForDay[index];
                            final nombre = cl['nombre'] ?? 'Clase';
                            final instructor = cl['instructor']?['nombre_completo'] ?? 'Instructor';
                            String horaInicio = cl['hora_inicio']?.toString() ?? '';
                            String horaFin = cl['hora_fin']?.toString() ?? '';
                            final ubicacion = cl['ubicacion'] ?? '';

                            if (horaInicio.length > 5) horaInicio = horaInicio.substring(0, 5);
                            if (horaFin.length > 5) horaFin = horaFin.substring(0, 5);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 0.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(horaInicio, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                        Text(horaFin, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text('$instructor${ubicacion.isNotEmpty ? ' • $ubicacion' : ''}',
                                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
