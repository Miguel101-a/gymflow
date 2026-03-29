import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'instructor_dashboard_screen.dart';
import 'instructor_classes_screen.dart';
import 'instructor_students_screen.dart';
import '../admin/calendar_screen.dart';
import '../admin/communications_screen.dart';

class InstructorShell extends StatefulWidget {
  const InstructorShell({super.key});

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InstructorDashboardScreen(),
    InstructorClassesScreen(),
    InstructorStudentsScreen(),
    CalendarScreen(),
    CommunicationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'Inter'),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'INICIO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'MIS CLASES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'ALUMNOS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'CALENDARIO',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.mail_outline),
              activeIcon: Icon(Icons.mail),
              label: 'MENSAJES',
            ),
          ],
        ),
      ),
    );
  }
}