import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/propiedad_model.dart';

class PropiedadesRemoteDataSource {
  const PropiedadesRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PropiedadModel>> obtenerPropiedades() async {
    final response = await _apiClient.get<dynamic>(ApiEndpoints.propiedades);
    final body = response.data;

    if (body is! Map<String, dynamic> || body['success'] != true) {
      throw const UnknownException(
        message: 'Respuesta inválida al consultar propiedades.',
        userMessage: 'No pudimos obtener las propiedades.',
      );
    }

    final data = body['data'];
    if (data is! List) {
      throw const UnknownException(
        message: 'El campo data de propiedades no es una lista.',
        userMessage: 'La respuesta de propiedades tiene un formato no válido.',
      );
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(PropiedadModel.fromJson)
        .toList(growable: false);
  }
}
