import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_typography.dart';
import 'alquileres/presentation/pages/alquileres_page.dart';
import 'configuracion/presentation/pages/configuracion_page.dart';
import 'dashboard/presentation/pages/dashboard_page.dart';
import 'pagos/presentation/pages/pagos_page.dart';

class AppShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
  void goToDashboard() => state = 0;
  void goToAlquileres() => state = 1;
  void goToPagos() => state = 2;
  void goToAcciones() => state = 3;
}

final appShellTabProvider =
    NotifierProvider<AppShellTabNotifier, int>(AppShellTabNotifier.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const List<Widget> _pages = [
    DashboardPage(),
    AlquileresPage(),
    PagosPage(),
    ConfiguracionPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(appShellTabProvider);

    final title = switch (selectedIndex) {
      0 => 'Dashboard',
      1 => 'Alquileres',
      2 => 'Pagos',
      _ => 'Acciones',
    };

    return Scaffold(
      appBar: (selectedIndex == 0 || selectedIndex == 3)
          ? AppBar(
              title: Text(title, style: AppTypography.titleMedium),
            )
          : null,
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            ref.read(appShellTabProvider.notifier).setTab(index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_rounded),
            label: 'Alquileres',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_rounded),
            label: 'Pagos',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_circle_rounded),
            label: 'Acciones',
          ),
        ],
      ),
    );
  }
}
