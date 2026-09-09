import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/app_router.dart';
import '../../data/onboarding_repository.dart';
import '../../../../app/core/utils/cpf_validator.dart';

// ---------------------------------------------------------------------------
// CPF formatter: 000.000.000-00
// ---------------------------------------------------------------------------

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

// ---------------------------------------------------------------------------
// CEP formatter: 00000-000
// ---------------------------------------------------------------------------

class _CepFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buf.write('-');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

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

  final _cpfCtrl        = TextEditingController();
  final _cepCtrl        = TextEditingController();
  final _logradouroCtrl = TextEditingController();
  final _bairroCtrl     = TextEditingController();
  final _cidadeCtrl     = TextEditingController();
  final _estadoCtrl     = TextEditingController();
  final _numeroCtrl     = TextEditingController();
  final _complementoCtrl = TextEditingController();

  bool _isLoadingCep = false;
  String? _cepError;
  bool _saving = false;
  String? _errorMsg;

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _cepCtrl.dispose();
    _logradouroCtrl.dispose();
    _bairroCtrl.dispose();
    _cidadeCtrl.dispose();
    _estadoCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCep(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;

    setState(() { _isLoadingCep = true; _cepError = null; });

    try {
      final response = await Dio().get('https://viacep.com.br/ws/$digits/json/');
      final data = response.data as Map<String, dynamic>;

      if (data['erro'] == true) {
        setState(() => _cepError = 'CEP não encontrado.');
        return;
      }

      setState(() {
        _logradouroCtrl.text = data['logradouro'] ?? '';
        _bairroCtrl.text     = data['bairro']     ?? '';
        _cidadeCtrl.text     = data['localidade'] ?? '';
        _estadoCtrl.text     = data['uf']         ?? '';
      });
    } catch (_) {
      setState(() => _cepError = 'Não foi possível consultar o CEP.');
    } finally {
      if (mounted) setState(() => _isLoadingCep = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_cepError != null) return;

    setState(() { _saving = true; _errorMsg = null; });

    try {
      await ref.read(onboardingRepositoryProvider).saveProfile(
        cpf:        _cpfCtrl.text.trim(),
        cep:        _cepCtrl.text.trim(),
        logradouro: _logradouroCtrl.text.trim(),
        numero:     _numeroCtrl.text.trim(),
        complemento: _complementoCtrl.text.trim().isEmpty ? null : _complementoCtrl.text.trim(),
        bairroNome: _bairroCtrl.text.trim(),
        cidade:     _cidadeCtrl.text.trim(),
        estadoUf:   _estadoCtrl.text.trim(),
      );
      if (mounted) context.go(AppRoutes.guardianHome);
    } catch (_) {
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
                _buildHeader(),
                const SizedBox(height: 28),

                // CPF
                _buildLabel('CPF'),
                const SizedBox(height: 6),
                _buildTextInput(
                  controller: _cpfCtrl,
                  hint: '000.000.000-00',
                  keyboardType: TextInputType.number,
                  formatters: [_CpfFormatter()],
                  validator: validateCpf,
                ),

                const SizedBox(height: 20),

                // CEP
                _buildLabel('CEP'),
                const SizedBox(height: 6),
                _buildCepField(),
                if (_cepError != null) ...[
                  const SizedBox(height: 4),
                  Text(_cepError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ],

                const SizedBox(height: 20),

                // Logradouro (readonly)
                _buildLabel('Logradouro'),
                const SizedBox(height: 6),
                _buildReadonlyInput(controller: _logradouroCtrl, hint: 'Preenchido pelo CEP'),

                const SizedBox(height: 16),

                // Bairro (readonly) + Estado (readonly) em linha
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Bairro'),
                          const SizedBox(height: 6),
                          _buildReadonlyInput(controller: _bairroCtrl, hint: 'Bairro'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('UF'),
                          const SizedBox(height: 6),
                          _buildReadonlyInput(controller: _estadoCtrl, hint: 'UF'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Cidade (readonly)
                _buildLabel('Cidade'),
                const SizedBox(height: 6),
                _buildReadonlyInput(controller: _cidadeCtrl, hint: 'Cidade'),

                const SizedBox(height: 20),

                // Número + Complemento em linha
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Número'),
                          const SizedBox(height: 6),
                          _buildTextInput(
                            controller: _numeroCtrl,
                            hint: 'Ex: 123',
                            keyboardType: TextInputType.text,
                            validator: (v) =>
                                (v ?? '').trim().isEmpty ? 'Obrigatório.' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Complemento'),
                          const SizedBox(height: 6),
                          _buildTextInput(
                            controller: _complementoCtrl,
                            hint: 'Apto, Bloco... (opcional)',
                            keyboardType: TextInputType.text,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ---------------------------------------------------------------------------
  // Widgets auxiliares
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text),
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

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
    );
  }

  Widget _buildCepField() {
    return TextFormField(
      controller: _cepCtrl,
      keyboardType: TextInputType.number,
      inputFormatters: [_CepFormatter()],
      decoration: InputDecoration(
        hintText: '00000-000',
        filled: true,
        fillColor: Colors.white,
        suffixIcon: _isLoadingCep
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.search, size: 20),
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
      onChanged: (v) {
        final digits = v.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 8) _lookupCep(v);
      },
      validator: (v) {
        final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
        if (d.length != 8) return 'CEP inválido.';
        return null;
      },
    );
  }

  Widget _buildReadonlyInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      decoration: InputDecoration(
        hintText: hint,
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
      validator: validator,
    );
  }
}
