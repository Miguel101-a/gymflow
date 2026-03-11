import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class ClassFormScreen extends StatefulWidget {
  final Map<String, dynamic>? classData;

  const ClassFormScreen({super.key, this.classData});

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _ubicacionController = TextEditingController();

  String? _selectedInstructorId;
  String _selectedNivel = 'todos';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  bool _activa = true;

  List<dynamic> _instructors = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _niveles = ['principiante', 'intermedio', 'avanzado', 'todos'];

  @override
  void initState() {
    super.initState();
    _fetchInstructors();
    if (widget.classData != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final d = widget.classData!;
    _nombreController.text = d['nombre'] ?? '';
    _descripcionController.text = d['descripcion'] ?? '';
    _capacidadController.text = (d['capacidad_maxima'] ?? 20).toString();
    _ubicacionController.text = d['ubicacion'] ?? '';
    _selectedInstructorId = d['instructor_id'];
    _selectedNivel = d['nivel'] ?? 'todos';
    _activa = d['activa'] ?? true;

    if (d['fecha'] != null) {
      _selectedDate = DateTime.parse(d['fecha']);
    }
    if (d['hora_inicio'] != null) {
      final parts = d['hora_inicio'].toString().split(':');
      if (parts.length >= 2) {
        _startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    if (d['hora_fin'] != null) {
      final parts = d['hora_fin'].toString().split(':');
      if (parts.length >= 2) {
        _endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  Future<void> _fetchInstructors() async {
    try {
      final data = await _supabase
          .from('perfiles')
          .select('id, nombre_completo')
          .eq('rol', 'admin'); // Assuming admins can be instructors or we have a specific role.

      if (mounted) {
        setState(() {
          _instructors = data;
          if (_selectedInstructorId == null && _instructors.isNotEmpty) {
             // Try to select current user if not editing
             final currentUser = _supabase.auth.currentUser;
             if (currentUser != null) {
                _selectedInstructorId = currentUser.id;
             } else {
                _selectedInstructorId = _instructors[0]['id'];
             }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate() || _selectedInstructorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos requeridos.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final classData = {
        'nombre': _nombreController.text,
        'descripcion': _descripcionController.text,
        'instructor_id': _selectedInstructorId,
        'capacidad_maxima': int.parse(_capacidadController.text),
        'fecha': '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'hora_inicio': _formatTime(_startTime),
        'hora_fin': _formatTime(_endTime),
        'ubicacion': _ubicacionController.text,
        'nivel': _selectedNivel,
        'activa': _activa,
      };

      if (widget.classData == null) {
        // Create
        await _supabase.from('clases').insert(classData);
      } else {
        // Update
        classData['updated_at'] = DateTime.now().toIso8601String();
        await _supabase
            .from('clases')
            .update(classData)
            .eq('id', widget.classData!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clase guardada exitosamente'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEditing = widget.classData != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Clase' : 'Nueva Clase'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Clase',
                  filled: true,
                  fillColor: AppColors.white,
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  filled: true,
                  fillColor: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedNivel,
                      decoration: const InputDecoration(
                        labelText: 'Nivel',
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      items: _niveles.map((n) => DropdownMenuItem(value: n, child: Text(n.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _selectedNivel = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _capacidadController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacidad Máx.',
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedInstructorId,
                decoration: const InputDecoration(
                  labelText: 'Instructor',
                  filled: true,
                  fillColor: AppColors.white,
                ),
                items: _instructors.map((i) {
                  return DropdownMenuItem<String>(
                    value: i['id'],
                    child: Text(i['nombre_completo'] ?? 'Sin nombre'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedInstructorId = v),
                validator: (v) => v == null ? 'Selecciona un instructor' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha',
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        child: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora Inicio',
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Hora Fin',
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ubicacionController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación / Sala',
                  filled: true,
                  fillColor: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Clase Activa'),
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
                tileColor: AppColors.white,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Clase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _capacidadController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }
}
