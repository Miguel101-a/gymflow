import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class GeneralConfigScreen extends StatefulWidget {
  const GeneralConfigScreen({super.key});

  @override
  State<GeneralConfigScreen> createState() => _GeneralConfigScreenState();
}

class _GeneralConfigScreenState extends State<GeneralConfigScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nombreController;
  late TextEditingController _telSoporteController;
  late TextEditingController _correoSoporteController;
  late TextEditingController _capacidadController;
  late TextEditingController _politicaController;
  TimeOfDay _apertura = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _cierre = const TimeOfDay(hour: 23, minute: 30);
  bool _notifGenerales = true;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController();
    _telSoporteController = TextEditingController();
    _correoSoporteController = TextEditingController();
    _capacidadController = TextEditingController();
    _politicaController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telSoporteController.dispose();
    _correoSoporteController.dispose();
    _capacidadController.dispose();
    _politicaController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String? s, TimeOfDay fallback) {
    if (s == null || s.isEmpty) return fallback;
    final parts = s.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? fallback.hour,
      minute: int.tryParse(parts[1]) ?? fallback.minute,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    try {
      final config = await _supabase
          .from('configuracion_gimnasio')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _nombreController.text = config?['nombre_gimnasio'] ?? 'GymFlow';
          _telSoporteController.text = config?['telefono_soporte'] ?? '61359146';
          _correoSoporteController.text = config?['correo_soporte'] ?? 'josevap8@gmail.com';
          _capacidadController.text = (config?['capacidad_maxima_default'] ?? 20).toString();
          _politicaController.text = config?['politica_cancelacion'] ??
              'Cancelación con al menos 12 horas de anticipación.';
          _apertura = _parseTime(
              config?['horario_apertura']?.toString(), const TimeOfDay(hour: 7, minute: 0));
          _cierre = _parseTime(
              config?['horario_cierre']?.toString(), const TimeOfDay(hour: 23, minute: 30));
          _notifGenerales = config?['notificaciones_generales_activas'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final capacidad = int.tryParse(_capacidadController.text.trim()) ?? 20;
    try {
      await _supabase.from('configuracion_gimnasio').update({
        'nombre_gimnasio': _nombreController.text.trim(),
        'horario_apertura': _formatTime(_apertura),
        'horario_cierre': _formatTime(_cierre),
        'telefono_soporte': _telSoporteController.text.trim(),
        'correo_soporte': _correoSoporteController.text.trim(),
        'notificaciones_generales_activas': _notifGenerales,
        'capacidad_maxima_default': capacidad,
        'politica_cancelacion': _politicaController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Configuración guardada'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(bool isOpening) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpening ? _apertura : _cierre,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOpening) {
          _apertura = picked;
        } else {
          _cierre = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const Expanded(
                    child: Text('Configuración general',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _section('Información del gimnasio', [
                    CustomTextField(
                      label: 'Nombre del gimnasio',
                      hintText: 'GymFlow',
                      prefixIcon: Icons.store_outlined,
                      controller: _nombreController,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Horario de atención', [
                    Row(
                      children: [
                        Expanded(child: _timeField('Apertura', _apertura, true)),
                        const SizedBox(width: 12),
                        Expanded(child: _timeField('Cierre', _cierre, false)),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Contacto de soporte', [
                    CustomTextField(
                      label: 'Teléfono',
                      hintText: '61359146',
                      prefixIcon: Icons.phone_outlined,
                      controller: _telSoporteController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Correo de soporte',
                      hintText: 'josevap8@gmail.com',
                      prefixIcon: Icons.email_outlined,
                      controller: _correoSoporteController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Configuración de clases', [
                    CustomTextField(
                      label: 'Capacidad máxima por defecto',
                      hintText: '20',
                      prefixIcon: Icons.people_outline,
                      controller: _capacidadController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Política de cancelación',
                      hintText: 'Texto que verán los clientes',
                      prefixIcon: Icons.policy_outlined,
                      controller: _politicaController,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _section('Notificaciones', [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        title: const Text('Notificaciones generales',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          'Activa o desactiva el envío global de avisos a los usuarios.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _notifGenerales,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _notifGenerales = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : PrimaryButton(text: 'Guardar configuración', onPressed: _save),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay value, bool isOpening) {
    return GestureDetector(
      onTap: () => _pickTime(isOpening),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(_formatTime(value),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
