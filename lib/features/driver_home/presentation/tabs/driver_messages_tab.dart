import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/driver_home_provider.dart';
import '../../domain/models/student_in_route.dart';
import '../../../../app/theme/app_colors.dart';

class DriverMessagesTab extends ConsumerWidget {
  const DriverMessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverHomeProvider);
    final notifier = ref.read(driverHomeProvider.notifier);

    final talkRequests =
        state.students.where((s) => s.talkRequested).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            '${talkRequests.length} solicitação(ões) de conversa',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (talkRequests.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 56, color: AppColors.textDisabled),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma solicitação pendente',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: talkRequests.length,
              itemBuilder: (context, index) {
                final student = talkRequests[index];
                return _TalkRequestCard(
                  student: student,
                  onAck: () => notifier.acknowledgeTalkRequest(student.id),
                  onWhatsApp: () {
                    notifier.removeTalkRequest(student.id);
                    _openWhatsApp(
                        student.guardianWhatsapp, student.guardianName);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final msg = Uri.encodeComponent(
        'Olá $name, estou disponível para conversar. Pode me ligar?');
    final uri = Uri.parse('https://wa.me/55$phone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _TalkRequestCard extends StatelessWidget {
  final StudentInRoute student;
  final VoidCallback onAck;
  final VoidCallback onWhatsApp;

  const _TalkRequestCard({
    required this.student,
    required this.onAck,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final isAcknowledged = student.talkAcknowledged;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAcknowledged
                        ? AppColors.success.withAlpha(30)
                        : AppColors.warning.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAcknowledged ? Icons.done_all : Icons.chat_bubble,
                    color: isAcknowledged ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.guardianName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Responsável por ${student.name}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (isAcknowledged)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Ciente — aguardando contato',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isAcknowledged)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAck,
                      icon: const Icon(Icons.done, size: 16),
                      label: const Text('Ciente',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.textDisabled),
                      ),
                    ),
                  ),
                if (!isAcknowledged) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onWhatsApp,
                    icon: SvgPicture.asset(
                      'assets/icons/whatsapp.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
                    ),
                    label: const Text('WhatsApp',
                        style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
