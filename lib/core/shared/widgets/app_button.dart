import 'package:flutter/material.dart';

import '../../theme/app_typography.dart';

/// Tipos de botones disponibles en el sistema de diseño
enum AppButtonVariant { primary, secondary, outline, danger, text }

/// Botón estandarizado del sistema con soporte para `isLoading`, íconos y variantes.
///
/// Comparación con Angular:
/// Equivale a un `<button app-button [variant]="'primary'" [loading]="loading">Guardar</button>`.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.isDense = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final action = isLoading ? null : onPressed;
    final minimumSize = Size(0, isDense ? 44 : 50);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final textStyle = AppTypography.labelLarge;

    final label = Text(text, textAlign: TextAlign.center);
    final child = isLoading
        ? Semantics(
            label: text,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colors.primary,
              ),
            ),
          )
        : icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.outline => OutlinedButton(
        onPressed: action,
        style: OutlinedButton.styleFrom(
          minimumSize: minimumSize,
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.outlineVariant),
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: action,
        style: TextButton.styleFrom(
          minimumSize: minimumSize,
          foregroundColor: colors.primary,
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      ),
      _ => FilledButton(
        onPressed: action,
        style: FilledButton.styleFrom(
          minimumSize: minimumSize,
          backgroundColor: switch (variant) {
            AppButtonVariant.danger => colors.error,
            AppButtonVariant.secondary => colors.secondaryContainer,
            _ => colors.primary,
          },
          foregroundColor: switch (variant) {
            AppButtonVariant.danger => colors.onError,
            AppButtonVariant.secondary => colors.onSecondaryContainer,
            _ => colors.onPrimary,
          },
          shape: shape,
          textStyle: textStyle,
        ),
        child: child,
      ),
    };

    return SizedBox(width: isFullWidth ? double.infinity : null, child: button);
  }
}
