import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _precioController = TextEditingController();

  // ── Imagen ──────────────────────────────────────────────────────────────────
  XFile? _pickedImage;           // archivo seleccionado del dispositivo
  String? _existingImageUrl;     // URL existente al editar una clase
  bool _isUploadingImage = false;
  // ────────────────────────────────────────────────────────────────────────────

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
    _precioController.text = (d['precio'] ?? 0).toString();
    _selectedInstructorId = d['instructor_id'];
    _selectedNivel = _niveles.contains(d['nivel']) ? d['nivel'] : 'todos';
    _activa = d['activa'] ?? true;
    _existingImageUrl = d['imagen_url'];          // guarda la URL existente

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
          .eq('rol', 'admin');

      if (mounted) {
        setState(() {
          _instructors = data;
          final currentStillValid =
              _instructors.any((i) => i['id'] == _selectedInstructorId);
          if (!currentStillValid) {
            final currentUser = _supabase.auth.currentUser;
            if (currentUser != null &&
                _instructors.any((i) => i['id'] == currentUser.id)) {
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

  // ── Seleccionar imagen del dispositivo (PNG o JPG) ──────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    // Muestra un bottom sheet para elegir galería o cámara
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Seleccionar imagen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,       // comprime un poco para no subir archivos enormes
      maxWidth: 1200,
    );

    if (image == null) return;

    // Validar extensión: solo PNG y JPG
    final ext = image.path.split('.').last.toLowerCase();
    if (ext != 'png' && ext != 'jpg' && ext != 'jpeg') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solo se permiten imágenes PNG o JPG'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _pickedImage = image);
  }

  // ── Quitar imagen seleccionada ──────────────────────────────────────────────
  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _existingImageUrl = null;
    });
  }

  // ── Subir imagen a Supabase Storage ────────────────────────────────────────
  // IMPORTANTE: Debes crear un bucket llamado "clases-imagenes" en
  // Supabase → Storage, con acceso público habilitado.
  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _existingImageUrl;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final ext = _pickedImage!.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

      // Nombre único basado en timestamp
      final fileName =
          'clase_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage
          .from('clases-imagenes')       // ← nombre del bucket en Supabase
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      final publicUrl = _supabase.storage
          .from('clases-imagenes')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return _existingImageUrl; // si falla, mantiene la URL anterior
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }
  // ────────────────────────────────────────────────────────────────────────────

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
        const SnackBar(
            content: Text('Por favor, completa todos los campos requeridos.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Sube la imagen si hay una nueva seleccionada
      final imageUrl = await _uploadImage();

      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;
      final duracion =
          endMinutes > startMinutes ? endMinutes - startMinutes : 0;

      final classData = {
        'nombre': _nombreController.text,
        'descripcion': _descripcionController.text,
        'instructor_id': _selectedInstructorId,
        'capacidad_maxima': int.parse(_capacidadController.text),
        'fecha':
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'hora_inicio': _formatTime(_startTime),
        'hora_fin': _formatTime(_endTime),
        'ubicacion': _ubicacionController.text,
        'nivel': _selectedNivel,
        'activa': _activa,
        'duracion_minutos': duracion,
        'imagen_url': imageUrl,                   // URL subida o null
        'precio': double.tryParse(_precioController.text) ?? 0,
      };

      if (widget.classData == null) {
        await _supabase.from('clases').insert(classData);
      } else {
        classData['updated_at'] = DateTime.now().toIso8601String();
        await _supabase
            .from('clases')
            .update(classData)
            .eq('id', widget.classData!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clase guardada exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
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
    final hasImage = _pickedImage != null || _existingImageUrl != null;

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
              // ── Nombre ─────────────────────────────────────────────────────
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

              // ── Descripción ────────────────────────────────────────────────
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

              // ── Nivel + Capacidad ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _niveles.contains(_selectedNivel)
                          ? _selectedNivel
                          : 'todos',
                      decoration: const InputDecoration(
                        labelText: 'Nivel',
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      items: _niveles
                          .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text(n.toUpperCase())))
                          .toList(),
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

              // ── Instructor ─────────────────────────────────────────────────
              if (_instructors.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              'No hay instructores disponibles. Por favor, crea uno primero.')),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _instructors.any((i) => i['id'] == _selectedInstructorId)
                      ? _selectedInstructorId
                      : null,
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
                  validator: (v) =>
                      v == null ? 'Selecciona un instructor' : null,
                ),
              const SizedBox(height: 16),

              // ── Fecha ──────────────────────────────────────────────────────
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    filled: true,
                    fillColor: AppColors.white,
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Hora inicio / fin ──────────────────────────────────────────
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

              // ── Ubicación ──────────────────────────────────────────────────
              TextFormField(
                controller: _ubicacionController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación / Sala',
                  filled: true,
                  fillColor: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),

              // ── Activa toggle ──────────────────────────────────────────────
              SwitchListTile(
                title: const Text('Clase Activa'),
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
                tileColor: AppColors.white,
              ),
              const SizedBox(height: 16),

              // ── Imagen — NUEVO: subir desde dispositivo ────────────────────
              const Text(
                'Imagen de la Clase',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),

              if (!hasImage)
                // Botón de selección cuando no hay imagen
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          width: 1.5,
                          style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 48, color: AppColors.primary),
                        const SizedBox(height: 8),
                        const Text('Toca para subir imagen',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('PNG o JPG',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                )
              else
                // Vista previa de la imagen seleccionada / existente
                Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.chipBackground,
                      ),
                      child: _pickedImage != null
                          // imagen recién seleccionada del dispositivo
                          ? Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            )
                          // imagen existente de Supabase
                          : Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, st) => const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 48,
                                    color: AppColors.textTertiary),
                              ),
                            ),
                    ),
                    // Botón de cambiar imagen
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Cambiar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Botón de eliminar imagen
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Quitar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Indicador de carga al subir
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              // ────────────────────────────────────────────────────────────────

              const SizedBox(height: 16),

              // ── Precio ─────────────────────────────────────────────────────
              TextFormField(
                controller: _precioController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  hintText: '0.00',
                  prefixText: 'Bs ',
                  filled: true,
                  fillColor: AppColors.white,
                ),
              ),
              const SizedBox(height: 32),

              // ── Botón guardar ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingImage) ? null : _saveClass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: (_isSaving || _isUploadingImage)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Clase',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
    _precioController.dispose();
    super.dispose();
  }
}