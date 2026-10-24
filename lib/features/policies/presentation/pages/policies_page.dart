import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_button.dart';
import '../../domain/entities/policy_document.dart';

/// Página de lista de políticas con botones de aceptar/rechazar.
class PoliciesPage extends StatelessWidget {
  const PoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = PolicyCatalog.catalog;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.policy_outlined, size: 28),
                  const SizedBox(width: 12),
                  Text('Políticas', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              ...catalog.documents.map((doc) => _PolicyTile(
                document: doc,
                isAccepted: false,
                onAccept: () {},
                onReject: () {},
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyTile extends StatelessWidget {
  const _PolicyTile({
    required this.document,
    required this.isAccepted,
    required this.onAccept,
    required this.onReject,
  });

  final PolicyDocument document;
  final bool isAccepted;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(document.icono, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    document.titulo,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (isAccepted) const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              document.cuerpo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: 'Ver', variant: AppButtonVariant.outline,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: isAccepted ? 'Revocar' : 'Aceptar',
                    variant: isAccepted ? AppButtonVariant.danger : AppButtonVariant.primary,
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
