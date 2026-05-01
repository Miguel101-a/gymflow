import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

enum _CalendarView { calendario, lista }

enum _RangeFilter { hoy, semana, mes, proximas, pasadas, todas }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _allClasses = [];
  bool _isLoading = true;

  DateTime _selectedDate = _today();
  _CalendarView _viewMode = _CalendarView.calendario;
  _RangeFilter _rangeFilter = _RangeFilter.proximas;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _weekdaysLong = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
    _fetchAllClasses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllClasses() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('clases')
          .select('*, instructor:perfiles(nombre_completo)')
          .order('fecha', ascending: true)
          .order('hora_inicio', ascending: true);

      if (mounted) {
        setState(() {
          _allClasses = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  DateTime? _parseClassDate(Map cl) {
    final raw = cl['fecha']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = DateTime.parse(raw);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  bool _matchesSearch(Map cl) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final nombre = (cl['nombre'] ?? '').toString().toLowerCase();
    final instructor =
        (cl['instructor']?['nombre_completo'] ?? '').toString().toLowerCase();
    final ubicacion = (cl['ubicacion'] ?? '').toString().toLowerCase();
    return nombre.contains(q) ||
        instructor.contains(q) ||
        ubicacion.contains(q);
  }

  bool _matchesRange(DateTime fecha) {
    final today = _today();
    switch (_rangeFilter) {
      case _RangeFilter.hoy:
        return fecha == today;
      case _RangeFilter.semana:
        final start = today.subtract(Duration(days: today.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return !fecha.isBefore(start) && !fecha.isAfter(end);
      case _RangeFilter.mes:
        return fecha.year == today.year && fecha.month == today.month;
      case _RangeFilter.proximas:
        return !fecha.isBefore(today);
      case _RangeFilter.pasadas:
        return fecha.isBefore(today);
      case _RangeFilter.todas:
        return true;
    }
  }

  List<Map<String, dynamic>> get _filteredClasses {
    return _allClasses.where((cl) {
      final fecha = _parseClassDate(cl);
      if (fecha == null) return false;
      return _matchesRange(fecha) && _matchesSearch(cl);
    }).toList();
  }

  List<Map<String, dynamic>> _classesForDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return _allClasses.where((cl) {
      final fecha = _parseClassDate(cl);
      if (fecha == null) return false;
      return fecha == target && _matchesSearch(cl);
    }).toList();
  }

  bool _hasClassesOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return _allClasses.any((cl) => _parseClassDate(cl) == target);
  }

  int _countFor(_RangeFilter f) {
    final today = _today();
    return _allClasses.where((cl) {
      final fecha = _parseClassDate(cl);
      if (fecha == null) return false;
      switch (f) {
        case _RangeFilter.hoy:
          return fecha == today;
        case _RangeFilter.semana:
          final start = today.subtract(Duration(days: today.weekday - 1));
          final end = start.add(const Duration(days: 6));
          return !fecha.isBefore(start) && !fecha.isAfter(end);
        case _RangeFilter.mes:
          return fecha.year == today.year && fecha.month == today.month;
        case _RangeFilter.proximas:
          return !fecha.isBefore(today);
        case _RangeFilter.pasadas:
          return fecha.isBefore(today);
        case _RangeFilter.todas:
          return true;
      }
    }).length;
  }

  void _goToToday() {
    setState(() {
      _selectedDate = _today();
      _rangeFilter = _RangeFilter.proximas;
    });
  }

  String _dateGroupLabel(DateTime fecha) {
    final today = _today();
    final tomorrow = today.add(const Duration(days: 1));
    if (fecha == today) return 'Hoy';
    if (fecha == tomorrow) return 'Mañana';
    final wd = _weekdaysLong[fecha.weekday - 1];
    return '$wd ${fecha.day} ${_months[fecha.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildViewToggle(),
            _buildSearchBar(),
            _buildRangeChips(),
            const SizedBox(height: 4),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: _viewMode == _CalendarView.calendario
                    ? _buildCalendarView()
                    : _buildListView(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Calendario',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton.icon(
            onPressed: _goToToday,
            icon: const Icon(Icons.today, size: 18, color: AppColors.primary),
            label: const Text(
              'Ir a hoy',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              label: 'Calendario',
              icon: Icons.calendar_view_week,
              selected: _viewMode == _CalendarView.calendario,
              onTap: () => setState(() => _viewMode = _CalendarView.calendario),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toggleButton(
              label: 'Lista',
              icon: Icons.view_list,
              selected: _viewMode == _CalendarView.lista,
              onTap: () => setState(() => _viewMode = _CalendarView.lista),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar clase, instructor o ubicación...',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: AppColors.backgroundLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildRangeChips() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _rangeChip(_RangeFilter.hoy, 'Hoy'),
            _rangeChip(_RangeFilter.semana, 'Semana'),
            _rangeChip(_RangeFilter.mes, 'Mes'),
            _rangeChip(_RangeFilter.proximas, 'Próximas'),
            _rangeChip(_RangeFilter.pasadas, 'Pasadas'),
            _rangeChip(_RangeFilter.todas, 'Todas'),
          ],
        ),
      ),
    );
  }

  Widget _rangeChip(_RangeFilter f, String label) {
    final selected = _rangeFilter == f;
    final count = _countFor(f);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _rangeFilter = f),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.backgroundLight,
        labelStyle: TextStyle(
          color: selected ? AppColors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
    );
  }

  Widget _buildCalendarView() {
    final startOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final dayClasses = _classesForDay(_selectedDate);

    return Column(
      children: [
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate =
                      _selectedDate.subtract(const Duration(days: 7));
                }),
                child: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                }),
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final day = startOfWeek.add(Duration(days: index));
              final dayOnly = DateTime(day.year, day.month, day.day);
              final isSelected = dayOnly == _selectedDate;
              final isToday = dayOnly == _today();
              final hasClasses = _hasClassesOn(dayOnly);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = dayOnly),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekdays[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasClasses
                              ? (isSelected
                                  ? AppColors.white
                                  : AppColors.primary)
                              : Colors.transparent,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Clases para ${_selectedDate.day} ${_months[_selectedDate.month - 1]}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${dayClasses.length} clases',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: dayClasses.isEmpty
              ? _buildEmptyState('No hay clases para este día')
              : RefreshIndicator(
                  onRefresh: _fetchAllClasses,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dayClasses.length,
                    itemBuilder: (context, index) =>
                        _buildClassCard(dayClasses[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final classes = _filteredClasses;
    if (classes.isEmpty) {
      return _buildEmptyState(
        _searchQuery.isNotEmpty
            ? 'Sin resultados para "$_searchQuery"'
            : 'No hay clases en este rango',
      );
    }

    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final cl in classes) {
      final fecha = _parseClassDate(cl);
      if (fecha == null) continue;
      groups.putIfAbsent(fecha, () => []).add(cl);
    }

    final sortedKeys = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _fetchAllClasses,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final fecha = sortedKeys[index];
          final groupClasses = groups[fecha]!;
          final isPast = fecha.isBefore(_today());

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      _dateGroupLabel(fecha),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isPast
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${groupClasses.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...groupClasses.map((cl) => _buildClassCard(cl, dimmed: isPast)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cl, {bool dimmed = false}) {
    final nombre = cl['nombre'] ?? 'Clase';
    final instructor = cl['instructor']?['nombre_completo'] ?? 'Instructor';
    String horaInicio = cl['hora_inicio']?.toString() ?? '';
    String horaFin = cl['hora_fin']?.toString() ?? '';
    final ubicacion = cl['ubicacion'] ?? '';
    final cancelada = cl['cancelada'] == true;

    if (horaInicio.length > 5) horaInicio = horaInicio.substring(0, 5);
    if (horaFin.length > 5) horaFin = horaFin.substring(0, 5);

    final opacity = dimmed ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: () async {
          final result =
              await Navigator.pushNamed(context, '/admin/class_form', arguments: cl);
          if (result == true) _fetchAllClasses();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cancelada ? AppColors.error : AppColors.border,
              width: cancelada ? 1.2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      horaInicio,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      horaFin,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (cancelada)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'CANCELADA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$instructor${ubicacion.toString().isNotEmpty ? ' • $ubicacion' : ''}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
