import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'app_accent.dart';

typedef AppAppearance = ({AppAccent accent, ThemeMode mode});

const AppAppearance defaultAppearance = (
  accent: AppAccent.blue,
  mode: ThemeMode.light,
);

final initialAppearanceProvider = Provider<AppAppearance>(
  (_) => defaultAppearance,
);

final appearanceProvider =
    NotifierProvider<AppearanceController, AppAppearance>(
      AppearanceController.new,
    );

extension ThemeModeLabel on ThemeMode {
  String get label => switch (this) {
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
    ThemeMode.system => 'Sistema',
  };
}

Future<AppAppearance> loadAppearance(SecureStorageService storage) async {
  try {
    final saved = (await storage.readAppearance())?.split(':');
    if (saved == null || saved.length != 2) return defaultAppearance;
    return (
      accent: AppAccent.values.firstWhere(
        (accent) => accent.name == saved.first,
        orElse: () => defaultAppearance.accent,
      ),
      mode: ThemeMode.values.firstWhere(
        (mode) => mode.name == saved.last,
        orElse: () => defaultAppearance.mode,
      ),
    );
  } catch (error, stack) {
    AppLogger.e('Error leyendo el tema de la aplicación', error, stack);
    return defaultAppearance;
  }
}

class AppearanceController extends Notifier<AppAppearance> {
  final _storage = SecureStorageService();
  Future<bool> _lastSave = Future.value(true);

  @override
  AppAppearance build() => ref.watch(initialAppearanceProvider);

  Future<bool> update({AppAccent? accent, ThemeMode? mode}) {
    final next = (accent: accent ?? state.accent, mode: mode ?? state.mode);
    state = next;
    _lastSave = _lastSave.then((_) async {
      try {
        await _storage.saveAppearance('${next.accent.name}:${next.mode.name}');
        return true;
      } catch (error, stack) {
        AppLogger.e('Error guardando el tema de la aplicación', error, stack);
        return false;
      }
    });
    return _lastSave;
  }
}
