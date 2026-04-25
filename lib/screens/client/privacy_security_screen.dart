import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  final _supabase = Supabase.instance.client;
  bool _sendingReset = false;

  Future<void> _requestPasswordReset() async {
    final user = _supabase.auth.currentUser;
    if (user?.email == null) return;
    setState(() => _sendingReset = true);
    try {
      await _supabase.auth.resetPasswordForEmail(user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace de cambio de contraseña enviado a tu correo'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReset = false);
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
                    child: Text('Privacidad y seguridad',
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
                  // Seguridad de la cuenta
                  _buildSection(
                    icon: Icons.lock_outline,
                    title: 'Seguridad de la cuenta',
                    children: [
                      _buildInfoRow(Icons.email_outlined, 'Correo electrónico',
                          _supabase.auth.currentUser?.email ?? '-'),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.chipBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.password, color: AppColors.primary, size: 20),
                        ),
                        title: const Text('Cambiar contraseña',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Recibirás un enlace en tu correo para cambiarla',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        trailing: _sendingReset
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                        onTap: _sendingReset ? null : _requestPasswordReset,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Protección de datos
                  _buildSection(
                    icon: Icons.shield_outlined,
                    title: 'Protección de datos',
                    children: [
                      _buildTextItem(
                          'Tu información personal (nombre, teléfono, peso, talla) solo es visible para ti y el equipo administrativo de GymFlow.'),
                      _buildTextItem(
                          'Nunca compartimos tus datos con terceros sin tu consentimiento.'),
                      _buildTextItem(
                          'Puedes editar o eliminar tus datos personales en cualquier momento desde tu perfil.'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Recomendaciones
                  _buildSection(
                    icon: Icons.info_outline,
                    title: 'Recomendaciones de seguridad',
                    children: [
                      _buildTextItem('No compartas tu contraseña con nadie.'),
                      _buildTextItem(
                          'Usa una contraseña segura con letras, números y símbolos.'),
                      _buildTextItem(
                          'Si sospechas que alguien accedió a tu cuenta, cambia tu contraseña inmediatamente.'),
                      _buildTextItem(
                          'Cierra sesión cuando uses dispositivos compartidos o públicos.'),
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 18),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildTextItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
