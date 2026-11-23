import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppAccent {
  blue('Azul', AppColors.primary, AppColors.primaryDark),
  teal('Verde petróleo', Color(0xFF0F6860), Color(0xFF104943)),
  violet('Violeta', Color(0xFF6941A5), Color(0xFF472F76)),
  terracotta('Terracota', Color(0xFFA3432C), Color(0xFF743120));

  const AppAccent(this.label, this.primary, this.deep);

  final String label;
  final Color primary;
  final Color deep;
}

class AppBrandColors extends ThemeExtension<AppBrandColors> {
  const AppBrandColors(this.primary, this.deep);

  final Color primary;
  final Color deep;

  static AppBrandColors of(BuildContext context) =>
      Theme.of(context).extension<AppBrandColors>() ??
      const AppBrandColors(AppColors.primary, AppColors.primaryDark);

  @override
  AppBrandColors copyWith({Color? primary, Color? deep}) =>
      AppBrandColors(primary ?? this.primary, deep ?? this.deep);

  @override
  AppBrandColors lerp(AppBrandColors? other, double t) {
    if (other == null) return this;
    return AppBrandColors(
      Color.lerp(primary, other.primary, t)!,
      Color.lerp(deep, other.deep, t)!,
    );
  }
}
