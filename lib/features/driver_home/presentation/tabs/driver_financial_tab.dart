import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/driver_home_provider.dart';
import '../../../../app/theme/app_colors.dart';

class DriverFinancialTab extends ConsumerWidget {
  const DriverFinancialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverHomeProvider);
    final notifier = ref.read(driverHomeProvider.notifier);
    final payments = state.payments;

    final totalPaid = payments
        .where((p) => p.paid)
        .fold(0.0, (sum, p) => sum + p.amount);
    final totalPending = payments
        .where((p) => !p.paid)
        .fold(0.0, (sum, p) => sum + p.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Recebido',
                  value: 'R\$ ${totalPaid.toStringAsFixed(2)}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Pendente',
                  value: 'R\$ ${totalPending.toStringAsFixed(2)}',
                  color: AppColors.warning,
                  icon: Icons.pending_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cobrar aviso
          if (totalPending > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(120)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Você tem R\$ ${totalPending.toStringAsFixed(2)} a receber. Envie lembretes via WhatsApp.',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          Text(
            'Mensalidades — Maio/2026',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...payments.asMap().entries.map((entry) {
            final index = entry.key;
            final p = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      p.paid ? AppColors.success.withAlpha(30) : AppColors.warning.withAlpha(30),
                  child: Icon(
                    p.paid ? Icons.check : Icons.attach_money,
                    color: p.paid ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                title: Text(p.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  p.paidInCash
                      ? 'Pago em espécie'
                      : p.paid
                          ? 'Pago'
                          : 'Aguardando pagamento',
                  style: TextStyle(
                    fontSize: 12,
                    color: p.paid ? AppColors.success : AppColors.warning,
                  ),
                ),
                trailing: p.paid
                    ? Chip(
                        label: Text(
                          'R\$ ${p.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppColors.success.withAlpha(30),
                        side: BorderSide.none,
                      )
                    : ElevatedButton.icon(
                        onPressed: () => notifier.markPaymentCash(index),
                        icon: const Icon(Icons.payments, size: 14),
                        label: const Text('Pago espécie',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
