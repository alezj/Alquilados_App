import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_section_header.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../data/repositories/payment_catalog_repository.dart';
import '../../domain/entities/pago.dart';
import '../providers/payment_mutations_provider.dart';
import 'payment_feedback.dart';

Future<void> showPaymentForm(BuildContext context, {Pago? pago}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PaymentFormSheet(pago: pago),
    );

typedef _FormOptions = (List<Map<String, Object?>>, PaymentCatalog);

class _PaymentFormSheet extends ConsumerStatefulWidget {
  const _PaymentFormSheet({this.pago});

  final Pago? pago;

  @override
  ConsumerState<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends ConsumerState<_PaymentFormSheet> {
  final _form = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(locale: 'es_US', symbol: 'RD\$');
  late final _date = TextEditingController(
    text: widget.pago?.fechaPago ?? _day(DateTime.now()),
  );
  late final _amount = TextEditingController(
    text: widget.pago == null ? '' : _currency.format(widget.pago!.monto),
  );
  late int? _tenant = int.tryParse(widget.pago?.idInquilino ?? '');
  late String? _method = _savedMethod;
  late String? _bank = _savedBank;
  late String _status =
      const {'pagado', 'vencido'}.contains(widget.pago?.estadoNormalizado)
      ? widget.pago!.estadoNormalizado
      : 'pendiente';
  late Future<_FormOptions> _options = _loadOptions();
  bool _saving = false;

  String? get _savedMethod => _nonEmpty(widget.pago?.metodoPago);
  String? get _savedBank => _nonEmpty(widget.pago?.banco);

  String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  String _day(DateTime date) => date.toIso8601String().substring(0, 10);

  Future<_FormOptions> _loadOptions() => (
    ref.read(paymentMutationsProvider).availableTenants(),
    ref.read(paymentCatalogProvider).load(),
  ).wait;

  @override
  void dispose() {
    _date.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.pago != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: editing ? 'Editar pago' : 'Nuevo pago',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 16),
            FutureBuilder<_FormOptions>(
              future: _options,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (!snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No se pudieron cargar los inquilinos o las formas de pago.',
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _options = _loadOptions()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  );
                }
                final (tenants, catalog) = snapshot.requireData;
                return _fields(tenants, catalog);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _fields(
    List<Map<String, Object?>> tenantRows,
    PaymentCatalog catalog,
  ) {
    final tenants = {
      for (final row in tenantRows)
        row['id'] as int: row['nombre_apellido'] as String,
    };
    final savedTenant = int.tryParse(widget.pago?.idInquilino ?? '');
    if (savedTenant != null && widget.pago!.inquilinoNombre.isNotEmpty) {
      tenants.putIfAbsent(savedTenant, () => widget.pago!.inquilinoNombre);
    }

    final methods = {
      ...catalog.methods,
      if (_savedMethod case final method?
          when !catalog.methods.containsKey(method))
        method: _savedBank != null,
    };
    final requiresBank = methods[_method] == true;
    final banks = {
      ...catalog.banks,
      if (_method == _savedMethod && _savedBank != null) _savedBank!,
    };

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.read(paymentMutationsProvider).isOnline) ...[
            const Text('El pago se guarda en el CRM. Requiere conexión.'),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            initialValue: tenants.containsKey(_tenant) ? _tenant : null,
            isExpanded: true,
            decoration: _decoration('Inquilino', Icons.person_rounded),
            items: [
              for (final entry in tenants.entries)
                DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving || tenants.isEmpty ? null : _selectTenant,
            validator: (value) =>
                value == null ? 'Selecciona un inquilino.' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: methods.containsKey(_method) ? _method : null,
            isExpanded: true,
            decoration: _decoration('Forma de pago', Icons.payments_outlined),
            items: [
              for (final method in methods.keys)
                DropdownMenuItem(
                  value: method,
                  child: Text(method, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _saving || methods.isEmpty
                ? null
                : (method) {
                    if (method == _method) return;
                    setState(() {
                      _method = method;
                      _bank = null;
                    });
                  },
            validator: (value) =>
                value == null ? 'Selecciona una forma de pago.' : null,
          ),
          if (methods.isEmpty)
            const Text('Tu empresa no tiene formas de pago activas.'),
          if (requiresBank) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_method),
              initialValue: banks.contains(_bank) ? _bank : null,
              isExpanded: true,
              decoration: _decoration('Banco', Icons.account_balance_outlined),
              items: [
                for (final bank in banks)
                  DropdownMenuItem(
                    value: bank,
                    child: Text(bank, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving || banks.isEmpty
                  ? null
                  : (bank) => setState(() => _bank = bank),
              validator: (value) =>
                  value == null ? 'Selecciona un banco.' : null,
            ),
            if (banks.isEmpty)
              const Text('Tu empresa no tiene bancos activos.'),
          ],
          const SizedBox(height: 12),
          AppTextField(
            label: 'Fecha de pago',
            prefixIcon: Icons.calendar_month_rounded,
            controller: _date,
            readOnly: true,
            onTap: _saving ? null : _pickDate,
            validator: (date) => DateTime.tryParse(date ?? '') == null
                ? 'Selecciona una fecha válida.'
                : null,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: 'Monto',
            prefixIcon: Icons.attach_money_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: _amount,
            readOnly: _saving,
            validator: (_) =>
                _parsedAmount > 0 ? null : 'Ingresa un monto positivo.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: _decoration('Estado', Icons.flag_rounded),
            items: const [
              DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
              DropdownMenuItem(value: 'pagado', child: Text('Pagado')),
              DropdownMenuItem(value: 'vencido', child: Text('Vencido')),
            ],
            onChanged: _saving
                ? null
                : (status) => setState(() => _status = status!),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: widget.pago == null ? 'Guardar pago' : 'Guardar cambios',
            isLoading: _saving,
            onPressed: () => _save(requiresBank),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    border: const OutlineInputBorder(),
  );

  double get _parsedAmount =>
      double.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

  Future<void> _selectTenant(int? id) async {
    setState(() => _tenant = id);
    if (id == null || widget.pago != null) return;
    final originalAmount = _amount.text;
    final amount = await ref.read(paymentMutationsProvider).suggestedAmount(id);
    if (!mounted || _tenant != id || _amount.text != originalAmount) return;
    _amount.text = amount != null && amount > 0 ? _currency.format(amount) : '';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date.text) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (mounted && picked != null) _date.text = _day(picked);
  }

  Future<void> _save(bool requiresBank) async {
    if (_saving || !_form.currentState!.validate()) return;
    final pago = widget.pago;
    final mutations = ref.read(paymentMutationsProvider);
    final tenant = _tenant.toString();
    final date = _date.text.trim();
    final amount = _parsedAmount;
    final bank = requiresBank ? _bank : null;
    final PaymentMethod? method =
        pago != null && _method == _savedMethod && bank == _savedBank
        ? null
        : (name: _method!, bank: bank);

    setState(() => _saving = true);
    final saved = await showPaymentResult(
      context,
      () => pago == null
          ? mutations.create(
              idInquilino: tenant,
              fechaPago: date,
              monto: amount,
              estado: _status,
              method: method,
            )
          : mutations.update(
              pago,
              idInquilino: tenant,
              fechaPago: date,
              monto: amount,
              estado: _status,
              method: method,
            ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }
}
