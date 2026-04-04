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
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        return (s['nombre_completo'] ?? '').toString().toLowerCase().contains(q) ||
            (s['email'] ?? '').toString().toLowerCase().contains(q) ||
            (s['clase_nombre'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _fetch() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('reservas')
          .select(
              'usuario_id, estado, clase:clases!inner(id, nombre, instructor_id), usuario:perfiles!inner(nombre_completo, email, telefono, tipo_membresia)')
          .eq('clase.instructor_id', user.id)
          .eq('estado', 'confirmada');

      final enriched = (data as List).map((r) => {
        'nombre_completo': r['usuario']?['nombre_completo'] ?? 'Sin nombre',
        'email': r['usuario']?['email'] ?? '',
        'telefono': r['usuario']?['telefono'] ?? 'Sin teléfono',
        'tipo_membresia': r['usuario']?['tipo_membresia'] ?? 'basica',
        'clase_nombre': r['clase']?['nombre'] ?? '',
        'usuario_id': r['usuario_id'],
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
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                      child: Text('Mis Alumnos',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                  Text('${_students.length} alumnos',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, email o clase...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            _isLoading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : _filtered.isEmpty
                    ? const Expanded(
                        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.people_outline, size: 56, color: AppColors.textTertiary),
                          SizedBox(height: 12),
                          Text('No hay alumnos en tus clases',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        ])))
                    : Expanded(
                        child: RefreshIndicator(
                          onRefresh: _fetch,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _card(_filtered[i]),
                          ),
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final name = s['nombre_completo'] ?? '';
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
            radius: 22,
            backgroundColor: AppColors.chipBackground,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(s['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(s['telefono'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              if ((s['clase_nombre'] ?? '').toString().isNotEmpty)
                Row(children: [
                  const Icon(Icons.fitness_center, size: 11, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(s['clase_nombre'], style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text((s['tipo_membresia'] ?? 'basica').toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}