import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/auth_state_provider.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/core/widgets/app_button.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/app_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .login(_emailCtrl.text.trim(), _passCtrl.text);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu e-mail antes de solicitar a redefinição.')),
      );
      return;
    }

    try {
      final dio = Dio();
      await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authForgotPassword}',
        data: {'email': email},
      );
      if (mounted) {
        _showResetCodeDialog(email);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível processar. Tente novamente.')),
        );
      }
    }
  }

  void _showResetCodeDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetCodeDialog(email: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Van illustration
                Image.asset(
                  'assets/branding/van_illustration.png',
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Bem-vindo!',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Faça login para continuar',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Informe o e-mail';
                          }
                          if (!v.contains('@')) return 'E-mail inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Informe a senha';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Esqueci a senha'),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Entrar',
                  onPressed: _login,
                  isLoading: isLoading,
                  width: double.infinity,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Não tem conta? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text(
                        'Cadastre-se',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Hint for testing
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            'Demo',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'motorista@teste.com → Home Motorista\nresponsavel@teste.com → Home Responsável',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
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
// Dialog de código de redefinição — fica em memória mesmo ao alternar apps
// ---------------------------------------------------------------------------

class _ResetCodeDialog extends StatefulWidget {
  final String email;
  const _ResetCodeDialog({required this.email});

  @override
  State<_ResetCodeDialog> createState() => _ResetCodeDialogState();
}

class _ResetCodeDialogState extends State<_ResetCodeDialog> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());

  bool _isLoading   = false;
  bool _isResending = false;
  int  _cooldown    = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_cooldown <= 0) { t.cancel(); return; }
      setState(() => _cooldown--);
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 6) {
      for (int i = 0; i < 6; i++) _controllers[i].text = value[i];
      _focusNodes.last.requestFocus();
      return;
    }
    if (value.isNotEmpty && index < 5) _focusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0)    _focusNodes[index - 1].requestFocus();
  }

  Future<void> _verify() async {
    if (_code.length < 6) {
      _showMsg('Digite todos os 6 dígitos.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dio = Dio();
      final res = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authVerifyResetCode}',
        data: {'email': widget.email, 'code': _code},
      );
      final resetLink = res.data['data']['reset_link'] as String?;
      if (resetLink != null && mounted) {
        final uri = Uri.parse(resetLink);
        // Abre o browser ANTES de fechar o dialog
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crie sua nova senha no navegador e volte para fazer login.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 6),
            ),
          );
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Código inválido ou expirado.';
      _showMsg(msg, isError: true);
      for (final c in _controllers) c.clear();
      _focusNodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await Dio().post(
        '${ApiConstants.baseUrl}${ApiConstants.authForgotPassword}',
        data: {'email': widget.email},
      );
      if (mounted) {
        _showMsg('Novo código enviado!');
        _startCooldown();
        for (final c in _controllers) c.clear();
        _focusNodes.first.requestFocus();
      }
    } catch (_) {
      _showMsg('Não foi possível reenviar.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  String _masked(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Verifique seu e-mail',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Enviamos um código de 6 dígitos para\n${_masked(widget.email)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Campos de 6 dígitos
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 42,
                  height: 50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: i == 0 ? 6 : 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            AppButton(
              label: 'Confirmar código',
              onPressed: _verify,
              isLoading: _isLoading,
              width: double.infinity,
            ),

            const SizedBox(height: 12),

            if (_cooldown > 0)
              Text('Reenviar em ${_cooldown}s',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
            else
              TextButton(
                onPressed: _isResending ? null : _resend,
                child: _isResending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Não recebi — reenviar'),
              ),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

