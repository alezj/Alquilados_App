import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';

/// Widget para mostrar errores de forma amigable al usuario con opción de reintentar.
///
/// Comparación con Angular:
/// Equivale a un `<app-error-state [message]="msg" (retry)="reload()"></app-error-state>`.
class AppError extends StatelessWidget {
  const AppError({
    super.key,
    required this.message,
    this.title = 'Algo salió mal',
    this.onRetry,
    this.retryText = 'Reintentar',
    this.icon = Icons.error_outline_rounded,
  });

  /// Mensaje legible para el usuario (nunca mostrar un stacktrace o error 500 crudo aquí)
  final String message;

  /// Título del error
  final String title;

  /// Callback para reintentar la operación (opcional)
  final VoidCallback? onRetry;

  /// Texto del botón de reintento
  final String retryText;

  /// Ícono a mostrar
  final IconData icon;

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
            // Círculo de fondo para el ícono de error
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Mensaje amigable
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),

            // Botón de reintento si fue proporcionado
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 160,
                child: AppButton(
                  text: retryText,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
