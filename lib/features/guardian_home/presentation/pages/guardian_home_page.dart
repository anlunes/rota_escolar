import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../application/guardian_home_provider.dart';
import '../../domain/models/student_summary.dart';
import '../../../../features/evaluation/presentation/widgets/monthly_evaluation_modal.dart';
import '../../../../features/auth/application/auth_state_provider.dart';
import '../../../../app/core/constants/status_constants.dart';
import '../../../../app/core/widgets/status_chip.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/core/constants/api_constants.dart';

// ---------------------------------------------------------------------------
// Mock available drivers for the Drivers tab
// ---------------------------------------------------------------------------
class _DriverInfo {
  final String id;
  final String name;
  final String vanCode;
  final double rating;
  final List<String> neighborhoods;
  final String whatsapp;

  const _DriverInfo({
    required this.id,
    required this.name,
    required this.vanCode,
    required this.rating,
    required this.neighborhoods,
    required this.whatsapp,
  });
}

const _mockDrivers = [
  _DriverInfo(
    id: 'd1',
    name: 'João Motorista',
    vanCode: 'VAN12345',
    rating: 4.8,
    neighborhoods: ['Jardim Primavera', 'Centro', 'Vila Verde'],
    whatsapp: '11988888888',
  ),
  _DriverInfo(
    id: 'd2',
    name: 'Maria Condutora',
    vanCode: 'VAN67890',
    rating: 4.6,
    neighborhoods: ['Parque Sol', 'Boa Vista', 'Centro'],
    whatsapp: '11977777777',
  ),
  _DriverInfo(
    id: 'd3',
    name: 'Carlos Transporte',
    vanCode: 'VAN11223',
    rating: 4.9,
    neighborhoods: ['Jardim Primavera', 'Bela Vista', 'Alto da Serra'],
    whatsapp: '11966666666',
  ),
];

// ---------------------------------------------------------------------------
// Guardian Home Page — 6-tab layout
// ---------------------------------------------------------------------------

class GuardianHomePage extends ConsumerStatefulWidget {
  const GuardianHomePage({super.key});

