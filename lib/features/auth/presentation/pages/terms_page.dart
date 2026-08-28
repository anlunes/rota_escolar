import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _accepting = false;

  Future<void> _acceptTerms() async {
    setState(() => _accepting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    if (mounted) context.go('/terms-done');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        title: const Text(
          'Termos de Uso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bem-vindo ao Rota Escolar',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última atualização: maio de 2026',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: '1. Aceitação dos Termos',
                    body:
                        'Ao usar o Rota Escolar, você concorda com estes Termos de Uso. '
                        'Se não concordar, não utilize o aplicativo.',
                  ),
                  _Section(
                    title: '2. Descrição do Serviço',
                    body:
                        'O Rota Escolar é uma plataforma que conecta responsáveis por '
                        'alunos a motoristas de transporte escolar, permitindo o '
                        'acompanhamento em tempo real das rotas escolares.',
                  ),
                  _Section(
                    title: '3. Cadastro e Conta',
                    body:
                        'Você é responsável por manter a confidencialidade das suas '
                        'credenciais de acesso. Informações falsas podem resultar no '
                        'cancelamento da conta.',
                  ),
                  _Section(
                    title: '4. Privacidade e Dados',
                    body:
                        'Coletamos dados necessários para o funcionamento do serviço, '
                        'como localização, nome e contato. Seus dados não serão '
                        'compartilhados com terceiros sem seu consentimento.',
                  ),
                  _Section(
                    title: '5. Responsabilidades',
                    body:
                        'Motoristas são responsáveis por manter documentação em dia e '
                        'operar veículos em conformidade com a legislação. Responsáveis '
                        'devem fornecer informações corretas sobre os alunos.',
                  ),
                  _Section(
                    title: '6. Pagamentos',
                    body:
                        'Os valores de mensalidade são acordados diretamente entre '
                        'responsáveis e motoristas. O Rota Escolar não processa '
                        'pagamentos financeiros.',
                  ),
                  _Section(
                    title: '7. Modificações',
                    body:
                        'Podemos atualizar estes termos a qualquer momento. '
                        'Notificaremos sobre mudanças significativas pelo aplicativo.',
                  ),
                  _Section(
                    title: '8. Contato',
                    body:
                        'Dúvidas? Entre em contato pelo e-mail: '
                        'suporte@rotaescolar.com.br',
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accepting ? null : _acceptTerms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _accepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Li e Aceito',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
