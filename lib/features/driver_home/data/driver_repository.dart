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

  /// Lista pagamentos do motorista.
  Future<List<PaymentRecord>> fetchPayments() async {
    try {
      final response = await _api.get(ApiConstants.financialIndex);

      final data = response.data;

      debugPrint('[DriverRepository] PAYMENTS RESPONSE: $data');

      if (data is Map && data['success'] == true) {
        final list = data['data'] as List<dynamic>;

        return list
            .map((item) => _paymentFromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Resposta inválida da API');
    } catch (e, stack) {
      debugPrint('[DriverRepository] fetchPayments ERROR: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  /// Marca mensalidade como paga em dinheiro.
  Future<bool> markPayment(String financialId) async {
    try {
      final response = await _api.post(
        ApiConstants.financialPay,
        data: {
          'financial_id': financialId,
          'method': 'cash',
        },
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
    );
  }

  PaymentRecord _paymentFromJson(Map<String, dynamic> json) {
    debugPrint('[DriverRepository] PARSING PAYMENT: $json');

    return PaymentRecord(
      studentName:
          json['student_name']?.toString() ?? '',

      month:
          json['month']?.toString() ?? '',

      amount:
          double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,

      paid:
          int.tryParse(json['paid'].toString()) == 1,

      paidInCash:
          int.tryParse(json['paid_in_cash'].toString()) == 1,
    );
  }
}

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(
    ref.read(apiServiceProvider),
  );
});