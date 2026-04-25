import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _notificacionesActivas = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final profile = await _supabase
          .from('perfiles')
          .select('notificaciones_activas')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _notificacionesActivas = profile['notificaciones_activas'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreference(bool value) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() {
      _notificacionesActivas = value;
      _isSaving = true;
    });
    try {
      await _supabase
          .from('perfiles')
          .update({'notificaciones_activas': value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Notificaciones activadas' : 'Notificaciones desactivadas'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _notificacionesActivas = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const Expanded(
                    child: Text('Notificaciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: const Text('Activar notificaciones',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          'Recibe avisos sobre clases, cancelaciones y comunicados del gimnasio.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        value: _notificacionesActivas,
                        activeColor: AppColors.primary,
                        onChanged: _isSaving ? null : _savePreference,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Recibirás notificaciones cuando:',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 12),
                          _NotifItem('Nueva clase disponible en tu horario'),
                          _NotifItem('Una clase reservada fue cancelada'),
                          _NotifItem('Cambios de horario en tus clases'),
                          _NotifItem('Comunicados importantes del gimnasio'),
                          _NotifItem('Recordatorios de clases próximas'),
                        ],
                      ),
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

class _NotifItem extends StatelessWidget {
  final String text;
  const _NotifItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
