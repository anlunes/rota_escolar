import 'package:dio/dio.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/core/services/api_service.dart';
import '../domain/models/estado.dart';
import '../domain/models/municipio.dart';
import '../domain/models/bairro.dart';
import '../domain/models/escola.dart';

class LocationRepository {
  final Dio _dio = ApiService().dio;
  final Dio _ibgeDio = Dio(BaseOptions(
    baseUrl: 'https://servicodados.ibge.gov.br/api/v1/localidades',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<List<Estado>> fetchEstados() async {
    final response = await _ibgeDio.get('/estados?orderBy=nome');
    final data = response.data as List;
    return data.map((e) => Estado(
      id: e['id'] as int,
      uf: e['sigla'] as String,
      nome: e['nome'] as String,
    )).toList();
  }

  Future<List<Municipio>> fetchMunicipios(int estadoId) async {
    final response = await _ibgeDio.get('/estados/$estadoId/municipios?orderBy=nome');
    final data = response.data as List;
    return data.map((e) => Municipio(
      id: e['id'] as int,
      nome: e['nome'] as String,
      ibge: e['id'] as int,
    )).toList();
  }

  Future<List<Bairro>> fetchBairros(int municipioId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}${ApiConstants.locationBairros}',
      queryParameters: {'municipio_id': municipioId},
    );
    final data = response.data['data'] as List;
    return data.map((e) => Bairro.fromJson(e)).toList();
  }

  Future<List<Escola>> fetchEscolas(int bairroId) async {
    final response = await _dio.get(
      '${ApiConstants.baseUrl}${ApiConstants.locationEscolas}',
      queryParameters: {'bairro_id': bairroId},
    );
    final data = response.data['data'] as List;
    return data.map((e) => Escola.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> createEscola({
    required String nome,
    required int bairroId,
    required String bairroNome,
    required String token,
    String? cep,
    String? endereco,
    String? cidade,
    String? estado,
    String? administracao,
    String? nivelEscolar,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.locationEscolasCreate}',
      data: {
        'nome': nome,
        'bairro_id': bairroId,
        'bairro_nome': bairroNome,
        if (cep != null) 'cep': cep,
        if (endereco != null) 'endereco': endereco,
        if (cidade != null) 'cidade': cidade,
        if (estado != null) 'estado': estado,
        if (administracao != null) 'administracao': administracao,
        if (nivelEscolar != null) 'nivel_escolar': nivelEscolar,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Submete novo bairro para aprovação do admin.
  /// Retorna o status: 'ativo' (já existia) ou 'pendente' (aguarda aprovação).
  Future<Map<String, dynamic>> createBairro({
    required String nome,
    required int municipioId,
    required String municipioNome,
    required String token,
  }) async {
    final response = await _dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.locationBairrosCreate}',
      data: {'nome': nome, 'municipio_id': municipioId, 'municipio_nome': municipioNome},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
