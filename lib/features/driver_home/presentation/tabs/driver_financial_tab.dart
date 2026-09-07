import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/driver_home_provider.dart';
import '../../data/driver_repository.dart';
import '../../../../app/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Provider de pagamentos por mês (fora do provider global para ter estado local)
// ---------------------------------------------------------------------------

class _FinancialState {
  final int mes;
  final int ano;
  final bool loading;
  final bool generating;
  final String? error;
  final List<PaymentRecord> payments;
  final int pendentesGeracao;
  final double valorServico;

  const _FinancialState({
    required this.mes,
    required this.ano,
    this.loading        = false,
    this.generating     = false,
    this.error,
    this.payments       = const [],
    this.pendentesGeracao = 0,
    this.valorServico   = 0,
  });

  _FinancialState copyWith({
    int? mes, int? ano, bool? loading, bool? generating,
    String? error, List<PaymentRecord>? payments,
    int? pendentesGeracao, double? valorServico,
  }) => _FinancialState(
    mes:               mes               ?? this.mes,
    ano:               ano               ?? this.ano,
    loading:           loading           ?? this.loading,
    generating:        generating        ?? this.generating,
    error:             error,
    payments:          payments          ?? this.payments,
    pendentesGeracao:  pendentesGeracao  ?? this.pendentesGeracao,
    valorServico:      valorServico      ?? this.valorServico,
  );
}

// ---------------------------------------------------------------------------

class DriverFinancialTab extends ConsumerStatefulWidget {
  const DriverFinancialTab({super.key});

  @override
  ConsumerState<DriverFinancialTab> createState() => _DriverFinancialTabState();
}

class _DriverFinancialTabState extends ConsumerState<DriverFinancialTab> {
  late _FinancialState _state;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _state = _FinancialState(mes: now.month, ano: now.year);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DriverRepository get _repo => ref.read(driverRepositoryProvider);

  Future<void> _load() async {
    setState(() => _state = _state.copyWith(loading: true, error: null));
    try {
      final result = await _repo.fetchPaymentsByMonth(_state.mes, _state.ano);
      setState(() => _state = _state.copyWith(
        loading:           false,
        payments:          result['mensalidades'] as List<PaymentRecord>,
        pendentesGeracao:  result['pendentes_geracao'] as int,
        valorServico:      (result['valor_servico'] as num).toDouble(),
      ));
    } catch (e) {
      setState(() => _state = _state.copyWith(loading: false, error: e.toString()));
    }
  }

  void _changeMonth(int delta) {
    var mes = _state.mes + delta;
    var ano = _state.ano;
    if (mes < 1)  { mes = 12; ano--; }
    if (mes > 12) { mes = 1;  ano++; }
    setState(() => _state = _state.copyWith(mes: mes, ano: ano));
    _load();
  }

  Future<void> _generate() async {
    if (_state.valorServico <= 0) {
      _showMsg('Configure o valor mensal por aluno no seu perfil primeiro.');
      return;
    }
    setState(() => _state = _state.copyWith(generating: true, error: null));
    try {
      await _repo.generateCharges(_state.mes, _state.ano);
      await _load();
      _showMsg('Cobranças geradas com sucesso!');
    } catch (e) {
      setState(() => _state = _state.copyWith(generating: false, error: e.toString()));
    } finally {
      if (mounted) setState(() => _state = _state.copyWith(generating: false));
    }
  }

  Future<void> _markCash(PaymentRecord p) async {
    // Otimista
    setState(() => _state = _state.copyWith(
      payments: _state.payments.map((x) => x.id == p.id
          ? PaymentRecord(
              id: p.id, studentName: p.studentName,
              responsavelNome: p.responsavelNome,
              responsavelWhatsapp: p.responsavelWhatsapp,
              mes: p.mes, ano: p.ano, amount: p.amount,
              status: 'pago', formaPagamento: 'dinheiro',
              asaasLink: p.asaasLink, dataVencimento: p.dataVencimento,
              dataPagamento: DateTime.now().toIso8601String().substring(0, 10),
            )
          : x).toList(),
    ));
    final ok = await _repo.markPayment(p.id);
    if (!ok) { _showMsg('Erro ao registrar pagamento.'); _load(); }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (_) { _showMsg('Não foi possível abrir o link.'); }
  }

