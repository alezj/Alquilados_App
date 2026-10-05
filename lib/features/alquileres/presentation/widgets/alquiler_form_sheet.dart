import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/shared/widgets/app_button.dart';
import '../../../../core/shared/widgets/app_text_field.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/alquiler.dart';

class AlquilerFormSheet extends StatefulWidget {
  const AlquilerFormSheet({super.key, this.alquiler});

  final Alquiler? alquiler;

  @override
  State<AlquilerFormSheet> createState() => _AlquilerFormSheetState();
}

class _AlquilerFormSheetState extends State<AlquilerFormSheet> {
  final _propiedadController = ValueNotifier<int>(0);
  final _inquilinoController = ValueNotifier<int>(0);
  final _montoPagoController = TextEditingController();
  final _cantidadDepositosController = TextEditingController();
  final _diaPagoController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();
  final _estadoController = ValueNotifier<String>('Activo');
  List<Map<String, dynamic>> _propiedades = const [];
  List<Map<String, dynamic>> _inquilinos = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();

    if (widget.alquiler != null) {
      _propiedadController.value = widget.alquiler!.propiedadId;
      _inquilinoController.value = widget.alquiler!.inquilinoId;
      _montoPagoController.text = _currency(_toDouble(widget.alquiler!.montoPago));
      _cantidadDepositosController.text = widget.alquiler!.cantidadDepositos.toString();
      _diaPagoController.text = widget.alquiler!.diaPago.toString();
      _fechaInicioController.text = widget.alquiler!.fechaInicio;
      _fechaFinController.text = widget.alquiler!.fechaFin ?? '';
      _estadoController.value = widget.alquiler!.estado;
    }
  }

  Future<void> _loadCatalog() async {
    final db = LocalDatabaseService();
    final propiedades = await db.getAllRows('propiedades');
    final inquilinos = await db.getAllRows('inquilinos');

    if (!mounted) return;
    setState(() {
      _propiedades = propiedades;
      _inquilinos = inquilinos;
      _isLoading = false;
      if (_propiedadController.value == 0 && _propiedades.isNotEmpty) {
        _propiedadController.value = (_propiedades.first['id'] as int?) ?? 0;
      }
      if (_inquilinoController.value == 0 && _inquilinos.isNotEmpty) {
        _inquilinoController.value = (_inquilinos.first['id'] as int?) ?? 0;
      }

      // Solo al crear: al editar se respeta el monto ya guardado
      if (widget.alquiler == null) {
        _aplicarPrecioMensual(_propiedadController.value);
      }
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _currency(double amount) {
    final format = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$', decimalDigits: 2);
    return format.format(amount);
  }

  double? _parseCurrency(String text) {
    // Deja solo dígitos y punto decimal: "RD$25,000.00" -> "25000.00"
    final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean);
  }

  void _aplicarPrecioMensual(int propiedadId) {
    final propiedad = _propiedades.firstWhere(
      (item) => (item['id'] as int?) == propiedadId,
      orElse: () => <String, dynamic>{},
    );

    final precio = _toDouble(propiedad['precio_mensual']);
    _montoPagoController.text = precio > 0 ? _currency(precio) : '';
  }

  Future<void> _pickDate({required bool isInicio}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(isInicio
              ? (_fechaInicioController.text.isNotEmpty
                  ? _fechaInicioController.text
                  : now.toIso8601String())
              : (_fechaFinController.text.isNotEmpty
                  ? _fechaFinController.text
                  : now.toIso8601String())) ??
          now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    final isoDate = picked.toIso8601String().split('T').first;
    setState(() {
      if (isInicio) {
        _fechaInicioController.text = isoDate;
      } else {
        _fechaFinController.text = isoDate;
      }
    });
  }

  Future<void> _save() async {
    final propiedadId = _propiedadController.value;
    final inquilinoId = _inquilinoController.value;
    final montoPago = _parseCurrency(_montoPagoController.text.trim());
    final cantidadDepositos = int.tryParse(_cantidadDepositosController.text.trim()) ?? 0;
    final diaPago = int.tryParse(_diaPagoController.text.trim()) ?? 1;
    final fechaInicio = _fechaInicioController.text.trim();
    final fechaFin = _fechaFinController.text.trim();

    if (propiedadId == 0 || inquilinoId == 0) {
      _showMessage('Debes seleccionar una propiedad y un inquilino.');
      return;
    }

    if (fechaInicio.isEmpty) {
      _showMessage('La fecha de inicio es obligatoria.');
      return;
    }

    if (montoPago == null || montoPago <= 0) {
      _showMessage('El monto a pagar debe ser mayor que cero.');
      return;
    }

    if (cantidadDepositos < 0 || diaPago < 1 || diaPago > 31) {
      _showMessage('La cantidad de depósitos debe ser 0 o mayor y el día de pago debe estar entre 1 y 31.');
      return;
    }

    try {
      final db = LocalDatabaseService();
      if (widget.alquiler == null) {
        await db.insertAlquiler(
          propiedadId: propiedadId,
          inquilinoId: inquilinoId,
          fechaInicio: fechaInicio,
          fechaFin: fechaFin.isEmpty ? null : fechaFin,
          importe: montoPago,
          montoPago: montoPago,
          cantidadDepositos: cantidadDepositos,
          diaPago: diaPago,
          estado: _estadoController.value,
        );
      } else {
        await db.updateAlquiler(
          id: widget.alquiler!.id,
          propiedadId: propiedadId,
          inquilinoId: inquilinoId,
          fechaInicio: fechaInicio,
          fechaFin: fechaFin.isEmpty ? null : fechaFin,
          importe: montoPago,
          montoPago: montoPago,
          cantidadDepositos: cantidadDepositos,
          diaPago: diaPago,
          estado: _estadoController.value,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _showMessage('No se pudo guardar el alquiler: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _propiedadController.dispose();
    _inquilinoController.dispose();
    _montoPagoController.dispose();
    _cantidadDepositosController.dispose();
    _diaPagoController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.alquiler == null ? 'Nuevo alquiler' : 'Editar alquiler';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ValueListenableBuilder<int>(
                valueListenable: _propiedadController,
                builder: (_, propiedadId, _) {
                  return DropdownButtonFormField<int>(
                    initialValue: _propiedades.any((item) => (item['id'] as int?) == propiedadId)
                        ? propiedadId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Propiedad',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final propiedad in _propiedades)
                        DropdownMenuItem<int>(
                          value: (propiedad['id'] as int?) ?? 0,
                          child: Text((propiedad['nombre'] ?? 'Propiedad') as String),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _propiedadController.value = value;
                        _aplicarPrecioMensual(value);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: _inquilinoController,
                builder: (_, inquilinoId, _) {
                  return DropdownButtonFormField<int>(
                    initialValue: _inquilinos.any((item) => (item['id'] as int?) == inquilinoId)
                        ? inquilinoId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Inquilino',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final inquilino in _inquilinos)
                        DropdownMenuItem<int>(
                          value: (inquilino['id'] as int?) ?? 0,
                          child: Text((inquilino['nombre_apellido'] ?? 'Inquilino') as String),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _inquilinoController.value = value;
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _fechaInicioController,
                label: 'Fecha de inicio',
                prefixIcon: Icons.calendar_today_rounded,
                readOnly: true,
                onTap: () => _pickDate(isInicio: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _fechaFinController,
                label: 'Fecha de finalización (opcional)',
                prefixIcon: Icons.event_available_rounded,
                readOnly: true,
                onTap: () => _pickDate(isInicio: false),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _montoPagoController,
                label: 'Monto a pagar por el inquilino',
                prefixIcon: Icons.attach_money_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _cantidadDepositosController,
                label: 'Cantidad de depósitos',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _diaPagoController,
                label: 'Día de pago',
                prefixIcon: Icons.calendar_today_rounded,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: _estadoController,
                builder: (_, estado, _) {
                  return DropdownButtonFormField<String>(
                    initialValue: ['Activo', 'Finalizado', 'Pendiente', 'Cancelado'].contains(estado)
                        ? estado
                        : 'Activo',
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'Finalizado', child: Text('Finalizado')),
                      DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                      DropdownMenuItem(value: 'Cancelado', child: Text('Cancelado')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _estadoController.value = value;
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              AppButton(
                text: widget.alquiler == null ? 'Guardar alquiler' : 'Actualizar alquiler',
                onPressed: _save,
              ),
            ],
          ],
        ),
      ),
    );
  }
}