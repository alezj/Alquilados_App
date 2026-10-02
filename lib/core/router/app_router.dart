import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/alquileres/presentation/pages/alquiler_detalle_page.dart';
import '../../features/alquileres/presentation/pages/alquileres_page.dart';
import '../../features/app_shell.dart';
import '../../features/configuracion/presentation/pages/configuracion_page.dart';
import '../../features/inquilinos/presentation/pages/inquilino_detalle_page.dart';
import '../../features/inquilinos/presentation/pages/inquilinos_page.dart';
import '../../features/login/presentation/pages/login_page.dart';
import '../../features/pagos/presentation/pages/pago_detalle_page.dart';
import '../../features/pagos/presentation/pages/pagos_page.dart';
import '../../features/propiedades/presentation/pages/propiedad_detalle_page.dart';
import '../../features/propiedades/presentation/pages/propiedades_page.dart';
import 'app_routes.dart';

abstract final class AppRouter {
  static GoRouter create({required WidgetBuilder designSystemBuilder}) {
    return GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(path: '/', redirect: (_, _) => AppRoutes.login),
        GoRoute(
          path: AppRoutes.designSystem,
          builder: (context, _) => designSystemBuilder(context),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const LoginPage(),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (_, _) => const AppShell(),
        ),
        GoRoute(
          path: AppRoutes.alquileres,
          builder: (_, _) => const AlquileresPage(),
        ),
        GoRoute(
          path: AppRoutes.alquilerDetalle,
          builder: (_, state) => AlquilerDetallePage(
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: AppRoutes.propiedades,
          builder: (_, _) => const PropiedadesPage(),
        ),
        GoRoute(
          path: AppRoutes.propiedadDetalle,
          builder: (_, state) => PropiedadDetallePage(
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: AppRoutes.inquilinos,
          builder: (_, _) => const InquilinosPage(),
        ),
        GoRoute(
          path: AppRoutes.inquilinoDetalle,
          builder: (_, state) => InquilinoDetallePage(
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(path: AppRoutes.pagos, builder: (_, _) => const PagosPage()),
        GoRoute(
          path: AppRoutes.pagoDetalle,
          builder: (_, state) => PagoDetallePage(
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
        ),
        GoRoute(
          path: AppRoutes.configuracion,
          builder: (_, _) => const ConfiguracionPage(),
        ),
      ],
    );
  }
}

class PendingRoutePage extends StatelessWidget {
  const PendingRoutePage({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            detail == null
                ? 'Esta pantalla está preparada para la siguiente etapa.'
                : '$detail\n\nEsta pantalla está preparada para la siguiente etapa.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
