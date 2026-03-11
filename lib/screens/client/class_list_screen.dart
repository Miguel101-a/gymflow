import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import 'client_shell.dart';

class ClassListScreen extends StatefulWidget {
  const ClassListScreen({super.key});

  @override
  State<ClassListScreen> createState() => _ClassListScreenState();
}

class _ClassListScreenState extends State<ClassListScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
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
          _classes = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      if (value == 'profile') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) shellState.switchTab(3);
      } else if (value == 'reservations') {
        final shellState = context.findAncestorStateOfType<ClientShellState>();
        if (shellState != null) shellState.switchTab(2);
      } else if (value == 'logout') {
        _signOut();
      }
    });
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu, size: 20),
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
                decoration: InputDecoration(
                  hintText: 'Buscar clases o instructores',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
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
              child: Row(
                children: [
                  _buildFilterChip('Tipo de Clase', true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Instructor', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Día', false),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Class list
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _classes.isEmpty
                    ? const Expanded(child: Center(child: Text('No hay clases disponibles')))
                    : Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final cl = _classes[index];
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
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: selected ? AppColors.white : AppColors.textSecondary),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: AppColors.chipBackground,
                    child: const Center(child: Icon(Icons.fitness_center, size: 48, color: AppColors.primary)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(spots, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Instructor: $instructor', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(time, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(duration, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, '/classDetail', arguments: classData),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Detalles', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
