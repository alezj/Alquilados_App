import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:alquilados_app/core/theme/app_accent.dart';
import 'package:alquilados_app/core/theme/app_appearance.dart';
import 'package:alquilados_app/core/theme/app_theme.dart';
import 'package:alquilados_app/features/configuracion/presentation/pages/configuracion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Acciones aplica el tema y guarda la última selección', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, child) {
            final appearance = ref.watch(appearanceProvider);
            return MaterialApp(
              theme: AppTheme.light(appearance.accent),
              darkTheme: AppTheme.dark(appearance.accent),
              themeMode: appearance.mode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.65)),
                child: child!,
              ),
              home: const Scaffold(body: ConfiguracionPage()),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final settings = find.text('Tema y colores');
    await tester.scrollUntilVisible(settings, 120);
    await tester.pumpAndSettle();
    await tester.tap(settings);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Violeta'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Violeta'))).colorScheme.primary,
      AppAccent.violet.primary,
    );

    await tester.ensureVisible(find.text('Oscuro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Oscuro'))).brightness,
      Brightness.dark,
    );
    await tester.ensureVisible(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Violeta · Oscuro'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final storage = SecureStorageService();
    await storage.clearSession();
    expect(await loadAppearance(storage), (
      accent: AppAccent.violet,
      mode: ThemeMode.dark,
    ));
  });

  test('Una preferencia inválida conserva el tema predeterminado', () async {
    FlutterSecureStorage.setMockInitialValues({'app_appearance': 'a:b'});
    expect(await loadAppearance(SecureStorageService()), defaultAppearance);
  });
}
