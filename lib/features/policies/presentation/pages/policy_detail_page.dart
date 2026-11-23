import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/app_card.dart';
import '../../../../core/shared/widgets/app_section_header.dart';
import '../../domain/entities/policy_document.dart';

/// Página de detalle de una política mostrando el texto completo.
class PolicyDetailPage extends StatelessWidget {
  const PolicyDetailPage({super.key, required this.document});

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Políticas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(title: document.titulo, icon: document.icono),
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
