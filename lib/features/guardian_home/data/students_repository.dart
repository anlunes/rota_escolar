import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core/services/api_service.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/constants/status_constants.dart';

import '../domain/models/student_summary.dart';

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
    required String residenceCep,
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

      if (existingId != null) {
        payload['id'] = existingId;
      }

      if (vanCode != null) {
        payload['van_code'] = vanCode;
      }

      final response = method == 'put'
          ? await _api.put(path, data: payload)
          : await _api.post(path, data: payload);

      final data = response.data;

      debugPrint('[StudentsRepository] SAVE RESPONSE: $data');

      if (data is Map && data['success'] == true) {
        return _fromJson(data['data'] as Map<String, dynamic>);
      }

      return null;
    } catch (e, stack) {
      debugPrint('[StudentsRepository] saveStudent error: $e');
      debugPrint(stack.toString());

      return null;
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
    );
  }
}

final studentsRepositoryProvider =
    Provider<StudentsRepository>((ref) {
  return StudentsRepository(
    ref.read(apiServiceProvider),
  );
});