  @override
  ConsumerState<GuardianHomePage> createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends ConsumerState<GuardianHomePage> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldShowMonthlyEvaluation()) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const MonthlyEvaluationModal(),
        );
      }
    });
  }

  void _logout() {
    ref.read(authNotifierProvider.notifier).logout();
  }

  Future<void> _openWhatsApp(String phone, String name) async {
    final msg =
        Uri.encodeComponent('Olá $name, preciso falar sobre o transporte.');
    final uri = Uri.parse('https://wa.me/55$phone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.text,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rota Escolar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (user != null)
              Text(
                'Olá, ${user.nome.split(' ').first}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Ajuda / FAQ',
            onPressed: () => context.push('/faq'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _StudentTab(onWhatsApp: _openWhatsApp),
          const _VideosTab(),
          const _MapTab(),
          _DriversTab(onWhatsApp: _openWhatsApp),
          const _CommunicationTab(),
          const _RouteReportTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.child_care_outlined),
            activeIcon: Icon(Icons.child_care),
            label: 'Filho',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            activeIcon: Icon(Icons.videocam),
            label: 'Vídeos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_outlined),
            activeIcon: Icon(Icons.directions_bus),
            label: 'Motoristas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Comunicação',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'Relatório',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — Student Cards
// ---------------------------------------------------------------------------

class _StudentTab extends ConsumerWidget {
  final Future<void> Function(String phone, String name) onWhatsApp;

  const _StudentTab({required this.onWhatsApp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guardianHomeProvider);
    final notifier = ref.read(guardianHomeProvider.notifier);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          await Future.delayed(const Duration(milliseconds: 800)),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(Icons.child_care,
                  color: AppColors.primaryDark, size: 18),
              const SizedBox(width: 6),
              Text(
                'Meus filhos',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${state.students.length} aluno(s)',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Cadastrar/Editar Filho button
          OutlinedButton.icon(
            onPressed: () => _showRegisterChildDialog(context, ref, null),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: const Text('Cadastrar / Editar Filho'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 12),
          ...state.students.map<Widget>(
            (student) => _StudentCard(
              student: student,
              onToggleGoToday: () => notifier.toggleGoToday(student.id),
              onToggleTalk: () => notifier.toggleTalkRequest(student.id),
              onWhatsApp: () =>
                  onWhatsApp(student.driverWhatsapp, student.driverName),
              onEdit: () =>
                  _showRegisterChildDialog(context, ref, student),
            ),
          ),
        ],
      ),
    );
  }

  void _showRegisterChildDialog(
      BuildContext context, WidgetRef ref, StudentSummary? existing) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _RegisterChildDialog(existing: existing, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Register / Edit Child Dialog
// ---------------------------------------------------------------------------

class _RegisterChildDialog extends StatefulWidget {
  final StudentSummary? existing;
  final WidgetRef ref;

  const _RegisterChildDialog({required this.existing, required this.ref});

  @override
  State<_RegisterChildDialog> createState() => _RegisterChildDialogState();
}

class _RegisterChildDialogState extends State<_RegisterChildDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _schoolCepCtrl;
  late final TextEditingController _residenceCepCtrl;
  late final TextEditingController _residenceNumberCtrl;
  late final TextEditingController _residenceComplementCtrl;
  late final TextEditingController _vanCodeCtrl;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _schoolCtrl = TextEditingController(text: widget.existing?.school ?? '');
    _residenceCepCtrl =
        TextEditingController(text: widget.existing?.residenceCep ?? '');
    _residenceNumberCtrl = TextEditingController();
    _residenceComplementCtrl = TextEditingController();
    _vanCodeCtrl = TextEditingController();
    _photoUrl = widget.existing?.photoUrl;
  }

  Future<void> _selectAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final studentId = widget.existing?.id ?? uid;

      final dio = Dio();
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'referencia': 'aluno',
        'referencia_id': studentId,
        'tipo': 'perfil',
        'arquivo': MultipartFile.fromBytes(
          bytes,
          filename: 'foto_aluno.jpg',
        ),
      });

      final response = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.uploadFotoCnh}',
        data: formData,
        options: Options(
          headers: token != null
              ? {'Authorization': 'Bearer $token'}
              : {},
        ),
      );

      if (response.data is Map && response.data['success'] == true) {
        final url = response.data['url'] as String?;
        if (url != null && mounted) {
          setState(() => _photoUrl = url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto enviada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _schoolCepCtrl.dispose();
    _residenceCepCtrl.dispose();
    _residenceNumberCtrl.dispose();
    _residenceComplementCtrl.dispose();
    _vanCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(
        isEdit ? 'Editar Filho' : 'Cadastrar Filho',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo placeholder
            GestureDetector(
              onTap: _uploadingPhoto ? null : _selectAndUploadPhoto,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(
                      color: AppColors.primary, width: 2),
                  image: _photoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_photoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _uploadingPhoto
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : _photoUrl == null
                        ? const Icon(Icons.camera_alt,
                            size: 28, color: AppColors.textSecondary)
                        : const Icon(Icons.check_circle,
                            size: 28, color: AppColors.success),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Foto (opcional)',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do aluno *',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolCtrl,
              decoration: const InputDecoration(
                labelText: 'Escola *',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolCepCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'CEP da escola *',
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: '00000-000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _residenceCepCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'CEP da residência *',
                prefixIcon: Icon(Icons.home_outlined),
                hintText: '00000-000',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _residenceNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número *',
                      prefixIcon: Icon(Icons.tag_outlined),
                      hintText: 'Ex: 123',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _residenceComplementCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Complemento',
                      prefixIcon: Icon(Icons.apartment_outlined),
                      hintText: 'Ex: Apto 42',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            TextField(
              controller: _vanCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'VanCode (opcional)',
                prefixIcon: Icon(Icons.directions_bus_outlined),
                hintText: 'Ex: VAN12345',
                helperText:
                    'Preencha para solicitar vaga ao motorista',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty ||
                _schoolCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nome e escola são obrigatórios')),
              );
              return;
            }
            widget.ref
                .read(guardianHomeProvider.notifier)
                .registerChild(
                  name: _nameCtrl.text.trim(),
                  school: _schoolCtrl.text.trim(),
                  residenceCep: _residenceCepCtrl.text.trim(),
                  vanCode: _vanCodeCtrl.text.trim().isEmpty
                      ? null
                      : _vanCodeCtrl.text.trim(),
                  existingId: widget.existing?.id,
                  photoUrl: _photoUrl,
                );
            Navigator.pop(context);
            if (_vanCodeCtrl.text.trim().isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Solicitação enviada ao motorista!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          child: Text(isEdit ? 'Salvar' : 'Cadastrar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Student Card
// ---------------------------------------------------------------------------

class _StudentCard extends StatelessWidget {
  final StudentSummary student;
  final VoidCallback onToggleGoToday;
  final VoidCallback onToggleTalk;
  final VoidCallback onWhatsApp;
  final VoidCallback onEdit;

  const _StudentCard({
    required this.student,
    required this.onToggleGoToday,
    required this.onToggleTalk,
    required this.onWhatsApp,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Card header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  backgroundImage: student.photoUrl != null
                      ? NetworkImage(student.photoUrl!)
                      : null,
                  child: student.photoUrl == null
                      ? Text(
                          student.name[0].toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.text),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        student.school,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.primaryDark),
                  tooltip: 'Editar',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                StatusChip(status: student.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status timeline with times
                _StatusTimeline(
                    status: student.status, stepTimes: student.stepTimes),
                const SizedBox(height: 14),
                if (student.lastUpdateTime != null)
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Última atualização: ${student.lastUpdateTime}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),

                // Vai hoje + Quero falar
                Row(
                  children: [
                    Expanded(
                      child: _ActionToggle(
                        label: student.goToday ? 'Vai hoje' : 'Não vai hoje',
                        icon: student.goToday
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                        active: student.goToday,
                        activeColor: AppColors.success,
                        inactiveColor: AppColors.textSecondary,
                        onTap: onToggleGoToday,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionToggle(
                        label: student.talkRequested
                            ? 'Solicitado'
                            : 'Quero falar',
                        icon: Icons.chat_bubble_outline,
                        active: student.talkRequested,
                        activeColor: AppColors.warning,
                        inactiveColor: AppColors.textSecondary,
                        onTap: onToggleTalk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Payment status + WhatsApp
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: student.ativo
                              ? AppColors.success.withAlpha(20)
                              : AppColors.warning.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: student.ativo
                                ? AppColors.success.withAlpha(80)
                                : AppColors.warning.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              student.ativo
                                  ? Icons.check_circle_outline
                                  : Icons.pending_outlined,
                              size: 16,
                              color: student.ativo
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.cicloEscolar,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    student.ativo
                                        ? 'Ativo ✓'
                                        : 'Inativo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: student.ativo
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: onWhatsApp,
                      icon: SvgPicture.asset(
                        'assets/icons/whatsapp.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                            Colors.white, BlendMode.srcIn),
                      ),
                      label: const Text('Motorista',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),

                // Driver info
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.drive_eta,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      student.driverName,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    const Text('•',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textDisabled)),
                    const SizedBox(width: 6),
                    Text(
                      student.cicloEscolar,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
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

// ---------------------------------------------------------------------------
// Status Timeline — times only on completed/current steps
// ---------------------------------------------------------------------------

class _StatusTimeline extends StatelessWidget {
  final StudentStatus status;
  final List<String>? stepTimes;

  const _StatusTimeline({required this.status, this.stepTimes});

  @override
  Widget build(BuildContext context) {
    final steps = StudentStatus.values;
    final currentIndex = steps.indexOf(status);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        final isDone = i < currentIndex;
        final isCurrent = i == currentIndex;
        // Show time only on completed or current steps (colored dot)
        final showTime = (isDone || isCurrent) &&
            stepTimes != null &&
            i < stepTimes!.length &&
            stepTimes![i].isNotEmpty;
        final timeLabel = showTime ? stepTimes![i] : '';

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone || isCurrent
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      border: Border.all(
                        color: isDone || isCurrent
                            ? AppColors.primary
                            : AppColors.textDisabled,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _iconFor(s),
                      size: 12,
                      color: isDone || isCurrent
                          ? AppColors.text
                          : AppColors.textDisabled,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shortLabel(s),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? AppColors.text
                          : AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: const TextStyle(
                          fontSize: 8, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    )
                  else
                    // Reserve height so layout stays stable
                    const SizedBox(height: 10),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentIndex
                        ? AppColors.primary
                        : AppColors.textDisabled,
                    margin: const EdgeInsets.only(bottom: 30),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(StudentStatus s) => switch (s) {
        StudentStatus.waitingVan => Icons.home,
        StudentStatus.toSchool => Icons.directions_bus,
        StudentStatus.atSchool => Icons.school,
        StudentStatus.toHome => Icons.directions_bus_filled,
        StudentStatus.atHome => Icons.home_filled,
      };

  String _shortLabel(StudentStatus s) => switch (s) {
        StudentStatus.waitingVan => 'Casa',
        StudentStatus.toSchool => 'Rota\nida',
        StudentStatus.atSchool => 'Escola',
        StudentStatus.toHome => 'Rota\nvolta',
        StudentStatus.atHome => 'Casa',
      };
}

// ---------------------------------------------------------------------------
// Action Toggle button
// ---------------------------------------------------------------------------

class _ActionToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _ActionToggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color:
              active ? activeColor.withAlpha(25) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor : AppColors.textDisabled,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: active ? activeColor : inactiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Videos (placeholder)
// ---------------------------------------------------------------------------

class _VideosTab extends StatelessWidget {
  const _VideosTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_outlined,
              size: 72, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'Em breve: vídeos das viagens',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Você poderá assistir gravações\ndas rotas do seu filho.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — GPS Map (placeholder)
// ---------------------------------------------------------------------------

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 72, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'Em breve: localização em tempo real',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Acompanhe onde a van está\ndurante o trajeto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4 — Available Drivers
// ---------------------------------------------------------------------------

class _DriversTab extends StatelessWidget {
  final Future<void> Function(String phone, String name) onWhatsApp;

  const _DriversTab({required this.onWhatsApp});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Motoristas disponíveis na região',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._mockDrivers.map((driver) => _DriverCard(
              driver: driver,
              onWhatsApp: () => onWhatsApp(driver.whatsapp, driver.name),
              onProfile: () => _showDriverProfile(context, driver),
            )),
      ],
    );
  }

  void _showDriverProfile(BuildContext context, _DriverInfo driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DriverProfileSheet(driver: driver),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final _DriverInfo driver;
  final VoidCallback onWhatsApp;
  final VoidCallback onProfile;

  const _DriverCard({
    required this.driver,
    required this.onWhatsApp,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onProfile,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: null,
                child: Text(
                  driver.name[0],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            driver.vanCode,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star,
                            size: 14, color: AppColors.primary),
                        Text(
                          driver.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.neighborhoods.join(' · '),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // WhatsApp button with SVG icon
              IconButton(
                onPressed: onWhatsApp,
                icon: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF25D366), BlendMode.srcIn),
                ),
                tooltip: 'WhatsApp',
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF25D366).withAlpha(20),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverProfileSheet extends StatelessWidget {
  final _DriverInfo driver;

  const _DriverProfileSheet({required this.driver});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textDisabled,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    driver.name[0],
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(driver.vanCode,
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < driver.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Bairros atendidos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: driver.neighborhoods
                  .map((n) => Chip(
                        label:
                            Text(n, style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppColors.primaryLight.withAlpha(80),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('Documentos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Required docs (CNH, CRLV) - show check/cancel
            const _DocRow(
                icon: Icons.credit_card,
                label: 'CNH',
                ok: true,
                optional: false),
            const _DocRow(
                icon: Icons.directions_bus,
                label: 'CRLV',
                ok: true,
                optional: false),
            // Optional docs not sent → neutral/gray, not red
            const _DocRow(
                icon: Icons.account_balance,
                label: 'Autorização Prefeitura',
                ok: false,
                optional: true),
            const _DocRow(
                icon: Icons.shield_outlined,
                label: 'Apólice APP',
                ok: true,
                optional: false),
            const SizedBox(height: 20),
            const Text('Avaliações',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const _ReviewRow(
                comment: 'Muito pontual e cuidadoso com as crianças.',
                stars: 5),
            const _ReviewRow(
                comment:
                    'Ótimo motorista, sempre avisa quando vai atrasar.',
                stars: 4),
          ],
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ok;
  final bool optional;

  const _DocRow({
    required this.icon,
    required this.label,
    required this.ok,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          if (ok)
            const Icon(Icons.check_circle, size: 18, color: AppColors.success)
          else if (optional)
            // Optional not sent → neutral gray
            const Icon(Icons.radio_button_unchecked,
                size: 18, color: AppColors.textDisabled)
          else
            // Required not sent → error red
            const Icon(Icons.cancel, size: 18, color: AppColors.error),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String comment;
  final int stars;

  const _ReviewRow({required this.comment, required this.stars});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(comment,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 5 — Communication Status
// ---------------------------------------------------------------------------

class _CommunicationTab extends ConsumerWidget {
  const _CommunicationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guardianHomeProvider);
    final notifier = ref.read(guardianHomeProvider.notifier);

    final requested = state.students
        .where((s) => s.talkRequested)
        .toList();

    if (requested.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: AppColors.textDisabled),
            SizedBox(height: 12),
            Text(
              'Nenhuma solicitação ativa',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Use o botão "Quero falar" na aba Filho\npara contatar o motorista.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Status de comunicação',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...requested.map((s) {
          final acked = s.talkAcknowledgedByDriver;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(s.name[0],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: acked
                                    ? AppColors.success.withAlpha(30)
                                    : AppColors.warning.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: acked
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                              child: Text(
                                acked ? 'Motorista ciente' : 'Solicitado',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: acked
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!acked)
                    TextButton(
                      onPressed: () =>
                          notifier.simulateDriverAcknowledge(s.id),
                      child: const Text('Simular\nciente',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 6 — Route Report — last 14 days, date on each card
// ---------------------------------------------------------------------------

class _RouteReportTab extends ConsumerWidget {
  const _RouteReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guardianHomeProvider);
    // Generate mock report entries for the last 14 days
    final today = DateTime.now();
    final days = List.generate(14, (i) => today.subtract(Duration(days: i)));
    final fmt = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Relatório de Rotas — últimos 14 dias',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...days.expand((day) => state.students.map((student) =>
            _StudentRouteReport(
              student: student,
              date: fmt.format(day),
              showTimes: day.isBefore(today.add(const Duration(days: 1))),
            ))),
      ],
    );
  }
}

class _StudentRouteReport extends StatelessWidget {
  final StudentSummary student;
  final String date;
  final bool showTimes;

  const _StudentRouteReport({
    required this.student,
    required this.date,
    required this.showTimes,
  });

  List<_RouteEvent> _buildEvents() {
    final times = student.stepTimes;
    return [
      _RouteEvent(
        time: showTimes && times != null && times.length > 1
            ? times[1]
            : '--:--',
        label: 'Embarcou na van',
        icon: Icons.directions_bus,
        color: AppColors.info,
      ),
      _RouteEvent(
        time: showTimes && times != null && times.length > 2
            ? times[2]
            : '--:--',
        label: 'Na escola',
        icon: Icons.school,
        color: AppColors.success,
      ),
      _RouteEvent(
        time: showTimes && times != null && times.length > 3
            ? times[3]
            : '--:--',
        label: 'Embarcou na van (volta)',
        icon: Icons.directions_bus_filled,
        color: AppColors.warning,
      ),
      _RouteEvent(
        time: showTimes && times != null && times.length > 4
            ? times[4]
            : '--:--',
        label: 'Em casa',
        icon: Icons.home_filled,
        color: AppColors.success,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(student.name[0],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryDark)),
                ),
                const SizedBox(width: 8),
                Text(
                  student.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...events.asMap().entries.map((entry) {
              final i = entry.key;
              final event = entry.value;
              final isLast = i == events.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: event.color.withAlpha(30),
                          border:
                              Border.all(color: event.color, width: 2),
                        ),
                        child:
                            Icon(event.icon, size: 16, color: event.color),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 32,
                          color: AppColors.textDisabled,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Text(
                            event.time,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            event.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RouteEvent {
  final String time;
  final String label;
  final IconData icon;
  final Color color;

  const _RouteEvent({
    required this.time,
    required this.label,
    required this.icon,
    required this.color,
  });
}
