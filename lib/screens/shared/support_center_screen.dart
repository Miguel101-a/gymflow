import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

  static const _phone = '61359146';
  static const _email = 'josevap8@gmail.com';

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
                    child: Text('Centro de soporte',
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
                  // Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.headset_mic, color: Colors.white, size: 40),
                        SizedBox(height: 12),
                        Text('¿Necesitas ayuda?',
                            style: TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        Text(
                          'Si tienes alguna consulta sobre tus reservas, clases, pagos o problemas con tu cuenta, comunícate con nuestro equipo de soporte.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Canales de contacto
                  const Text('Canales de contacto',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  _buildContactCard(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'Teléfono / WhatsApp',
                    value: _phone,
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: _phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Número copiado al portapapeles'),
                            backgroundColor: AppColors.success),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Correo electrónico',
                    value: _email,
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: _email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Correo copiado al portapapeles'),
                            backgroundColor: AppColors.success),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Preguntas frecuentes
                  const Text('Preguntas frecuentes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _buildFaq('¿Cómo cancelo una reserva?',
                      'Ve a la sección "Reservas", selecciona la clase y presiona "Cancelar". Recuerda que la cancelación debe realizarse con al menos 12 horas de anticipación.'),
                  _buildFaq('¿Puedo cambiar mi clase reservada?',
                      'Actualmente debes cancelar la reserva existente y crear una nueva para la clase deseada.'),
                  _buildFaq('¿Cómo actualizo mi información de pago?',
                      'Contáctanos directamente por teléfono o correo electrónico para gestionar cambios en tu método de pago.'),
                  _buildFaq('¿Cuál es el horario del gimnasio?',
                      'GymFlow atiende de lunes a domingo de 7:00 a. m. a 11:30 p. m.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.copy_outlined, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFaq(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        iconColor: AppColors.primary,
        children: [
          Text(answer,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}
