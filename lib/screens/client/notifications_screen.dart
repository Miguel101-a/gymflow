import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final notifications = await _supabase
          .from('comunicaciones')
          .select()
          .or('usuario_id.eq.${user.id},and(usuario_id.is.null,grupo_destinatario.eq.todos)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase
          .from('comunicaciones')
          .update({'leida': true})
          .eq('id', id);
      _fetchNotifications();
    } catch (_) {}
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  ({IconData icon, Color color, String label}) _typeInfo(String? tipo) {
    switch (tipo) {
      case 'cancelacion':
        return (
          icon: Icons.event_busy,
          color: AppColors.error,
          label: 'Cancelación',
        );
      case 'aviso':
        return (
          icon: Icons.campaign_outlined,
          color: AppColors.warning,
          label: 'Aviso',
        );
      default:
        return (
          icon: Icons.notifications_outlined,
          color: AppColors.primary,
          label: 'General',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.textTertiary),
                        SizedBox(height: 16),
                        Text('No hay notificaciones', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchNotifications,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        final id = notif['id']?.toString();
                        final title = notif['asunto'] ?? 'Sin asunto';
                        final message = notif['contenido'] ?? '';
                        final date = notif['created_at'] != null
                            ? _formatDate(notif['created_at'])
                            : '';
                        final tipo = notif['tipo']?.toString();
                        final leida = notif['leida'] == true;
                        final info = _typeInfo(tipo);

                        return GestureDetector(
                          onTap: () {
                            if (!leida && id != null) _markAsRead(id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: leida ? AppColors.white : info.color.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: leida
                                    ? AppColors.border
                                    : info.color.withValues(alpha: 0.4),
                                width: leida ? 0.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: info.color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(info.icon, size: 16, color: info.color),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: info.color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        info.label.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: info.color,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!leida)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: info.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(title,
                                    style: TextStyle(
                                      fontWeight: leida ? FontWeight.w600 : FontWeight.w700,
                                      fontSize: 16,
                                    )),
                                const SizedBox(height: 6),
                                Text(message,
                                    style: const TextStyle(
                                        fontSize: 14, color: AppColors.textSecondary)),
                                const SizedBox(height: 10),
                                Text(date,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textTertiary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
