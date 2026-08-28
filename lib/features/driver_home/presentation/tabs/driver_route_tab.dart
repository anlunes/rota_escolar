import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/driver_home_provider.dart';
import '../../domain/models/student_in_route.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../../../app/core/widgets/status_chip.dart';
import '../../../../app/theme/app_colors.dart';

class DriverRouteTab extends ConsumerWidget {
  const DriverRouteTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverHomeProvider);
    final notifier = ref.read(driverHomeProvider.notifier);
    final periodStudents = state.studentsForCurrentPeriod;

    return Column(
      children: [
        // Period selector
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: RoutePeriod.values.map((period) {
                final selected = state.selectedPeriod == period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      period.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.text,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.text,
                    backgroundColor: AppColors.primaryLight,
                    onSelected: (_) => notifier.setPeriod(period),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Talk request alert banner
        if (state.talkRequestCount > 0)
          Container(
            width: double.infinity,
            color: AppColors.warning.withAlpha(30),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${state.talkRequestCount} responsável(is) quer(em) falar',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Student count info
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${periodStudents.length} alunos nesta rota',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),

        // Reorderable list (filtered by current period)
        Expanded(
          child: periodStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_outlined,
                          size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum aluno nesta rota',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: periodStudents.length,
                  onReorder: notifier.reorderStudentsInPeriod,
                  itemBuilder: (context, index) {
                    final student = periodStudents[index];
                    return _StudentRouteCard(
                      key: ValueKey(student.id),
                      student: student,
                      position: index + 1,
                      onStatusNext: () {
                        final next = _nextStatus(student.status);
                        if (next != null) {
                          notifier.updateStudentStatus(student.id, next);
                        }
                      },
                      onTalkAck: () =>
                          notifier.acknowledgeTalkRequest(student.id),
                      onWhatsApp: () =>
                          _openWhatsApp(student.guardianWhatsapp),
                      onRemoveFromRoute: () => notifier.removeStudentFromRoute(
                          student.id, state.selectedPeriod),
                    );
                  },
                ),
        ),
      ],
    );
  }

  StudentStatus? _nextStatus(StudentStatus current) {
    return switch (current) {
      StudentStatus.waitingVan => StudentStatus.toSchool,
      StudentStatus.toSchool => StudentStatus.atSchool,
      StudentStatus.atSchool => StudentStatus.toHome,
      StudentStatus.toHome => StudentStatus.atHome,
      StudentStatus.atHome => null,
    };
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/55$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StudentRouteCard extends StatelessWidget {
  final StudentInRoute student;
  final int position;
  final VoidCallback onStatusNext;
  final VoidCallback onTalkAck;
  final VoidCallback onWhatsApp;
  final VoidCallback onRemoveFromRoute;

  const _StudentRouteCard({
    super.key,
    required this.student,
    required this.position,
    required this.onStatusNext,
    required this.onTalkAck,
    required this.onWhatsApp,
    required this.onRemoveFromRoute,
  });

  @override
  Widget build(BuildContext context) {
    final canAdvance = student.status != StudentStatus.atHome;
    final ringColor =
        student.paymentPaid ? AppColors.success : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular photo with payment-status ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: student.photoUrl != null
                        ? NetworkImage(student.photoUrl!)
                        : null,
                    child: student.photoUrl == null
                        ? Text(
                            student.name[0].toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primaryDark),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                // Name + school
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: student.goToday
                                    ? AppColors.text
                                    : AppColors.textDisabled,
                              ),
                            ),
                          ),
                          if (!student.goToday) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.textDisabled.withAlpha(60),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Não vai hoje',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        student.school,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      // Payment status indicator
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ringColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            student.paymentPaid
                                ? 'Pgto em dia'
                                : 'Pgto pendente',
                            style: TextStyle(
                                fontSize: 10,
                                color: ringColor,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Remove from route button
                IconButton(
                  onPressed: onRemoveFromRoute,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.textSecondary, size: 18),
                  tooltip: 'Remover desta rota',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    student.address,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Status + Actions row
            Row(
              children: [
                StatusChip(status: student.status),
                const Spacer(),
                // Talk request alert
                if (student.talkRequested)
                  GestureDetector(
                    onTap: onTalkAck,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, size: 14, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Quer falar',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                // WhatsApp
                IconButton(
                  onPressed: onWhatsApp,
                  icon: SvgPicture.asset(
                    'assets/icons/whatsapp.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFF25D366), BlendMode.srcIn),
                  ),
                  tooltip: 'WhatsApp ${student.guardianName}',
                  style: IconButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF25D366).withAlpha(20),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
                const SizedBox(width: 4),
                // Next status
                if (student.goToday && canAdvance)
                  ElevatedButton(
                    onPressed: onStatusNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Avançar',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