  Future<void> _openWhatsapp(String phone, String studentName, double valor) async {
    final fone = phone.replaceAll(RegExp(r'\D'), '');
    if (fone.isEmpty) { _showMsg('WhatsApp do responsável não cadastrado.'); return; }
    final mes   = _mesLabel(_state.mes, _state.ano);
    final texto = Uri.encodeComponent(
      'Olá! Segue o lembrete de pagamento da mensalidade de $studentName referente a $mes — R\$ ${valor.toStringAsFixed(2)}. Qualquer dúvida, estou à disposição!',
    );
    final uri = Uri.parse('https://wa.me/55$fone?text=$texto');
    try { await launchUrl(uri, mode: LaunchMode.externalApplication); }
    catch (_) { _showMsg('WhatsApp não disponível.'); }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _mesLabel(int mes, int ano) {
    const nomes = ['','Janeiro','Fevereiro','Março','Abril','Maio','Junho',
                   'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'];
    return '${nomes[mes]}/$ano';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final payments    = _state.payments;
    final recebido    = payments.where((p) => p.paid).fold(0.0, (s, p) => s + p.amount);
    final pendente    = payments.where((p) => p.status == 'pendente').fold(0.0, (s, p) => s + p.amount);
    final atrasado    = payments.where((p) => p.atrasado).fold(0.0, (s, p) => s + p.amount);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Seletor de mês ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _state.loading ? null : () => _changeMonth(-1),
                    ),
                    Text(
                      _mesLabel(_state.mes, _state.ano),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _state.loading ? null : () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Cards resumo ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _SummaryCard(
                  label: 'Recebido',
                  value: 'R\$ ${recebido.toStringAsFixed(2)}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                )),
                const SizedBox(width: 8),
                Expanded(child: _SummaryCard(
                  label: 'Pendente',
                  value: 'R\$ ${pendente.toStringAsFixed(2)}',
                  color: AppColors.warning,
                  icon: Icons.pending_outlined,
                )),
                if (atrasado > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _SummaryCard(
                    label: 'Atrasado',
                    value: 'R\$ ${atrasado.toStringAsFixed(2)}',
                    color: AppColors.error,
                    icon: Icons.warning_amber_outlined,
                  )),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── Botão gerar cobranças ───────────────────────────────────────
            if (_state.pendentesGeracao > 0 && !_state.loading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _state.generating ? null : _generate,
                  icon: _state.generating
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                    _state.generating
                        ? 'Gerando cobranças...'
                        : 'Gerar cobranças — ${_mesLabel(_state.mes, _state.ano)} (${_state.pendentesGeracao} aluno${_state.pendentesGeracao > 1 ? 's' : ''})',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            if (_state.error != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(80)),
                ),
                child: Text(_state.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 16),

            // ── Lista de pagamentos ─────────────────────────────────────────
            if (_state.loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (payments.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 12),
                      Text(
                        _state.pendentesGeracao > 0
                            ? 'Clique em "Gerar cobranças" para criar as mensalidades deste mês.'
                            : 'Nenhuma cobrança para este mês.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...payments.map((p) => _PaymentCard(
                payment: p,
                onMarkCash:  () => _markCash(p),
                onOpenLink:  p.asaasLink != null ? () => _openLink(p.asaasLink!) : null,
                onWhatsapp:  () => _openWhatsapp(p.responsavelWhatsapp, p.studentName, p.amount),
              )),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card individual de pagamento
// ---------------------------------------------------------------------------

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  final VoidCallback  onMarkCash;
  final VoidCallback? onOpenLink;
  final VoidCallback  onWhatsapp;

  const _PaymentCard({
    required this.payment,
    required this.onMarkCash,
    required this.onOpenLink,
    required this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final p      = payment;
    final isPago = p.paid;

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (p.status) {
      case 'pago':
        statusColor = AppColors.success; statusIcon = Icons.check_circle; statusLabel = 'Pago';
        break;
      case 'atrasado':
        statusColor = AppColors.error;   statusIcon = Icons.warning_amber; statusLabel = 'Atrasado';
        break;
      case 'cancelado':
        statusColor = AppColors.textSecondary; statusIcon = Icons.cancel_outlined; statusLabel = 'Cancelado';
        break;
      default:
        statusColor = AppColors.warning; statusIcon = Icons.schedule;      statusLabel = 'Pendente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(p.responsavelNome,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('R\$ ${p.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 3),
                        Text(statusLabel,
                            style: TextStyle(fontSize: 12, color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Detalhes
            if (p.dataVencimento != null || p.formaPagamento != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (p.dataVencimento != null) ...[
                    const Icon(Icons.event_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Vence ${_formatDate(p.dataVencimento!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const Spacer(),
                  if (p.paidInCash)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 13, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Dinheiro', style: TextStyle(fontSize: 12, color: AppColors.success)),
                      ],
                    )
                  else if (p.formaPagamento == 'asaas')
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pix_outlined, size: 13, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Pix/Boleto/Cartão', style: TextStyle(fontSize: 12, color: AppColors.success)),
                      ],
                    ),
                ],
              ),
            ],

            // Ações (só se não pago)
            if (!isPago && p.status != 'cancelado') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Pago em dinheiro
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarkCash,
                      icon: const Icon(Icons.payments_outlined, size: 15),
                      label: const Text('Dinheiro', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: BorderSide(color: AppColors.success.withAlpha(120)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  // Ver cobrança Asaas
                  if (onOpenLink != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onOpenLink,
                        icon: const Icon(Icons.open_in_browser, size: 15),
                        label: const Text('Ver cobrança', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                  // WhatsApp lembrete
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onWhatsapp,
                    icon: const Icon(Icons.chat_outlined, size: 20),
                    color: const Color(0xFF25D366),
                    tooltip: 'Enviar lembrete via WhatsApp',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withAlpha(20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(String iso) {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

// ---------------------------------------------------------------------------
// Card resumo
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final IconData icon;

  const _SummaryCard({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ]),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
