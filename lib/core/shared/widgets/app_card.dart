import 'package:flutter/material.dart';

/// Card estandarizada para listas y resúmenes de Alquilados App.
///
/// Comparación con Angular:
/// Equivale a un `<mat-card>` o un contenedor de componente con estilos unificados.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.color,
    this.borderColor,
    this.borderRadius = 16.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = color ?? theme.cardTheme.color ?? theme.colorScheme.surface;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(
        color: borderColor ?? theme.dividerTheme.color ?? Colors.transparent,
        width: 1,
      ),
    );

    if (onTap != null) {
      return Material(
        color: cardColor,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shape,
      ),
      padding: padding,
      child: child,
    );
  }
}
