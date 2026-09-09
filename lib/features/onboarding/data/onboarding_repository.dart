import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/core/constants/api_constants.dart';
import '../../../app/core/services/api_service.dart';

class OnboardingProfile {
  final String cpf;
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairroNome;
  final String cidade;
  final String estadoUf;
  final bool hasCpf;
  final bool hasCep;
  final bool hasFilho;
  final bool onboardingComplete;

  const OnboardingProfile({
    required this.cpf,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.complemento,
    required this.bairroNome,
    required this.cidade,
    required this.estadoUf,
    required this.hasCpf,
    required this.hasCep,
    required this.hasFilho,
    required this.onboardingComplete,
  });

  factory OnboardingProfile.fromJson(Map<String, dynamic> j) {
    return OnboardingProfile(
      cpf:               j['cpf']?.toString()        ?? '',
      cep:               j['cep']?.toString()        ?? '',
      logradouro:        j['logradouro']?.toString() ?? '',
      numero:            j['numero']?.toString()     ?? '',
      complemento:       j['complemento']?.toString() ?? '',
      bairroNome:        j['bairro_nome']?.toString() ?? '',
      cidade:            j['cidade']?.toString()     ?? '',
      estadoUf:          j['estado_uf']?.toString()  ?? '',
      hasCpf:            j['has_cpf']  == true,
      hasCep:            j['has_cep']  == true,
      hasFilho:          j['has_filho'] == true,
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
    required String cpf,
    required String cep,
    required String logradouro,
    required String numero,
    String? complemento,
    required String bairroNome,
    required String cidade,
    required String estadoUf,
  }) async {
    await _api.post(
      ApiConstants.guardianProfile,
      data: {
        'cpf':         cpf,
        'cep':         cep,
        'logradouro':  logradouro,
        'numero':      numero,
        'complemento': complemento ?? '',
        'bairro_nome': bairroNome,
        'cidade':      cidade,
        'estado_uf':   estadoUf,
      },
    );
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository();
});
