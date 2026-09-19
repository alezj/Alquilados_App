import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

abstract final class AppRouter {
  static GoRouter create({required WidgetBuilder designSystemBuilder}) {
    return GoRouter(
      initialLocation: AppRoutes.designSystem,
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => AppRoutes.designSystem,
        ),
        GoRoute(
          path: AppRoutes.designSystem,
          builder: (context, __) => designSystemBuilder(context),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const PendingRoutePage(title: 'Iniciar sesión'),
        ),
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (_, __) => const PendingRoutePage(title: 'Dashboard'),
        ),
        GoRoute(
          path: AppRoutes.propiedades,
          builder: (_, __) => const PendingRoutePage(title: 'Propiedades'),
        ),
        GoRoute(
          path: AppRoutes.propiedadDetalle,
          builder: (_, state) => PendingRoutePage(
            title: 'Detalle de propiedad',
            detail: 'Identificador: ${state.pathParameters['id']}',
          ),
        ),
        GoRoute(
          path: AppRoutes.inquilinos,
          builder: (_, __) => const PendingRoutePage(title: 'Inquilinos'),
        ),
        GoRoute(
          path: AppRoutes.inquilinoDetalle,
          builder: (_, state) => PendingRoutePage(
            title: 'Detalle de inquilino',
            detail: 'Identificador: ${state.pathParameters['id']}',
          ),
        ),
        GoRoute(
          path: AppRoutes.pagos,
          builder: (_, __) => const PendingRoutePage(title: 'Pagos'),
        ),
        GoRoute(
          path: AppRoutes.configuracion,
          builder: (_, __) => const PendingRoutePage(title: 'Configuración'),
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