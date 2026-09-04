import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../application/driver_home_provider.dart';
import '../../domain/models/student_in_route.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../../../app/core/widgets/status_chip.dart';
import '../../../../app/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Helper — lista de dias úteis a partir de hoje (inclui hoje)
// ---------------------------------------------------------------------------
List<DateTime> _buildWeekdays(int count) {
  final result = <DateTime>[];
  var d = DateTime.now();
  // Normaliza para meia-noite
  d = DateTime(d.year, d.month, d.day);
  while (result.length < count) {
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
      result.add(d);
    }
    d = d.add(const Duration(days: 1));
  }
  return result;
}

// ---------------------------------------------------------------------------
// Driver Route Tab
// ---------------------------------------------------------------------------

class DriverRouteTab extends ConsumerStatefulWidget {
  final VoidCallback? onGoToMessages;
  const DriverRouteTab({super.key, this.onGoToMessages});

  @override
  ConsumerState<DriverRouteTab> createState() => _DriverRouteTabState();
}

class _DriverRouteTabState extends ConsumerState<DriverRouteTab> {
  late final List<DateTime> _days;
  late DateTime _selectedDay;
  bool _isToday = true;

  // Dados para dias futuros
  bool _futureLoading = false;
  String? _futureError;
  List<Map<String, dynamic>> _futureStudents = [];

