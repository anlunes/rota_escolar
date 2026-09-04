import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/services/api_service.dart';

class EvaluationStatus {
  final bool needsEvaluation;
  final int? motoristaId;
  final String mes;

  const EvaluationStatus({
    required this.needsEvaluation,
    required this.motoristaId,
    required this.mes,
  });

  factory EvaluationStatus.fromJson(Map<String, dynamic> j) {
    return EvaluationStatus(
      needsEvaluation: j['needs_evaluation'] == true,
      motoristaId: j['motorista_id'] != null ? (j['motorista_id'] as num).toInt() : null,
      mes: j['mes']?.toString() ?? '',
    );
  }
}

class EvaluationRepository {
  final ApiService _api = ApiService();

  Future<EvaluationStatus> checkStatus() async {
    final response = await _api.get(ApiConstants.evaluationsStatus);
    final data = response.data['data'] as Map<String, dynamic>;
    return EvaluationStatus.fromJson(data);
  }

  Future<void> submit({
    required int motoristaId,
    required double nota,
    required String mes,
    String comentario = '',
  }) async {
    await _api.post(
      ApiConstants.evaluationsCreate,
      data: {
        'motorista_id': motoristaId,
        'nota': nota,
        'comentario': comentario,
        'mes': mes,
      },
    );
  }
}

final evaluationRepositoryProvider = Provider<EvaluationRepository>(
  (ref) => EvaluationRepository(),
);
