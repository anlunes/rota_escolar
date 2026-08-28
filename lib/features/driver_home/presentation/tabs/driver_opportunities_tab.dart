import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/driver_home_provider.dart';
import '../../../../app/theme/app_colors.dart';

class DriverOpportunitiesTab extends ConsumerWidget {
  const DriverOpportunitiesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverHomeProvider);
    final notifier = ref.read(driverHomeProvider.notifier);
    final opportunities = state.opportunities;

    final pending = opportunities.where((o) => !o.accepted && !o.declined).toList();
    final resolved = opportunities.where((o) => o.accepted || o.declined).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pending.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  'Novas candidaturas (${pending.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...pending.map(
              (o) => _OpportunityCard(
                opportunity: o,
                onAccept: () => notifier.acceptOpportunity(o.id),
                onDecline: () => notifier.declineOpportunity(o.id),
                onWhatsApp: () => _openWhatsApp(o.guardianWhatsapp, o.guardianName),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (resolved.isNotEmpty) ...[
            Text(
              'Resolvidas',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            ...resolved.map(
              (o) => _OpportunityCard(
                opportunity: o,
                onAccept: null,
                onDecline: null,
                onWhatsApp: () => _openWhatsApp(o.guardianWhatsapp, o.guardianName),
              ),
            ),
          ],

          if (opportunities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 56, color: AppColors.textDisabled),
                    SizedBox(height: 12),
                    Text(
                      'Nenhuma candidatura no momento',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final msg = Uri.encodeComponent('Olá $name, recebi sua candidatura no Rota Escolar.');
    final uri = Uri.parse('https://wa.me/55$phone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _OpportunityCard extends StatelessWidget {
  final CandidateOpportunity opportunity;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onWhatsApp;

  const _OpportunityCard({
    required this.opportunity,
    required this.onAccept,
    required this.onDecline,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = opportunity.accepted || opportunity.declined;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.child_care, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opportunity.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Responsável: ${opportunity.guardianName}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // WhatsApp button
                IconButton(
                  onPressed: onWhatsApp,
                  icon: SvgPicture.asset(
                    'assets/icons/whatsapp.svg',
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF25D366), BlendMode.srcIn),
                  ),
                  tooltip: 'WhatsApp ${opportunity.guardianName}',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withAlpha(20),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
                if (isResolved)
                  Chip(
                    label: Text(
                      opportunity.accepted ? 'Aceito' : 'Recusado',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: opportunity.accepted
                        ? AppColors.success.withAlpha(30)
                        : AppColors.error.withAlpha(30),
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.school, text: opportunity.school),
            const SizedBox(height: 4),
            _InfoRow(
                icon: Icons.location_on_outlined, text: opportunity.address),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.schedule, text: opportunity.period),
            if (!isResolved) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDecline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Recusar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Aceitar'),
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
