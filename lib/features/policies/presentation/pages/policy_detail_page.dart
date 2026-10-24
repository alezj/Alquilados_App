import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/policy_document.dart';

/// Página de detalle de una política mostrando el texto completo.
class PolicyDetailPage extends StatelessWidget {
  const PolicyDetailPage({
    super.key,
    required this.document,
  });

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(document.titulo),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.titulo,
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: 16),
              Text(
                document.cuerpo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.75,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
