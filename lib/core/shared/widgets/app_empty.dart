import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// Widget para mostrar estados vacíos cuando una consulta no arroja resultados.
///
/// Comparación con Angular:
/// Equivale a un bloque `<ng-container *ngIf="items.length === 0">...<app-empty-state></ng-container>`.
class AppEmpty extends StatelessWidget {
  const AppEmpty({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
  });

  /// Título principal (ej: "No hay propiedades registradas")
  final String title;

  /// Descripción complementaria (ej: "Agrega tu primer inmueble para comenzar")
  final String? message;

  /// Ícono a mostrar
  final IconData icon;

  /// Texto del botón de acción (opcional)
  final String? actionText;

  /// Callback al presionar el botón de acción
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono ilustrativo en contenedor circular
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppColors.textMutedLight,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),

            // Mensaje
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],

            // Botón de acción opcional
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                isDense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
