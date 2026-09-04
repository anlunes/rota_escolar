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
  final VoidCallback? onGoToMessages;
  const DriverRouteTab({super.key, this.onGoToMessages});

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
          GestureDetector(
            onTap: onGoToMessages,
            child: Container(
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
                  const Icon(Icons.chevron_right, color: AppColors.warning, size: 18),
                ],
              ),
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
                      period: state.selectedPeriod,
                      position: index + 1,
                      onStatusNext: () {
                        final next = _nextStatus(student.status, state.selectedPeriod);
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

  StudentStatus? _nextStatus(StudentStatus current, RoutePeriod period) {
    if (period.isOutbound) {
      // Ida: casa → rota ida → escola (para no atSchool)
      return switch (current) {
        StudentStatus.waitingVan => StudentStatus.toSchool,
        StudentStatus.toSchool   => StudentStatus.atSchool,
        _                        => null,
      };
    } else {
      // Volta: escola → rota volta → em casa
      return switch (current) {
        StudentStatus.atSchool => StudentStatus.toHome,
        StudentStatus.toHome   => StudentStatus.atHome,
        _                      => null,
      };
    }
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
  final RoutePeriod period;
  final int position;
  final VoidCallback onStatusNext;
  final VoidCallback onTalkAck;
  final VoidCallback onWhatsApp;
  final VoidCallback onRemoveFromRoute;

  const _StudentRouteCard({
    super.key,
    required this.student,
    required this.period,
    required this.position,
    required this.onStatusNext,
    required this.onTalkAck,
    required this.onWhatsApp,
    required this.onRemoveFromRoute,
  });

  /// Destino contextual: ida → escola, volta → casa
  String get _destinationLabel {
    if (period.isOutbound) return student.school.isNotEmpty ? student.school : 'Escola';
    return student.address.isNotEmpty ? student.address : 'Endereço não informado';
  }

  IconData get _destinationIcon =>
      period.isOutbound ? Icons.school_outlined : Icons.home_outlined;

  /// Texto do botão avançar de acordo com o período e o status atual
  String get _advanceLabel {
    if (period.isOutbound) {
      return switch (student.status) {
        StudentStatus.waitingVan => 'Embarcou',
        StudentStatus.toSchool   => 'Chegou',
        _                        => '',
      };
    } else {
      return switch (student.status) {
        StudentStatus.atSchool => 'Saiu',
        StudentStatus.toHome   => 'Em casa',
        _                      => '',
      };
    }
  }

  /// Pode avançar se o status atual é válido para o período selecionado
  bool get _canAdvanceInPeriod {
    if (period.isOutbound) {
      return student.status == StudentStatus.waitingVan ||
             student.status == StudentStatus.toSchool;
    } else {
      return student.status == StudentStatus.atSchool ||
             student.status == StudentStatus.toHome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = student.paymentPaid ? AppColors.success : AppColors.error;
    final nameInitial = student.name.isNotEmpty ? student.name[0].toUpperCase() : '?';
    final notGoingToday = !student.goToday;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: notGoingToday ? AppColors.error.withAlpha(18) : null,
      shape: notGoingToday
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.error.withAlpha(120), width: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner "Não vai hoje" ────────────────────────────────
          if (notGoingToday)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'NÃO VAI HOJE — responsável avisou',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onRemoveFromRoute,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withAlpha(100)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.remove_circle_outline, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Remover da fila',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Conteúdo do card ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha principal
                Row(
                  children: [
                    // Avatar com anel de pagamento
                    Opacity(
                      opacity: notGoingToday ? 0.45 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ringColor, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: student.photoUrl != null
                              ? NetworkImage(student.photoUrl!)
                              : null,
                          child: student.photoUrl == null
                              ? Text(nameInitial,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: AppColors.primaryDark))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nome
                    Expanded(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: notGoingToday ? AppColors.textDisabled : AppColors.text,
                          decoration: notGoingToday ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Talk request badge
                    if (student.talkRequested)
                      GestureDetector(
                        onTap: onTalkAck,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat, size: 12, color: AppColors.warning),
                              SizedBox(width: 3),
                              Text('Falar',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    // Remover
                    IconButton(
                      onPressed: onRemoveFromRoute,
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 16, color: AppColors.textDisabled),
                      tooltip: 'Remover desta rota',
                      style: IconButton.styleFrom(padding: const EdgeInsets.all(4)),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // Destino contextual
                Row(
                  children: [
                    Icon(_destinationIcon, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _destinationLabel,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Status + Ações
                Row(
                  children: [
                    StatusChip(status: student.status),
                    const Spacer(),
                    // WhatsApp
                    IconButton(
                      onPressed: onWhatsApp,
                      icon: SvgPicture.asset(
                        'assets/icons/whatsapp.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                            Color(0xFF25D366), BlendMode.srcIn),
                      ),
                      tooltip: 'WhatsApp ${student.guardianName}',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366).withAlpha(20),
                        padding: const EdgeInsets.all(5),
                      ),
                    ),
                    if (student.goToday && _canAdvanceInPeriod) ...[
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: onStatusNext,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(_advanceLabel,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
