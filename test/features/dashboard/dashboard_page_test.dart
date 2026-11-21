import 'package:alquilados_app/core/shared/widgets/app_card.dart';
import 'package:alquilados_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, scale, stacked) in [
    (380.0, 1.0, true),
    (430.0, 1.0, true),
    (800.0, 1.0, false),
    (800.0, 2.0, true),
  ]) {
    testWidgets('Dashboard shortcuts at width $width and text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: DashboardQuickActions(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (icon, title) in [
        (Icons.home_work_rounded, 'Alquileres'),
        (Icons.payment_rounded, 'Pagos'),
      ]) {
        final iconFinder = find.byIcon(icon).first;
        final card = find.ancestor(
          of: iconFinder,
          matching: find.byType(AppCard),
        );
        final label = find.descendant(of: card, matching: find.text(title));
        expect(label, findsOneWidget);

        final iconBounds = tester.getRect(iconFinder);
        final labelBounds = tester.getRect(label);
        if (stacked) {
          expect(labelBounds.top, greaterThan(iconBounds.bottom));
          expect(labelBounds.center.dx, closeTo(iconBounds.center.dx, 0.1));
        } else {
          expect(labelBounds.left, greaterThan(iconBounds.right));
          expect(labelBounds.top, lessThan(iconBounds.bottom));
        }
      }
    });
  }
}
