import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../models/inquilino_model.dart';

class InquilinosRemoteDataSource {
  const InquilinosRemoteDataSource(this._apiClient);
  final ApiClient _apiClient;

  Future<List<InquilinoModel>> obtenerInquilinos() async {
    final body = (await _apiClient.get<dynamic>(ApiEndpoints.inquilinos)).data;
    if (body is! Map<String, dynamic> ||
        body['success'] != true ||
        body['data'] is! List) {
      throw const UnknownException(
        message: 'Respuesta inválida al consultar inquilinos.',
        userMessage: 'No pudimos obtener los inquilinos.',
      );
    }
    return (body['data'] as List)
        .whereType<Map<String, dynamic>>()
        .map(InquilinoModel.fromJson)
        .toList(growable: false);
  }
}
