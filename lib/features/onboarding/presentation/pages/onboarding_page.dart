import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/app_router.dart';
import '../../../../features/location/data/location_repository.dart';
import '../../../../features/location/domain/models/estado.dart';
import '../../../../features/location/domain/models/municipio.dart';
import '../../../../features/location/domain/models/bairro.dart';
import '../../data/onboarding_repository.dart';

// ---------------------------------------------------------------------------
// Providers locais de localização para o onboarding
// ---------------------------------------------------------------------------

final _estadosProvider = FutureProvider<List<Estado>>((ref) {
  return LocationRepository().fetchEstados();
});

final _selectedEstadoProvider = StateProvider<Estado?>((ref) => null);
final _selectedMunicipioProvider = StateProvider<Municipio?>((ref) => null);
final _selectedBairroProvider = StateProvider<Bairro?>((ref) => null);

final _municipiosProvider = FutureProvider<List<Municipio>>((ref) {
  final estado = ref.watch(_selectedEstadoProvider);
  if (estado == null) return Future.value([]);
  return LocationRepository().fetchMunicipios(estado.id);
});

final _bairrosProvider = FutureProvider<List<Bairro>>((ref) {
  final municipio = ref.watch(_selectedMunicipioProvider);
  if (municipio == null) return Future.value([]);
  return LocationRepository().fetchBairros(municipio.id);
});

// ---------------------------------------------------------------------------
// OnboardingPage
// ---------------------------------------------------------------------------

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _telefoneCtrl = TextEditingController();
  bool _saving = false;
  String? _errorMsg;

  @override
  void dispose() {
    _telefoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final bairro = ref.read(_selectedBairroProvider);
    if (bairro == null) {
      setState(() => _errorMsg = 'Selecione seu bairro.');
      return;
    }

    setState(() { _saving = true; _errorMsg = null; });

    try {
      await ref.read(onboardingRepositoryProvider).saveProfile(
        telefone: _telefoneCtrl.text.trim(),
        bairroId: bairro.id,
      );
      if (mounted) context.go(AppRoutes.guardianHome);
    } catch (e) {
      setState(() => _errorMsg = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        title: const Text(
          'Rota Escolar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _Header(),
                const SizedBox(height: 32),
                _PhoneField(controller: _telefoneCtrl),
                const SizedBox(height: 20),
                _LocationSection(),
                if (_errorMsg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(color: AppColors.error, fontSize: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.text,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.directions_bus_rounded, size: 40, color: AppColors.text),
        ),
        const SizedBox(height: 20),
        const Text(
          'Complete seu perfil',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Precisamos de algumas informações para conectar você aos motoristas da sua região.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Campo de telefone
// ---------------------------------------------------------------------------

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WhatsApp / Telefone',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          decoration: InputDecoration(
            hintText: 'Ex: 21999999999',
            counterText: '',
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.length < 10) return 'Informe um número válido (DDD + número).';
            return null;
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de localização: Estado → Município → Bairro
// ---------------------------------------------------------------------------

class _LocationSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estadosAsync  = ref.watch(_estadosProvider);
    final municipiosAsync = ref.watch(_municipiosProvider);
    final bairrosAsync  = ref.watch(_bairrosProvider);

    final selectedEstado   = ref.watch(_selectedEstadoProvider);
    final selectedMunicipio = ref.watch(_selectedMunicipioProvider);
    final selectedBairro   = ref.watch(_selectedBairroProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Estado
        const Text(
          'Estado',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        estadosAsync.when(
          loading: () => loadingDropdown('Carregando estados...'),
          error: (err, _) => errorDropdown('Erro ao carregar estados'),
          data: (estados) => buildDropdown<Estado>(
            hint: 'Selecione o estado',
            value: selectedEstado,
            items: estados,
            label: (e) => '${e.uf} — ${e.nome}',
            onChanged: (e) {
              ref.read(_selectedEstadoProvider.notifier).state = e;
              ref.read(_selectedMunicipioProvider.notifier).state = null;
              ref.read(_selectedBairroProvider.notifier).state = null;
            },
          ),
        ),

        const SizedBox(height: 16),

        // Município
        const Text(
          'Município',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        if (selectedEstado == null)
          disabledDropdown('Selecione o estado primeiro')
        else
          municipiosAsync.when(
            loading: () => loadingDropdown('Carregando municípios...'),
            error: (err, _) => errorDropdown('Erro ao carregar municípios'),
            data: (municipios) => buildDropdown<Municipio>(
              hint: 'Selecione o município',
              value: selectedMunicipio,
              items: municipios,
              label: (m) => m.nome,
              onChanged: (m) {
                ref.read(_selectedMunicipioProvider.notifier).state = m;
                ref.read(_selectedBairroProvider.notifier).state = null;
              },
            ),
          ),

        const SizedBox(height: 16),

        // Bairro
        const Text(
          'Bairro',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 6),
        if (selectedMunicipio == null)
          disabledDropdown('Selecione o município primeiro')
        else
          bairrosAsync.when(
            loading: () => loadingDropdown('Carregando bairros...'),
            error: (err, _) => errorDropdown('Erro ao carregar bairros'),
            data: (bairros) {
              if (bairros.isEmpty) {
                return disabledDropdown('Nenhum bairro cadastrado neste município');
              }
              return buildDropdown<Bairro>(
                hint: 'Selecione seu bairro',
                value: selectedBairro,
                items: bairros,
                label: (b) => b.nome,
                onChanged: (b) {
                  ref.read(_selectedBairroProvider.notifier).state = b;
                },
              );
            },
          ),
      ],
    );
  }

  Widget buildDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          value: value,
          items: items.map((item) => DropdownMenuItem<T>(
            value: item,
            child: Text(label(item), style: const TextStyle(fontSize: 14)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget loadingDropdown(String label) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget disabledDropdown(String label) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textDisabled)),
    );
  }

  Widget errorDropdown(String label) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.error)),
    );
  }
}
