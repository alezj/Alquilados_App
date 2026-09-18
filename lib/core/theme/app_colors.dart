import 'package:flutter/material.dart';

/// Paleta de colores centralizada del sistema Alquilados.
///
/// Comparación con Angular:
/// Equivale a las variables CSS / tokens en `_variables.scss` o `tailwind.config.js`.
abstract final class AppColors {
  // --- Colores Principales de Marca ---
  // Azul pizarra corporativo elegante
  static const Color primary = Color(0xFF1E40AF); // Blue 800
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF1E3A8A); // Blue 900

  // Acento secundario (Cian moderno para detalles interactivos)
  static const Color secondary = Color(0xFF0EA5E9); // Sky 500
  static const Color secondaryLight = Color(0xFF38BDF8); // Sky 400
  static const Color secondaryDark = Color(0xFF0284C7); // Sky 600

  // --- Estados de Negocio (Inmuebles, Alquileres, Pagos) ---
  // Verde: Propiedad disponible / Pago al día / Éxito
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color successDark = Color(0xFF047857); // Emerald 700

  // Azul: Propiedad alquilada / Contrato activo
  static const Color info = Color(0xFF2563EB); // Blue 600
  static const Color infoLight = Color(0xFFDBEAFE); // Blue 100
  static const Color infoDark = Color(0xFF1D4ED8); // Blue 700

  // Amarillo/Ámbar: En mantenimiento / Pago próximo a vencer
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningDark = Color(0xFFB45309); // Amber 700

  // Rojo/Rose: Pago vencido / En mora / Error crítico
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color errorLight = Color(0xFFFEE2E2); // Red 100
  static const Color errorDark = Color(0xFFB91C1C); // Red 700

  // --- Neutros (Modo Claro) ---
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF); // Blanco puro
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  // --- Neutros (Modo Oscuro) ---
  static const Color backgroundDark = Color(0xFF0B0F17); // Slate casi negro
  static const Color surfaceDark = Color(0xFF151C28); // Slate 900
  static const Color cardDark = Color(0xFF1E293B); // Slate 800
  static const Color borderDark = Color(0xFF334155); // Slate 700
  static const Color textPrimaryDark = Color(0xFFF8FAFC); // Slate 50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textMutedDark = Color(0xFF64748B); // Slate 500
}
