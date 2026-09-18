import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Tipo semántico de estado para el badge
enum StatusBadgeType {
  success, // Disponible / Pagado / Al día
  info, // Alquilado / En contrato
  warning, // Mantenimiento / Próximo a vencer / Pendiente
  error, // En mora / Vencido / Desocupado irregular
  neutral, // Inactivo / Borrador
}

/// Chip o Badge de estado para propiedades, inquilinos y pagos.
///
/// Comparación con Angular:
/// Equivale a un `<span class="badge badge-success">Disponible</span>`.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.info,
    this.icon,
  });

  /// Crea un badge a partir del texto de estado devuelto por el backend
  factory StatusBadge.fromString(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized.contains('disponible') ||
        normalized.contains('al dia') ||
        normalized.contains('al día') ||
        normalized.contains('pagado') ||
        normalized.contains('activo')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } else if (normalized.contains('alquilado') ||
        normalized.contains('ocupado') ||
        normalized.contains('contrato')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.info,
        icon: Icons.key_rounded,
      );
    } else if (normalized.contains('mantenimiento') ||
        normalized.contains('pendiente') ||
        normalized.contains('proximo') ||
        normalized.contains('próximo')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.warning,
        icon: Icons.access_time_rounded,
      );
    } else if (normalized.contains('mora') ||
        normalized.contains('vencido') ||
        normalized.contains('atrasado') ||
        normalized.contains('cancelado')) {
      return StatusBadge(
        label: status,
        type: StatusBadgeType.error,
        icon: Icons.error_outline_rounded,
      );
    }

    return StatusBadge(
      label: status,
      type: StatusBadgeType.neutral,
    );
  }

  final String label;
  final StatusBadgeType type;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _getColors(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.statusBadge.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  (Color, Color) _getColors(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (type) {
      case StatusBadgeType.success:
        return (
          isDark ? AppColors.successDark.withValues(alpha: 0.3) : AppColors.successLight,
          isDark ? AppColors.successLight : AppColors.successDark,
        );
      case StatusBadgeType.info:
        return (
          isDark ? AppColors.infoDark.withValues(alpha: 0.3) : AppColors.infoLight,
          isDark ? AppColors.infoLight : AppColors.infoDark,
        );
      case StatusBadgeType.warning:
        return (
          isDark ? AppColors.warningDark.withValues(alpha: 0.3) : AppColors.warningLight,
          isDark ? AppColors.warningLight : AppColors.warningDark,
        );
      case StatusBadgeType.error:
        return (
          isDark ? AppColors.errorDark.withValues(alpha: 0.3) : AppColors.errorLight,
          isDark ? AppColors.errorLight : AppColors.errorDark,
        );
      case StatusBadgeType.neutral:
        return (
          isDark ? AppColors.cardDark : AppColors.borderLight,
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        );
    }
  }
}
