import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_accent.dart';
import '../../../../core/theme/app_appearance.dart';

class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.palette_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Tema y colores'),
      subtitle: Text('${appearance.accent.label} · ${appearance.mode.label}'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _AppearancePicker(),
      ),
    );
  }
}

class _AppearancePicker extends ConsumerWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    Future<void> update({AppAccent? accent, ThemeMode? mode}) async {
      final saved = await controller.update(accent: accent, mode: mode);
      if (!saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el tema.')),
        );
      }
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tema y colores', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Color de acento', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final accent in AppAccent.values)
                  ChoiceChip(
                    label: Text(accent.label),
                    avatar: CircleAvatar(backgroundColor: accent.primary),
                    selected: appearance.accent == accent,
                    onSelected: (_) => update(accent: accent),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Apariencia', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in ThemeMode.values)
                  ChoiceChip(
                    label: Text(mode.label),
                    selected: appearance.mode == mode,
                    onSelected: (_) => update(mode: mode),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Listo'),
            ),
          ],
        ),
      ),
    );
  }
}
