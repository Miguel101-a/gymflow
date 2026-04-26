import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/refresh_notifier.dart';
import 'client_shell.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _allClasses = [];
  List<dynamic> _filteredClasses = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  // Filter state
  String? _selectedNivel;
  final List<String> _niveles = ['todos', 'principiante', 'intermedio', 'avanzado'];

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _searchController.addListener(_applyFilters);
    RefreshNotifier.clientRefresh.addListener(_onRefresh);
  }

  void _onRefresh() {
    _fetchClasses();
  }

  @override
  void dispose() {
    RefreshNotifier.clientRefresh.removeListener(_onRefresh);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    try {
      final data = await _supabase
          .from('clases')
          .select('*, instructor:perfiles(nombre_completo)')
          .eq('activa', true)
          .order('fecha', ascending: true);
          
      if (mounted) {
        setState(() {
          _allClasses = data;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClasses = _allClasses.where((cl) {
        // Search filter
        final nombre = (cl['nombre'] ?? '').toString().toLowerCase();
        final instructor = (cl['instructor']?['nombre_completo'] ?? '').toString().toLowerCase();
        final matchesSearch = query.isEmpty || nombre.contains(query) || instructor.contains(query);

        // Level filter
        final nivel = (cl['nivel'] ?? '').toString();
        final matchesNivel = _selectedNivel == null || _selectedNivel == 'todos' || nivel == _selectedNivel;

        return matchesSearch && matchesNivel;
      }).toList();
    });
  }

  void _showProfileMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200,
        100,
        16,
        0,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_outline, size: 20),
            title: Text('Mi perfil', style: TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'reservations',
          child: ListTile(
            leading: Icon(Icons.calendar_today_outlined, size: 20),
            title: Text('Mis reservas', style: TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, size: 20, color: AppColors.error),
            title: Text('Cerrar sesión', style: TextStyle(fontSize: 14, color: AppColors.error)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (!mounted) return;
      if (value == 'profile') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) shellState.switchTab(3);
      } else if (value == 'reservations') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) shellState.switchTab(2);
      } else if (value == 'logout') {
        _confirmSignOut();
      }
    });
  }

  Future<void> _confirmSignOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Está seguro de salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _selectNivel(String nivel) {
    setState(() {
      if (_selectedNivel == nivel) {
        _selectedNivel = null; // deselect
      } else {
        _selectedNivel = nivel;
      }
    });
    _applyFilters();
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
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Clases de Gimnasio',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showProfileMenu,
                    child: const CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.chipBackground,
                      child: Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Search
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar clases o instructores',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Filter chips
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _niveles.map((nivel) {
                    final isSelected = _selectedNivel == nivel;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _selectNivel(nivel),
                        child: _buildFilterChip(
                          nivel == 'todos' ? 'Todos' : nivel[0].toUpperCase() + nivel.substring(1),
                          isSelected,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Class list
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _filteredClasses.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty || _selectedNivel != null
                                    ? 'No se encontraron clases con esos filtros'
                                    : 'No hay clases disponibles',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            final cl = _filteredClasses[index];
                            final instructorName = cl['instructor']?['nombre_completo'] ?? 'Instructor';
                            
                            final fecha = cl['fecha']?.toString() ?? '';
                            final horaInicio = cl['hora_inicio']?.toString() ?? '';
                            final duracion = cl['duracion_minutos']?.toString() ?? '-';
                            final capacidad = cl['capacidad_maxima'] ?? 0;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildClassItem(
                                context,
                                cl,
                                cl['nombre']?.toString() ?? 'Clase',
                                instructorName,
                                '$fecha • $horaInicio',
                                '$duracion min',
                                'Capacidad: $capacidad',
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

  Widget _buildFilterChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.white : AppColors.textPrimary,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: selected ? AppColors.white : AppColors.textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildClassItem(BuildContext context, dynamic classData, String title, String instructor, String time, String duration, String spots) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/classDetail', arguments: classData),
      child: Container(
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
                  width: 110,
                  color: AppColors.chipBackground,
                  child: classData['imagen_url'] != null && classData['imagen_url'].toString().isNotEmpty
                      ? Image.network(
                          classData['imagen_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.fitness_center, size: 36, color: AppColors.primary),
                          ),
                        )
                      : const Center(child: Icon(Icons.fitness_center, size: 36, color: AppColors.primary)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.person_outline, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('Instructor: $instructor',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('$time · $duration',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.people_outline, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(spots,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ]),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/classDetail', arguments: classData),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Detalles', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
