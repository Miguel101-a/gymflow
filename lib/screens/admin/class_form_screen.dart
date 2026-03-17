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
  final _imagenUrlController = TextEditingController();
  final _precioController = TextEditingController();

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
    _imagenUrlController.text = d['imagen_url'] ?? '';
    _precioController.text = (d['precio'] ?? 0).toString();
    _selectedInstructorId = d['instructor_id'];
    _selectedNivel = _niveles.contains(d['nivel']) ? d['nivel'] : 'todos';
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
          
          // Safety: check if current selected instructor still exists in the freshly loaded list
          final currentStillValid = _instructors.any((i) => i['id'] == _selectedInstructorId);
          
          if (!currentStillValid) {
            // Try to select current user if not editing or if current selection is invalid
            final currentUser = _supabase.auth.currentUser;
            if (currentUser != null && _instructors.any((i) => i['id'] == currentUser.id)) {
              _selectedInstructorId = currentUser.id;
            } else if (_instructors.isNotEmpty) {
              _selectedInstructorId = _instructors[0]['id'];
            } else {
              _selectedInstructorId = null;
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
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      final duracion = endMinutes > startMinutes ? endMinutes - startMinutes : 0;

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
        'duracion_minutos': duracion,
        'imagen_url': _imagenUrlController.text.trim().isEmpty ? null : _imagenUrlController.text.trim(),
        'precio': double.tryParse(_precioController.text) ?? 0,
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
                      value: _niveles.contains(_selectedNivel) ? _selectedNivel : 'todos',
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
              if (_instructors.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(child: Text('No hay instructores disponibles. Por favor, crea uno primero.')),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _instructors.any((i) => i['id'] == _selectedInstructorId) ? _selectedInstructorId : null,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _imagenUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL de Imagen (opcional)',
                  hintText: 'https://ejemplo.com/imagen.jpg',
                  filled: true,
                  fillColor: AppColors.white,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_imagenUrlController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.chipBackground,
                    ),
                    child: Image.network(
                      _imagenUrlController.text,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.image_not_supported, size: 48, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  hintText: '0.00',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: AppColors.white,
                ),
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
    _imagenUrlController.dispose();
    _precioController.dispose();
    super.dispose();
  }
}
