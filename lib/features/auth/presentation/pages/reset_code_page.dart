import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/core/widgets/app_button.dart';
import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';

class ResetCodePage extends StatefulWidget {
  final String email;

  const ResetCodePage({super.key, required this.email});

  @override
  State<ResetCodePage> createState() => _ResetCodePageState();
}

class _ResetCodePageState extends State<ResetCodePage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes  = List.generate(6, (_) => FocusNode());

  bool _isLoading  = false;
  bool _isResending = false;
  int  _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) {
      _showError('Digite todos os 6 dígitos do código.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authVerifyResetCode}',
        data: {'email': widget.email, 'code': _code},
      );

      final resetLink = response.data['data']['reset_link'] as String?;
      if (resetLink != null && mounted) {
        final uri = Uri.parse(resetLink);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link aberto! Crie sua nova senha no navegador e volte para fazer login.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 6),
            ),
          );
          context.go(AppRoutes.login);
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] as String? ??
          'Código inválido ou expirado. Tente novamente.';
      _showError(msg);
      // Limpa os campos para redigitar
      for (final c in _controllers) c.clear();
      _focusNodes.first.requestFocus();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final dio = Dio();
      await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authForgotPassword}',
        data: {'email': widget.email},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Novo código enviado para seu e-mail.'),
            backgroundColor: AppColors.success,
          ),
        );
        _startCooldown();
        for (final c in _controllers) c.clear();
        _focusNodes.first.requestFocus();
      }
    } catch (_) {
      _showError('Não foi possível reenviar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 6) {
      // Colou o código inteiro — distribui pelos campos
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes.last.requestFocus();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String _maskedEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: AppColors.primary),
        title: const Text('Verificar identidade',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Código enviado!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enviamos um código de 6 dígitos para\n${_maskedEmail(widget.email)}\n\nDigite-o abaixo. Válido por 10 minutos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 40),

              // Campos de 6 dígitos
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  return Container(
                    width: 46,
                    height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: i == 0 ? 6 : 1, // permite colar no primeiro campo
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Confirmar código',
                onPressed: _verify,
                isLoading: _isLoading,
                width: double.infinity,
              ),

              const SizedBox(height: 24),

              // Reenviar
              if (_resendCooldown > 0)
                Text(
                  'Reenviar código em ${_resendCooldown}s',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                )
              else
                TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Não recebi o código — reenviar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
