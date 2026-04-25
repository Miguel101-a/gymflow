import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class BusinessRulesScreen extends StatelessWidget {
  const BusinessRulesScreen({super.key});

  static const List<String> _rules = [
    'Los clientes solo pueden reservar clases activas y con cupos disponibles.',
    'Un cliente no puede reservar dos veces la misma clase.',
    'Si una clase alcanza su capacidad máxima, debe bloquear nuevas reservas.',
    'Solo administradores e instructores autorizados pueden crear clases.',
    'El instructor solo puede gestionar las clases que creó o que tiene asignadas.',
    'Si una clase se cancela, los clientes inscritos deben recibir una notificación.',
    'Las reservas deben tener estados como: confirmada, cancelada o pendiente.',
    'Los usuarios deben tener un rol principal válido: cliente, instructor o admin.',
    'El administrador puede cambiar roles y permisos de los usuarios.',
    'Los datos personales del usuario deben estar protegidos y solo ser editables por el dueño del perfil o por un administrador autorizado.',
    'Las clases deben tener fecha, hora de inicio, hora de fin, instructor, capacidad máxima, nivel y ubicación.',
    'El sistema debe evitar conflictos de horario entre clases del mismo instructor.',
    'El gimnasio atiende en el horario de 7:00 a. m. a 11:30 p. m.',
    'No se deben crear clases fuera del horario de atención del gimnasio.',
    'Las notificaciones deben enviarse cuando exista una cancelación, modificación o comunicado importante.',
    'El cliente solo puede ver y gestionar sus propias reservas.',
    'El instructor solo puede ver alumnos inscritos en sus propias clases.',
    'Solo el administrador puede acceder a configuración general y administración de roles.',
  ];

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
                    child: Text('Reglas del Negocio',
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.gavel_outlined, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Políticas y normas que rigen el funcionamiento de GymFlow.',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_rules.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.chipBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _rules[index],
                              style: const TextStyle(
                                  fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
