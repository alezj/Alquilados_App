import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';

Future<bool> showPaymentResult(
  BuildContext context,
  Future<String?> Function() save,
) async {
  try {
    final message = await save();
    if (message == null) return false;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      final message = error is AppException
          ? error.userMessage
          : 'No pudimos confirmar el pago. Revisa la conexión e intenta nuevamente.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }
}
