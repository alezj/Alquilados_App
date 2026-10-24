import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/policy_document.dart';

/// Proveedor de estado para las políticas de la aplicación.
///
/// Comparación con Angular: Equivale a un `BehaviorSubject<Set<String>>`
/// que guarda los IDs de políticas aceptadas por el usuario.
class PolicyAcceptanceNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void accept(String policyId) {
    final updated = Set<String>.from(state)..add(policyId);
    state = updated;
  }

  void revoke(String policyId) {
    final updated = Set<String>.from(state)..remove(policyId);
    state = updated;
  }

  bool hasAccepted(String policyId) => state.contains(policyId);
}

final policyAcceptanceProvider =
    NotifierProvider<PolicyAcceptanceNotifier, Set<String>>(PolicyAcceptanceNotifier.new);

/// Proveedor que indica si todas las políticas han sido aceptadas.
final allPoliciesAcceptedProvider = Provider<bool>((ref) {
  final accepted = ref.watch(policyAcceptanceProvider);
  return PolicyCatalog.catalog.documents.every(
    (d) => accepted.contains(d.id),
  );
});
