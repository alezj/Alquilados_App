import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../domain/entities/policy_document.dart';
import '../providers/policy_provider.dart';
import 'policy_detail_page.dart';

/// Página de aceptación de políticas donde el usuario debe revisar
/// y aceptar cada política antes de continuar.
class PolicyAcceptancePage extends ConsumerWidget {
  const PolicyAcceptancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = PolicyCatalog.catalog;
    final accepted = ref.watch(policyAcceptanceProvider);
    final allAccepted = catalog.documents.every(
      (d) => accepted.contains(d.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Políticas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.policy_outlined, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Políticas', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Para continuar con el registro o inicio de sesión, revise y acepte las políticas.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...catalog.documents.map((doc) {
              final isAccepted = accepted.contains(doc.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(doc.icono, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              doc.titulo,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (isAccepted)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        doc.cuerpo,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'Ver',
                              variant: AppButtonVariant.outline,
                              onPressed: () => _showDetail(context, doc),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              text: isAccepted ? 'Revocado' : 'Aceptar',
                              variant: isAccepted ? AppButtonVariant.danger : AppButtonVariant.primary,
                              onPressed: () {
                                ref.read(policyAcceptanceProvider.notifier).accept(doc.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${doc.titulo} aceptada.')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (!allAccepted) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppButton(
                  text: 'Continuar',
                  variant: AppButtonVariant.primary,
                  isFullWidth: true,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Complete todos los términos para continuar.')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, PolicyDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PolicyDetailPage(document: doc),
      ),
    );
  }
}
