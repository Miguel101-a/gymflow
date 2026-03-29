import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class InstructorStudentsScreen extends StatefulWidget {
  const InstructorStudentsScreen({super.key});

  @override
  State<InstructorStudentsScreen> createState() =>
      _InstructorStudentsScreenState();
}

class _InstructorStudentsScreenState extends State<InstructorStudentsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _students = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMisAlumnos();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        final nombre = (s['nombre_completo'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        final clase = (s['clase_nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(q) || email.contains(q) || clase.contains(q);
      }).toList();
    });
  }

  Future<void> _fetchMisAlumnos() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      // Trae reservas confirmadas de clases donde instructor_id = yo
      final data = await _supabase
          .from('reservas')
          .select(
              'usuario_id, estado, created_at, clase:clases!inner(id, nombre, instructor_id), usuario:perfiles!inner(nombre_completo, email, telefono, tipo_membresia)')
          .eq('clase.instructor_id', user.id)
          .eq('estado', 'confirmada')
          .order('created_at', ascending: false);

      // Enriquecer datos con nombre de clase
      final enriched = (data as List).map((r) {
        return {
          'nombre_completo': r['usuario']?['nombre_completo'] ?? 'Sin nombre',
          'email': r['usuario']?['email'] ?? '',
          'telefono': r['usuario']?['telefono'] ?? 'Sin teléfono',
          'tipo_membresia': r['usuario']?['tipo_membresia'] ?? 'basica',
          'clase_nombre': r['clase']?['nombre'] ?? '',
          'estado_reserva': r['estado'] ?? '',
          'usuario_id': r['usuario_id'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _students = enriched;
          _filtered = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
                  const Expanded(
                    child: Text('Mis Alumnos',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  Text('${_students.length} alumnos',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Búsqueda
            Container(
              color: AppColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, email o clase...',
                  prefixIcon: const Icon(Icons.search,
                      color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            // Lista
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()))
                : _filtered.isEmpty
                    ? const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 56, color: AppColors.textTertiary),
                              SizedBox(height: 12),
                              Text('No hay alumnos en tus clases',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16)),
                            ],
                          ),
                        ),
                      )
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetchMisAlumnos,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final student = _filtered[index];
                              return _buildStudentCard(student);
                            },
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = student['nombre_completo'] ?? '';
    final email = student['email'] ?? '';
    final phone = student['telefono'] ?? 'Sin teléfono';
    final membership = student['tipo_membresia'] ?? 'basica';
    final claseNombre = student['clase_nombre'] ?? '';

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
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.chipBackground,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(phone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
                if (claseNombre.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.fitness_center,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(claseNombre,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              membership.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}