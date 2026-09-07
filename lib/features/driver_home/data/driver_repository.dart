import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core/services/api_service.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/constants/status_constants.dart';

import '../domain/models/student_in_route.dart';
import '../application/driver_home_provider.dart';

/// Repositório de rotas/alunos do motorista.
class DriverRepository {
  final ApiService _api;

  DriverRepository(this._api);

  /// Lista alunos da rota do dia para o motorista logado.
  Future<List<StudentInRoute>> fetchRouteStudents() async {
    try {
      final response = await _api.get(ApiConstants.routesIndex);

      final data = response.data;

      debugPrint('[DriverRepository] RESPONSE: $data');

      if (data is Map && data['success'] == true) {
        final list = data['data'] as List<dynamic>;

        return list
            .map((item) => _studentFromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Resposta inválida da API');
    } catch (e, stack) {
      debugPrint('[DriverRepository] fetchRouteStudents ERROR: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Reordena alunos na rota.
  Future<bool> reorderStudents(
    List<String> orderedIds,
    RoutePeriod period,
  ) async {
    try {
      final response = await _api.put(
        ApiConstants.routesReorder,
        data: {
          'period': period.value,
          'ordered_ids': orderedIds,
        },
      );

      final data = response.data;

      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[DriverRepository] reorderStudents error: $e');
      return false;
    }
  }

  /// Lista pagamentos do motorista para um mês/ano específico.
  Future<Map<String, dynamic>> fetchPaymentsByMonth(int mes, int ano) async {
    try {
      final response = await _api.get(
        ApiConstants.financialIndex,
        queryParameters: {'mes': mes, 'ano': ano},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final raw     = data['data'] as Map<String, dynamic>;
        final list    = raw['mensalidades'] as List<dynamic>;
        return {
          'pendentes_geracao': raw['pendentes_geracao'] ?? 0,
          'valor_servico':     raw['valor_servico'] ?? 0.0,
          'mensalidades': list
              .map((item) => _paymentFromJson(item as Map<String, dynamic>))
              .toList(),
        };
      }
      return {'pendentes_geracao': 0, 'valor_servico': 0.0, 'mensalidades': <PaymentRecord>[]};
    } catch (e) {
      debugPrint('[DriverRepository] fetchPaymentsByMonth error: $e');
      return {'pendentes_geracao': 0, 'valor_servico': 0.0, 'mensalidades': <PaymentRecord>[]};
    }
  }

  /// Alias usado no carregamento inicial (mês atual).
  Future<List<PaymentRecord>> fetchPayments() async {
    final now = DateTime.now();
    final result = await fetchPaymentsByMonth(now.month, now.year);
    return result['mensalidades'] as List<PaymentRecord>;
  }

  /// Gera cobranças Asaas para o mês/ano informado.
  Future<List<Map<String, dynamic>>> generateCharges(int mes, int ano) async {
    try {
      final response = await _api.post(
        ApiConstants.financialGenerate,
        data: {'mes': mes, 'ano': ano},
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      final msg = data is Map ? (data['message'] ?? 'Erro ao gerar cobranças') : 'Erro';
      throw Exception(msg);
    } catch (e) {
      debugPrint('[DriverRepository] generateCharges error: $e');
      rethrow;
    }
  }

  /// Lista candidaturas pendentes (alunos com van_code do motorista, sem motorista_id).
  Future<List<CandidateOpportunity>> fetchOpportunities() async {
    try {
      final response = await _api.get(ApiConstants.driverOpportunities);
      final data = response.data;
      if (data is Map && data['success'] == true) {
        final list = data['data'] as List<dynamic>;
        return list
            .map((item) => _opportunityFromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[DriverRepository] fetchOpportunities error: $e');
      return [];
    }
  }

  /// Aceita ou recusa uma candidatura.
  Future<bool> respondOpportunity(int alunoId, String action) async {
    try {
      final response = await _api.post(
        ApiConstants.driverOpportunities,
        data: {'action': action, 'aluno_id': alunoId},
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[DriverRepository] respondOpportunity error: $e');
      return false;
    }
  }

  /// Persiste o novo status do aluno no MySQL (fire-and-forget).
  Future<bool> updateStudentStatus(String studentId, StudentStatus status) async {
    try {
      final response = await _api.post(
        ApiConstants.routesUpdateStatus,
        data: {
          'aluno_id': int.tryParse(studentId) ?? 0,
          'status': status.value,
        },
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[DriverRepository] updateStudentStatus error: $e');
      return false;
    }
  }

  /// Motorista confirma leitura da solicitação de conversa.
  Future<bool> ackTalkRequest(String studentId) async {
    try {
      final response = await _api.post(
        ApiConstants.studentsTalkRequest,
        data: {
          'id':     int.tryParse(studentId) ?? 0,
          'action': 'ack',
        },
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[DriverRepository] ackTalkRequest error: $e');
      return false;
    }
  }

  /// Marca mensalidade como paga em dinheiro.
  Future<bool> markPayment(int mensalidadeId) async {
    try {
      final response = await _api.post(
        ApiConstants.financialPay,
        data: {'mensalidade_id': mensalidadeId},
      );
      final data = response.data;
      return data is Map && data['success'] == true;
    } catch (e) {
      debugPrint('[DriverRepository] markPayment error: $e');
      return false;
    }
  }

  StudentInRoute _studentFromJson(Map<String, dynamic> json) {
    debugPrint('[DriverRepository] PARSING STUDENT: $json');

    // Mapeia turno do aluno para os períodos de rota que ele participa
    final turno = json['turno']?.toString().toLowerCase() ?? '';
    List<RoutePeriod>? activeRoutes;
    if (turno == 'manhã' || turno == 'manha' || turno == 'morning') {
      activeRoutes = [RoutePeriod.morningOutbound, RoutePeriod.morningReturn];
    } else if (turno == 'tarde' || turno == 'afternoon') {
      activeRoutes = [RoutePeriod.afternoonOutbound, RoutePeriod.afternoonReturn];
    }
    // integral ou vazio = null (aparece em todos os períodos)

    return StudentInRoute(
      id: json['id']?.toString() ?? '',

      name: json['name']?.toString() ?? '',

      address: json['address']?.toString() ?? '',

      school: json['school']?.toString() ?? '',

      status: StudentStatus.fromValue(
        json['status_atual']?.toString(),
      ),

      goToday:
          int.tryParse(json['vai_hoje'].toString()) == 1,

      talkRequested:
          int.tryParse(json['talk_requested'].toString()) == 1,

      guardianWhatsapp:
          json['guardian_whatsapp']?.toString() ?? '',

      guardianName:
          json['guardian_name']?.toString() ?? '',

      paymentPaid:
          int.tryParse(json['payment_paid'].toString()) == 1,

      activeRoutes: activeRoutes,

      photoUrl: (json['foto_url']?.toString() ?? '').isNotEmpty
          ? json['foto_url'].toString()
          : null,
    );
  }

  CandidateOpportunity _opportunityFromJson(Map<String, dynamic> json) {
    return CandidateOpportunity(
      id: json['aluno_id']?.toString() ?? '',
      alunoId: (json['aluno_id'] as num?)?.toInt() ?? 0,
      studentName: json['student_name']?.toString() ?? '',
      guardianName: json['guardian_name']?.toString() ?? '',
      guardianWhatsapp: json['guardian_whatsapp']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      school: json['school']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
    );
  }

  PaymentRecord _paymentFromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id:                   (json['id'] as num?)?.toInt() ?? 0,
      studentName:          json['aluno_nome']?.toString()           ?? '',
      responsavelNome:      json['responsavel_nome']?.toString()     ?? '',
      responsavelWhatsapp:  json['responsavel_whatsapp']?.toString() ?? '',
      mes:                  (json['mes'] as num?)?.toInt()           ?? 0,
      ano:                  (json['ano'] as num?)?.toInt()           ?? 0,
      amount:               double.tryParse(json['valor']?.toString() ?? '0') ?? 0.0,
      status:               json['status']?.toString()        ?? 'pendente',
      formaPagamento:       json['forma_pagamento']?.toString(),
      asaasLink:            json['asaas_link']?.toString(),
      dataVencimento:       json['data_vencimento']?.toString(),
      dataPagamento:        json['data_pagamento']?.toString(),
    );
  }
}

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(
    ref.read(apiServiceProvider),
  );
});