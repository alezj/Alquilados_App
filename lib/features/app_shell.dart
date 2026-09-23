import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_typography.dart';
import 'dashboard/presentation/pages/dashboard_page.dart';
import 'inquilinos/presentation/pages/inquilinos_page.dart';
import 'pagos/presentation/pages/pagos_page.dart';
import 'propiedades/presentation/pages/propiedades_page.dart';
import 'configuracion/presentation/pages/configuracion_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    DashboardPage(),
    PropiedadesPage(),
    InquilinosPage(),
    PagosPage(),
    ConfiguracionPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final title = switch (_selectedIndex) {
      0 => 'Dashboard',
      1 => 'Propiedades',
      2 => 'Inquilinos',
      3 => 'Pagos',
      _ => 'Configuración',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTypography.titleMedium),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Propiedades'),
          NavigationDestination(icon: Icon(Icons.people_rounded), label: 'Inquilinos'),
          NavigationDestination(icon: Icon(Icons.payments_rounded), label: 'Pagos'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
