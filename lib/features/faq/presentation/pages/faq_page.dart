import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  static const _items = [
    _FaqItem(
      question: 'Como funciona o Rota Escolar?',
      answer:
          'O Rota Escolar conecta responsáveis e motoristas de transporte escolar. '
          'Responsáveis acompanham o trajeto dos filhos em tempo real e podem '
          'comunicar-se com o motorista pelo aplicativo.',
    ),
    _FaqItem(
      question: 'Como cadastro meu filho?',
      answer:
          'Na aba "Filho", toque em "Cadastrar Filho" e preencha o nome, '
          'endereço e escola. Você pode informar um VanCode para vincular ao '
          'motorista específico.',
    ),
    _FaqItem(
      question: 'O que é o VanCode?',
      answer:
          'VanCode é o código único de identificação da van/motorista. Ao '
          'informar o VanCode no cadastro do filho, uma solicitação é enviada '
          'diretamente ao motorista para avaliação.',
    ),
    _FaqItem(
      question: 'Como marco se meu filho vai hoje?',
      answer:
          'Na aba "Filho", use o botão "Vai hoje / Não vai hoje" no card do '
          'aluno. O motorista é notificado automaticamente.',
    ),
    _FaqItem(
      question: 'Como solicitar falar com o motorista?',
      answer:
          'Toque no botão "Quero falar" no card do filho. O motorista verá a '
          'solicitação e poderá entrar em contato pelo WhatsApp.',
    ),
    _FaqItem(
      question: 'Como vejo o histórico de rotas?',
      answer:
          'Acesse a aba "Relatório" para ver os últimos 14 dias de rotas, '
          'com horários de embarque, chegada à escola e retorno.',
    ),
    _FaqItem(
      question: 'Como um motorista aceita novos alunos?',
      answer:
          'Na aba "Vagas", o motorista vê as solicitações de novos alunos e '
          'pode aceitar ou recusar. Ao aceitar, o aluno é adicionado à rota.',
    ),
    _FaqItem(
      question: 'Como atualizo meus dados?',
      answer:
          'Motoristas podem editar Estado, Cidade, Bairros e Escolas atendidas '
          'na aba "Perfil", tocando no ícone de edição.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        title: const Text(
          'Ajuda / FAQ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline,
                    color: AppColors.primaryDark, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Perguntas Frequentes',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ..._items.map((item) => _FaqCard(item: item)),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;

  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Text(
                  widget.item.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
