import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core/services/api_service.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/constants/status_constants.dart';

import '../domain/models/student_summary.dart';
import '../domain/models/route_report_entry.dart';

/// Repositório de alunos do responsável.
class StudentsRepository {
  final ApiService _api;

  StudentsRepository(this._api);

  /// Lista alunos do responsável logado.
  Future<List<StudentSummary>> fetchStudents() async {
    try {
      final response = await _api.get(ApiConstants.studentsIndex);

      final data = response.data;

      debugPrint('[StudentsRepository] RESPONSE: $data');

      if (data is Map && data['success'] == true) {
        final list = data['data'] as List<dynamic>;

        return list
            .map((item) => _fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e, stack) {
      debugPrint('[StudentsRepository] fetchStudents error: $e');
      debugPrint(stack.toString());

      return [];
    }
  }

  /// Cria/atualiza aluno.
  Future<StudentSummary?> saveStudent({
    required String name,
    required String school,
    int? escolaId,
    required String residenceCep,
    String? logradouro,
    String? numero,
    String? complemento,
    String? bairro,
    String? cicloEscolar,
    String? turno,
    String? dataNascimento,
    String? vanCode,
    String? existingId,
  }) async {
    try {
      final path = existingId != null
          ? ApiConstants.studentsUpdate
          : ApiConstants.studentsIndex;

      final method = existingId != null ? 'put' : 'post';

      final payload = <String, dynamic>{
        'name': name,
        'school': school,
        'residence_cep': residenceCep,
      };

      if (escolaId != null)      payload['escola_id']          = escolaId;
      if (logradouro != null)    payload['logradouro']          = logradouro;
      if (numero != null)        payload['numero_residencia']   = numero;
      if (complemento != null)   payload['complemento']         = complemento;
      if (bairro != null)        payload['bairro_residencia']   = bairro;
      if (cicloEscolar != null)  payload['ciclo_escolar']       = cicloEscolar;
      if (turno != null)         payload['turno']               = turno;
      if (dataNascimento != null) payload['data_nascimento']    = dataNascimento;
      if (existingId != null)    payload['id']                  = existingId;
      if (vanCode != null)       payload['van_code']            = vanCode;

      final response = method == 'put'
          ? await _api.put(path, data: payload)
          : await _api.post(path, data: payload);

      final data = response.data;

      debugPrint('[StudentsRepository] SAVE RESPONSE: $data');

      if (data is Map && data['success'] == true) {
        return _fromJson(data['data'] as Map<String, dynamic>);
      }

      final msg = data is Map ? (data['message'] ?? 'Erro desconhecido') : 'Resposta inválida';
      debugPrint('[StudentsRepository] saveStudent falhou: $msg');
      throw Exception(msg);
    } catch (e, stack) {
      debugPrint('[StudentsRepository] saveStudent error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  StudentSummary _fromJson(Map<String, dynamic> json) {
    debugPrint('[StudentsRepository] PARSING STUDENT: $json');

    return StudentSummary(
      id: json['id']?.toString() ?? '',

      name: json['name']?.toString() ?? '',

      school: json['school']?.toString() ?? '',

      residenceCep:
          json['residence_cep']?.toString() ?? '',

      cicloEscolar:
          json['ciclo_escolar']?.toString() ?? 'A definir',

      status: StudentStatus.fromValue(
        json['status_atual']?.toString(),
      ),

      goToday:
          int.tryParse(json['vai_hoje'].toString()) == 1,

      talkRequested:
          int.tryParse(json['talk_requested'].toString()) == 1,

      talkAcknowledgedByDriver:
          int.tryParse(
                json['talk_acknowledged'].toString(),
              ) ==
              1,

      driverName:
          json['driver_name']?.toString() ??
              'Sem motorista',

      driverWhatsapp:
          json['driver_whatsapp']?.toString() ?? '',

      ativo:
          int.tryParse(
                json['ativo'].toString(),
              ) ==
              1,

      vanCode:       json['van_code']?.toString()        ?? '',
      logradouro:    json['logradouro']?.toString()       ?? '',
      numero:        json['numero_residencia']?.toString() ?? '',
      complemento:   json['complemento']?.toString()      ?? '',
      bairro:        json['bairro_residencia']?.toString() ?? '',
      turno:         json['turno']?.toString()             ?? '',
      dataNascimento: json['data_nascimento']?.toString()  ?? '',
      photoUrl:      (json['foto_url']?.toString() ?? '').isNotEmpty
                         ? json['foto_url'].toString()
                         : null,
    );
  }

  /// Persiste talk_requested no banco.
  Future<void> toggleTalkRequest(String id, bool requested) async {
    await _api.post(
      ApiConstants.studentsTalkRequest,
      data: {
        'id':     int.tryParse(id) ?? 0,
        'action': requested ? 'request' : 'cancel',
      },
    );
  }

  /// Persiste vai_hoje no banco (atualiza último rota_dia_alunos).
  Future<void> toggleGoToday(String id, bool goToday) async {
    await _api.post(
      ApiConstants.studentsGoToday,
      data: {'id': int.tryParse(id) ?? 0, 'vai_hoje': goToday ? 1 : 0},
    );
  }

  /// Reativa aluno desativado.
  Future<void> reactivateStudent(String id) async {
    final response = await _api.post(
      ApiConstants.studentsIndex,
      data: {'action': 'reactivate', 'id': int.tryParse(id) ?? 0},
    );
    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final msg = data is Map ? (data['message'] ?? 'Erro ao reativar') : 'Erro ao reativar';
      throw Exception(msg);
    }
  }

  /// Busca histórico de rotas dos últimos [days] dias para os alunos do responsável.
  Future<List<RouteReportEntry>> fetchReport({int days = 14}) async {
    try {
      final response = await _api.get(
        ApiConstants.routesReport,
        queryParameters: {'days': days},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = data['data'] as List<dynamic>;
        return list
            .map((e) => RouteReportEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[StudentsRepository] fetchReport error: $e');
      return [];
    }
  }

  /// Remove o aluno (soft delete: ativo = 0).
  Future<void> deleteStudent(String id) async {
    final response = await _api.delete(
      ApiConstants.studentsIndex,
      data: {'id': int.tryParse(id) ?? 0},
    );
    final data = response.data;
    if (data is! Map || data['success'] != true) {
      final msg = data is Map ? (data['message'] ?? 'Erro ao excluir') : 'Erro ao excluir';
      throw Exception(msg);
    }
  }
}

final studentsRepositoryProvider =
    Provider<StudentsRepository>((ref) {
  return StudentsRepository(
    ref.read(apiServiceProvider),
  );
});