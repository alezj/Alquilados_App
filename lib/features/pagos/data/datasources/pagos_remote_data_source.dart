import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/pago_model.dart';

class PagosRemoteDataSource {
  const PagosRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;
  Future<List<PagoModel>> obtenerPagos() async {
    final body = (await _apiClient.get<dynamic>(ApiEndpoints.pagos)).data;
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! List) {
      throw const UnknownException(
        message: 'Respuesta inválida al consultar pagos.',
        userMessage: 'No pudimos obtener los pagos.',
      );
    }
    return (body['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(PagoModel.fromJson)
        .toList(growable: false);
  }
}
