// ignore: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../utils/permissions.dart';

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

  // ── Imagen ─────────────────────────────────────────────────────────────────
  // Usamos Uint8List + XFile — compatible con Flutter Web y Mobile
  // NO usamos dart:io ni Image.file() porque no funcionan en Web (Vercel)
  XFile? _pickedImageFile;
  Uint8List? _pickedImageBytes;
  String? _detectedMime;        // 'image/png' o 'image/jpeg' detectado por bytes
  String? _existingImageUrl;
  bool _isUploadingImage = false;
  // ────────────────────────────────────────────────────────────────────────────

  String? _selectedInstructorId;
  String _selectedNivel = 'todos';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  bool _activa = true;

  // Plaza 24 de Septiembre, Santa Cruz de la Sierra
  static const LatLng _defaultCenter = LatLng(-17.7833, -63.1821);
  LatLng _markerLatLng = _defaultCenter;
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  List<dynamic> _instructors = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasPermission = true;

  final List<String> _niveles = [
    'principiante', 'intermedio', 'avanzado', 'todos'
  ];

  @override
  void initState() {
    super.initState();
    _fetchInstructors();
    if (widget.classData != null) _loadExistingData();
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
    _existingImageUrl = d['imagen_url'];

    if (d['fecha'] != null) _selectedDate = DateTime.parse(d['fecha']);
    if (d['hora_inicio'] != null) {
      final p = d['hora_inicio'].toString().split(':');
      if (p.length >= 2) _startTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    if (d['hora_fin'] != null) {
      final p = d['hora_fin'].toString().split(':');
      if (p.length >= 2) _endTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    final lat = d['latitud'];
    final lng = d['longitud'];
    if (lat != null && lng != null) {
      _markerLatLng = LatLng(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );
    }
  }

  Future<void> _fetchInstructors() async {
    try {
      final perms = await Permissions.load();
      final isEditing = widget.classData != null;
      final needed = isEditing ? Permissions.editarClases : Permissions.crearClases;
      if (perms[needed] != true) {
        if (mounted) setState(() { _hasPermission = false; _isLoading = false; });
        return;
      }

      final data = await _supabase
          .from('perfiles')
          .select('id, nombre_completo')
          .inFilter('rol', ['admin', 'instructor']);
      if (mounted) {
        setState(() {
          _instructors = data;
          final valid = _instructors.any((i) => i['id'] == _selectedInstructorId);
          if (!valid) {
            final cu = _supabase.auth.currentUser;
            if (cu != null && _instructors.any((i) => i['id'] == cu.id)) {
              _selectedInstructorId = cu.id;
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

  // ── Detectar tipo de imagen por sus primeros bytes (magic bytes) ────────────
  // Esto funciona en Web y Mobile sin necesidad de la extensión del archivo.
  // PNG empieza con: 89 50 4E 47  (‰PNG)
  // JPG empieza con: FF D8        (ÿØ)
  String? _detectMimeFromBytes(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    return null; // no es PNG ni JPG
  }

  // ── Seleccionar imagen — 100% compatible con Flutter Web ───────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();

    // En Web solo está disponible gallery (no hay cámara nativa en browser)
    // Mostramos el sheet igualmente por si se usa en móvil
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Seleccionar imagen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería / Archivo'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Cámara (solo móvil)'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
    } catch (e) {
      // En web, la cámara puede no estar disponible
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cámara no disponible. Usa la galería.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (image == null) return;

    // Leer bytes — FUNCIONA EN WEB Y MOBILE (no usa dart:io)
    final bytes = await image.readAsBytes();

    // Detectar tipo por magic bytes (no depende del nombre del archivo)
    final mime = _detectMimeFromBytes(bytes);

    if (mime == null) {
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

    setState(() {
      _pickedImageFile = image;
      _pickedImageBytes = bytes;
      _detectedMime = mime;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImageFile = null;
      _pickedImageBytes = null;
      _detectedMime = null;
      _existingImageUrl = null;
    });
  }

  // ── Subir imagen a Supabase Storage — bucket "class-images" ────────────────
  Future<String?> _uploadImage() async {
    if (_pickedImageBytes == null || _detectedMime == null) {
      return _existingImageUrl;
    }

    setState(() => _isUploadingImage = true);
    try {
      final ext = _detectedMime == 'image/png' ? 'png' : 'jpg';
      final fileName = 'clase_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage
          .from('class-images')       // ← nombre exacto del bucket en Supabase
          .uploadBinary(
            fileName,
            _pickedImageBytes!,
            fileOptions: FileOptions(contentType: _detectedMime!, upsert: true),
          );

      return _supabase.storage.from('class-images').getPublicUrl(fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return _existingImageUrl;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search')
          .replace(queryParameters: {'q': query, 'format': 'json', 'limit': '1'});
      final response = await http.get(uri, headers: {'User-Agent': 'gymflow/1.0'});
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat'] as String);
          final lon = double.parse(results[0]['lon'] as String);
          final point = LatLng(lat, lon);
          setState(() => _markerLatLng = point);
          _mapController.move(point, 15);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontró la ubicación')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _askToNotifyClients(Map<String, dynamic> classData) async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Notificar a los clientes')),
          ],
        ),
        content: const Text(
          '¿Quieres enviar una notificación a todos los clientes para invitarlos a inscribirse a esta nueva clase?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Enviar notificación',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (accept != true) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final nombre = classData['nombre'] ?? 'Nueva clase';
      final fecha = classData['fecha'] ?? '';
      final horaInicio = classData['hora_inicio'] ?? '';
      final ubicacion = classData['ubicacion'] ?? '';
      final contenido =
          '¡Nueva clase disponible! "$nombre" — $fecha a las $horaInicio'
          '${ubicacion.toString().isNotEmpty ? ' en $ubicacion' : ''}.'
          ' ¡Inscríbete y reserva tu lugar!';

      await _supabase.from('comunicaciones').insert({
        'asunto': 'Nueva clase: $nombre',
        'contenido': contenido,
        'autor_id': user.id,
        'grupo_destinatario': 'todos',
        'tipo': 'clase_creada',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación enviada a los clientes'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar la notificación: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate() || _selectedInstructorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, completa todos los campos requeridos.')),
      );
      return;
    }

    const openMin = 7 * 60;
    const closeMin = 23 * 60 + 30;
    final startTotalMin = _startTime.hour * 60 + _startTime.minute;
    final endTotalMin = _endTime.hour * 60 + _endTime.minute;
    if (startTotalMin < openMin || endTotalMin > closeMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El horario debe estar entre 07:00 y 23:30'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final imageUrl = await _uploadImage();
      final startMin = _startTime.hour * 60 + _startTime.minute;
      final endMin = _endTime.hour * 60 + _endTime.minute;

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
        'duracion_minutos': endMin > startMin ? endMin - startMin : 0,
        'imagen_url': imageUrl,
        'precio': double.tryParse(_precioController.text) ?? 0,
        'latitud': _markerLatLng.latitude,
        'longitud': _markerLatLng.longitude,
      };

      final isNewClass = widget.classData == null;
      if (isNewClass) {
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
              backgroundColor: AppColors.success),
        );

        if (isNewClass) {
          await _askToNotifyClients(classData);
        }

        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: AppColors.error),
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

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Sin permiso'),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: AppColors.textTertiary),
              SizedBox(height: 16),
              Text('No tienes permiso para esta acción.',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final isEditing = widget.classData != null;
    final hasImage = _pickedImageBytes != null || _existingImageUrl != null;

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
              // ── Nombre ──────────────────────────────────────────────────────
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                    labelText: 'Nombre de la Clase',
                    filled: true, fillColor: AppColors.white),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),

              // ── Descripción ─────────────────────────────────────────────────
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Descripción',
                    filled: true, fillColor: AppColors.white),
              ),
              const SizedBox(height: 16),

              // ── Nivel + Capacidad ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _niveles.contains(_selectedNivel) ? _selectedNivel : 'todos',
                      decoration: const InputDecoration(
                          labelText: 'Nivel', filled: true, fillColor: AppColors.white),
                      items: _niveles
                          .map((n) => DropdownMenuItem(value: n, child: Text(n.toUpperCase())))
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
                          filled: true, fillColor: AppColors.white),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Instructor ──────────────────────────────────────────────────
              if (_instructors.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(child: Text('No hay instructores disponibles.')),
                  ]),
                )
              else
                DropdownButtonFormField<String>(
                  value: _instructors.any((i) => i['id'] == _selectedInstructorId)
                      ? _selectedInstructorId
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Instructor', filled: true, fillColor: AppColors.white),
                  items: _instructors
                      .map((i) => DropdownMenuItem<String>(
                          value: i['id'],
                          child: Text(i['nombre_completo'] ?? 'Sin nombre')))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedInstructorId = v),
                  validator: (v) => v == null ? 'Selecciona un instructor' : null,
                ),
              const SizedBox(height: 16),

              // ── Fecha ───────────────────────────────────────────────────────
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha', filled: true, fillColor: AppColors.white,
                      suffixIcon: Icon(Icons.calendar_today, size: 18)),
                  child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                ),
              ),
              const SizedBox(height: 16),

              // ── Hora inicio / fin ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Hora Inicio', filled: true, fillColor: AppColors.white),
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
                            labelText: 'Hora Fin', filled: true, fillColor: AppColors.white),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Ubicación ───────────────────────────────────────────────────
              TextFormField(
                controller: _ubicacionController,
                decoration: const InputDecoration(
                    labelText: 'Ubicación / Sala',
                    filled: true, fillColor: AppColors.white),
              ),
              const SizedBox(height: 16),

              // ── Mapa: ubicación GPS ────────────────────────────────────────
              const Text('Ubicación en el mapa',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              const Text('Toca el mapa para marcar el punto exacto.',
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar dirección...',
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(8))),
                      ),
                      onSubmitted: (_) => _searchLocation(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSearching ? null : _searchLocation,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 320,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _markerLatLng,
                    initialZoom: 13,
                    onTap: (tapPosition, point) {
                      setState(() => _markerLatLng = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.gymflow.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _markerLatLng,
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(Icons.location_on,
                              color: AppColors.primary, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lat: ${_markerLatLng.latitude.toStringAsFixed(5)}, '
                'Lng: ${_markerLatLng.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),

              // ── Activa ──────────────────────────────────────────────────────
              SwitchListTile(
                title: const Text('Clase Activa'),
                value: _activa,
                onChanged: (v) => setState(() => _activa = v),
                tileColor: AppColors.white,
              ),
              const SizedBox(height: 16),

              // ── IMAGEN — subida desde dispositivo/navegador ─────────────────
              const Text('Imagen de la Clase',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),

              if (!hasImage)
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
                          width: 1.5),
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
                                fontSize: 12, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                )
              else
                Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.chipBackground),
                      // Image.memory — funciona en Web Y Mobile (no usa dart:io)
                      child: _pickedImageBytes != null
                          ? Image.memory(_pickedImageBytes!, fit: BoxFit.contain)
                          : Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, st) => const Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 48, color: AppColors.textTertiary),
                              ),
                            ),
                    ),
                    Positioned(
                      bottom: 8, left: 8,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Cambiar',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Quitar',
                                  style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Center(
                            child: Column(mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 8),
                                Text('Subiendo imagen...',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              // ─────────────────────────────────────────────────────────────────

              const SizedBox(height: 16),

              // ── Precio ──────────────────────────────────────────────────────
              TextFormField(
                controller: _precioController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Precio', hintText: '0.00',
                    prefixText: 'Bs ', filled: true, fillColor: AppColors.white),
              ),
              const SizedBox(height: 32),

              // ── Guardar ─────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: (_isSaving || _isUploadingImage) ? null : _saveClass,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: (_isSaving || _isUploadingImage)
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Clase',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    _searchController.dispose();
    super.dispose();
  }
}