  @override
  void initState() {
    super.initState();
    _days = _buildWeekdays(14);
    _selectedDay = _days.first;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDay(DateTime day) {
    if (_isSameDay(day, _selectedDay)) return;
    setState(() {
      _selectedDay = day;
      _isToday = _isSameDay(day, _days.first);
      _futureStudents = [];
      _futureError = null;
    });
    if (!_isToday) _loadFuture(day);
  }

  Future<void> _loadFuture(DateTime day) async {
    setState(() { _futureLoading = true; _futureError = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dateStr =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.routesIndex}',
        queryParameters: {'date': dateStr},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final list = (res.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() { _futureStudents = list; _futureLoading = false; });
    } catch (e) {
      setState(() { _futureError = 'Erro ao carregar previsão.'; _futureLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverHomeProvider);
    final notifier = ref.read(driverHomeProvider.notifier);
    final periodStudents = state.studentsForCurrentPeriod;

    return Column(
      children: [
        // ── Faixa de datas ───────────────────────────────────────────────────
        Container(
          color: AppColors.primary,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final day = _days[i];
                    final selected = _isSameDay(day, _selectedDay);
                    final isToday = i == 0;
                    return GestureDetector(
                      onTap: () => _selectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.text
                              : AppColors.primaryLight.withAlpha(80),
                          borderRadius: BorderRadius.circular(10),
                          border: selected
                              ? null
                              : Border.all(
                                  color: AppColors.primaryLight.withAlpha(120)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isToday
                                  ? 'Hoje'
                                  : DateFormat('EEE', 'pt_BR')
                                      .format(day)
                                      .substring(0, 3)
                                      .toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.text,
                              ),
                            ),
                            Text(
                              DateFormat('MMM', 'pt_BR').format(day),
                              style: TextStyle(
                                fontSize: 9,
                                color: selected
                                    ? AppColors.primaryDark
                                    : AppColors.text.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Period selector (hoje e datas futuras) ───────────────────
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: RoutePeriod.values.map((period) {
                    final selected = state.selectedPeriod == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
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
            ],
          ),
        ),

        // ── Conteúdo principal ───────────────────────────────────────────────
        if (_isToday) ...[
          // Talk request alert banner
          if (state.talkRequestCount > 0)
            GestureDetector(
              onTap: widget.onGoToMessages,
              child: Container(
                width: double.infinity,
                color: AppColors.warning.withAlpha(30),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    const Icon(Icons.chevron_right,
                        color: AppColors.warning, size: 18),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '${periodStudents.length} alunos nesta rota',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          Expanded(
            child: periodStudents.isEmpty
                ? _emptyRoute()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
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
                          final next = _nextStatus(
                              student.status, state.selectedPeriod);
                          if (next != null) {
                            notifier.updateStudentStatus(student.id, next);
                          }
                        },
                        onTalkAck: () =>
                            notifier.acknowledgeTalkRequest(student.id),
                        onWhatsApp: () =>
                            _openWhatsApp(student.guardianWhatsapp),
                        onRemoveFromRoute: () =>
                            notifier.removeStudentFromRoute(
                                student.id, state.selectedPeriod),
                      );
                    },
                  ),
          ),
        ] else ...[
          // ── Visualização de data futura ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDay),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (!_futureLoading)
                  GestureDetector(
                    onTap: () => _loadFuture(_selectedDay),
                    child: const Icon(Icons.refresh,
                        size: 18, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (_futureLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (_futureError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_futureError!,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => _loadFuture(_selectedDay),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          else
            Builder(builder: (_) {
              // Filtra por turno de acordo com o período selecionado
              final turnoFiltro = (state.selectedPeriod == RoutePeriod.morningOutbound ||
                      state.selectedPeriod == RoutePeriod.morningReturn)
                  ? 'manha'
                  : 'tarde';
              final isOutbound = state.selectedPeriod.isOutbound;
              final filtered = _futureStudents
                  .where((s) => s['turno']?.toString() == turnoFiltro)
                  .toList();
              if (filtered.isEmpty) return Expanded(child: _emptyRoute());
              return Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _FutureStudentCard(
                      data: filtered[i], isOutbound: isOutbound),
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _emptyRoute() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined,
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text('Nenhum aluno nesta rota',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  StudentStatus? _nextStatus(StudentStatus current, RoutePeriod period) {
    if (period.isOutbound) {
      return switch (current) {
        StudentStatus.waitingVan => StudentStatus.toSchool,
        StudentStatus.toSchool => StudentStatus.atSchool,
        _ => null,
      };
    } else {
      return switch (current) {
        StudentStatus.atSchool => StudentStatus.toHome,
        StudentStatus.toHome => StudentStatus.atHome,
        _ => null,
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

// ---------------------------------------------------------------------------
// Card para datas futuras (informação + WhatsApp responsável, sem status)
// ---------------------------------------------------------------------------

class _FutureStudentCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isOutbound;

  const _FutureStudentCard({required this.data, required this.isOutbound});

  Future<void> _openWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('https://wa.me/55$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name         = data['name']?.toString() ?? '';
    final turno        = data['turno']?.toString() ?? '';
    final school       = data['school']?.toString() ?? '';
    final address      = data['address']?.toString() ?? '';
    final photoUrl     = data['foto_url']?.toString();
    final guardianName = data['guardian_name']?.toString() ?? '';
    final guardianWa   = data['guardian_whatsapp']?.toString() ?? '';
    final vaiHoje      = int.tryParse(data['vai_hoje']?.toString() ?? '1') ?? 1;
    final ausente      = vaiHoje == 0;
    final destino      = isOutbound
        ? (school.isNotEmpty ? school : 'Escola')
        : (address.isNotEmpty ? address : 'Endereço não informado');
    final destinoIcon  = isOutbound ? Icons.school_outlined : Icons.home_outlined;

    return _RouteCardShell(
      ausente: ausente,
      absentLabel: 'AUSÊNCIA AGENDADA',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Opacity(
                  opacity: ausente ? 0.45 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.primaryLight, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 27,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.primaryDark))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ausente ? AppColors.textDisabled : AppColors.text,
                      decoration: ausente ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(destinoIcon, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    destino,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (turno.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withAlpha(80),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      turno == 'manha' ? 'Manhã' : 'Tarde',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark),
                    ),
                  ),
                const Spacer(),
                if (guardianWa.isNotEmpty)
                  IconButton(
                    onPressed: () => _openWhatsApp(guardianWa),
                    icon: SvgPicture.asset(
                      'assets/icons/whatsapp.svg',
                      width: 18,
                      height: 18,
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF25D366), BlendMode.srcIn),
                    ),
                    tooltip: 'WhatsApp $guardianName',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF25D366).withAlpha(20),
                      padding: const EdgeInsets.all(5),
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

// ---------------------------------------------------------------------------
// Shell compartilhado pelos dois cards (banner de ausência + borda)
// ---------------------------------------------------------------------------

class _RouteCardShell extends StatelessWidget {
  final bool ausente;
  final String absentLabel;
  final Widget child;

  const _RouteCardShell({
    required this.ausente,
    required this.absentLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: ausente ? AppColors.error.withAlpha(18) : null,
      shape: ausente
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.error.withAlpha(120), width: 1.5),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ausente)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, size: 13, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    absentLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card de hoje (reorderable, com ações de status)
// ---------------------------------------------------------------------------

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

  String get _destinationLabel {
    if (period.isOutbound)
      return student.school.isNotEmpty ? student.school : 'Escola';
    return student.address.isNotEmpty
        ? student.address
        : 'Endereço não informado';
  }

  IconData get _destinationIcon =>
      period.isOutbound ? Icons.school_outlined : Icons.home_outlined;

  String get _advanceLabel {
    if (period.isOutbound) {
      return switch (student.status) {
        StudentStatus.waitingVan => 'Embarcou',
        StudentStatus.toSchool => 'Chegou',
        _ => '',
      };
    } else {
      return switch (student.status) {
        StudentStatus.atSchool => 'Saiu',
        StudentStatus.toHome => 'Em casa',
        _ => '',
      };
    }
  }

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
    final ringColor    = student.paymentPaid ? AppColors.success : AppColors.error;
    final nameInitial  = student.name.isNotEmpty ? student.name[0].toUpperCase() : '?';
    final notGoing     = !student.goToday;
    final turnoLabel   = student.activeRoutes?.any((p) =>
            p == RoutePeriod.morningOutbound || p == RoutePeriod.morningReturn) == true
        ? 'Manhã'
        : 'Tarde';

    return _RouteCardShell(
      ausente: notGoing,
      absentLabel: 'NÃO VAI HOJE — responsável avisou',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botão "Remover da fila" dentro do banner é tratado pelo shell acima;
          // aqui adicionamos só se ausente (sobrepõe o shell com ação)
          if (notGoing)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 4),
                child: GestureDetector(
                  onTap: onRemoveFromRoute,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error.withAlpha(120)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_circle_outline, size: 13, color: AppColors.error),
                        SizedBox(width: 4),
                        Text('Remover da fila',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha: avatar + nome + badge falar + remover
                Row(
                  children: [
                    Opacity(
                      opacity: notGoing ? 0.45 : 1.0,
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
                    Expanded(
                      child: Text(
                        student.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: notGoing ? AppColors.textDisabled : AppColors.text,
                          decoration: notGoing ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                    if (!notGoing)
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

                // Destino
                Row(
                  children: [
                    Icon(_destinationIcon, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _destinationLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Status + turno + WhatsApp + avançar
                Row(
                  children: [
                    StatusChip(status: student.status),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        turnoLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark),
                      ),
                    ),
                    const Spacer(),
                    if (student.guardianWhatsapp.isNotEmpty)
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
