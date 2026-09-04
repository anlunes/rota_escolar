import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/services/api_service.dart';

class OnboardingProfile {
  final String telefone;
  final int? bairroId;
  final String bairroNome;
  final int? municipioId;
  final bool hasPhone;
  final bool hasBairro;
  final bool hasFilho;
  final bool onboardingComplete;

  const OnboardingProfile({
    required this.telefone,
    required this.bairroId,
    required this.bairroNome,
    required this.municipioId,
    required this.hasPhone,
    required this.hasBairro,
    required this.hasFilho,
    required this.onboardingComplete,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> j) {
    return OnboardingProfile(
      telefone:           j['telefone']?.toString() ?? '',
      bairroId:           j['bairro_id'] as int?,
      bairroNome:         j['bairro_nome']?.toString() ?? '',
      municipioId:        j['municipio_id'] as int?,
      hasPhone:           j['has_phone'] == true,
      hasBairro:          j['has_bairro'] == true,
      hasFilho:           j['has_filho'] == true,
      onboardingComplete: j['onboarding_complete'] == true,
    );
  }
}

class OnboardingRepository {
  final ApiService _api = ApiService();

  Future<OnboardingProfile> getProfile() async {
    final response = await _api.get(ApiConstants.guardianProfile);
    final data = response.data['data'] as Map<String, dynamic>;
    return OnboardingProfile.fromJson(data);
  }

  Future<void> saveProfile({
    required String telefone,
    required int bairroId,
  }) async {
    await _api.post(
      ApiConstants.guardianProfile,
      data: {
        'telefone': telefone,
        'bairro_id': bairroId,
      },
    );
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});
