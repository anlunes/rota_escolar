import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                '${DateFormat('dd/MM - EEE', 'pt_BR').format(DateTime.now())}  •  ${state.students.length} aluno(s)',
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
            label: const Text('Cadastrar Filho'),
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
              onReactivate: () => notifier.reactivateStudent(student.id),
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
  // Dados básicos
  late final TextEditingController _nameCtrl;
  late final TextEditingController _vanCodeCtrl;
  late final TextEditingController _birthDateCtrl;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  String? _cicloEscolar;
  String? _turno;

  // Endereço residencial
  late final TextEditingController _cepCtrl;
  late final TextEditingController _logradouroCtrl;
  late final TextEditingController _numeroCtrl;
  late final TextEditingController _complementoCtrl;
  late final TextEditingController _bairroCtrl;
  bool _loadingCep = false;

  // Escola
  late final TextEditingController _escolaSearchCtrl;
  int? _escolaId;
  List<Map<String, dynamic>> _escolaSuggestions = [];
  bool _loadingEscolas = false;

  static const _ciclos = ['Infantil', 'Fundamental I', 'Fundamental II', 'Médio'];
  static const _turnos = [('manha', 'Manhã'), ('tarde', 'Tarde')];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl        = TextEditingController(text: e?.name ?? '');
    _vanCodeCtrl     = TextEditingController(text: e?.vanCode ?? '');
    _birthDateCtrl   = TextEditingController(text: _isoToDisplay(e?.dataNascimento ?? ''));
    _cepCtrl         = TextEditingController(text: e?.residenceCep ?? '');
    _logradouroCtrl  = TextEditingController(text: e?.logradouro ?? '');
    _numeroCtrl      = TextEditingController(text: e?.numero ?? '');
    _complementoCtrl = TextEditingController(text: e?.complemento ?? '');
    _bairroCtrl      = TextEditingController(text: e?.bairro ?? '');
    _escolaSearchCtrl = TextEditingController(text: e?.school ?? '');
    _cicloEscolar    = (e?.cicloEscolar == 'A definir' || e?.cicloEscolar == '') ? null : e?.cicloEscolar;
    _turno           = (e?.turno == '') ? null : e?.turno;
    _photoUrl        = e?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vanCodeCtrl.dispose();
    _birthDateCtrl.dispose();
    _cepCtrl.dispose();
    _logradouroCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _bairroCtrl.dispose();
    _escolaSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCep() async {
    final cep = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;
    setState(() => _loadingCep = true);
    try {
      final dio = Dio();
      final res = await dio.get('https://viacep.com.br/ws/$cep/json/');
      if (res.data is Map && res.data['erro'] != true) {
        setState(() {
          _logradouroCtrl.text = res.data['logradouro'] ?? '';
          _bairroCtrl.text    = res.data['bairro']     ?? '';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingCep = false);
    }
  }

  Future<void> _searchEscolas(String query) async {
    if (query.length < 2) {
      setState(() { _escolaSuggestions = []; _escolaId = null; });
      return;
    }
    setState(() => _loadingEscolas = true);
    try {
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.locationEscolas}',
        queryParameters: {'q': query},
      );
      if (res.data is Map && res.data['success'] == true) {
        setState(() {
          _escolaSuggestions = List<Map<String, dynamic>>.from(res.data['data']);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingEscolas = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aluno'),
        content: Text('Deseja remover ${widget.existing!.name} da sua lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context); // fecha o dialog de edição
    widget.ref.read(guardianHomeProvider.notifier).deleteStudent(
      widget.existing!.id,
      onError: (msg) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error),
          );
        }
      },
    );
  }

  /// Converte "dd/mm/aaaa" → "aaaa-mm-dd" para o banco. Retorna null se incompleto.
  String? _parseDateToISO(String text) {
    final parts = text.split('/');
    if (parts.length != 3 || parts[2].length != 4) return null;
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  /// Converte "aaaa-mm-dd" (banco) → "dd/mm/aaaa" (display). Retorna '' se vazio.
  String _isoToDisplay(String iso) {
    if (iso.isEmpty) return '';
    final parts = iso.split('-');
    if (parts.length != 3) return '';
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<void> _selectAndUploadPhoto() async {
    if (_uploadingPhoto) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final uid   = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final studentId = widget.existing?.id ?? uid;
      final dio = Dio();
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'referencia': 'aluno',
        'referencia_id': studentId,
        'tipo': 'perfil',
        'arquivo': MultipartFile.fromBytes(bytes, filename: 'foto_aluno.jpg'),
      });
      final response = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.uploadFotoCnh}',
        data: formData,
        options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
      );
      if (response.data is Map && response.data['success'] == true) {
        final url = response.data['url'] as String?;
        if (url != null && mounted) setState(() => _photoUrl = url);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do aluno é obrigatório')),
      );
      return;
    }
    if (_escolaId == null && _escolaSearchCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma escola')),
      );
      return;
    }
    final van = _vanCodeCtrl.text.trim();
    final ctx = context;

    widget.ref.read(guardianHomeProvider.notifier).registerChild(
      name: name,
      school: _escolaSearchCtrl.text.trim(),
      escolaId: _escolaId,
      residenceCep: _cepCtrl.text.trim(),
      logradouro: _logradouroCtrl.text.trim(),
      numero: _numeroCtrl.text.trim(),
      complemento: _complementoCtrl.text.trim(),
      bairro: _bairroCtrl.text.trim(),
      cicloEscolar: _cicloEscolar,
      turno: _turno,
      dataNascimento: _parseDateToISO(_birthDateCtrl.text),
      vanCode: van.isEmpty ? null : van,
      existingId: widget.existing?.id,
      photoUrl: _photoUrl,
      onError: (msg) {
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Erro ao salvar: $msg'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
    Navigator.pop(context);
    if (van.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação enviada ao motorista!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Editar Filho' : 'Cadastrar Filho',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  if (isEdit && widget.existing!.ativo)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                      tooltip: 'Excluir aluno',
                      onPressed: () => _confirmDelete(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (isEdit && !widget.existing!.ativo)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.ref.read(guardianHomeProvider.notifier)
                            .reactivateStudent(widget.existing!.id);
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Reativar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.success),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Foto ────────────────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _uploadingPhoto ? null : _selectAndUploadPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.surfaceVariant,
                              backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                              child: _uploadingPhoto
                                  ? const CircularProgressIndicator(strokeWidth: 2)
                                  : _photoUrl == null
                                      ? const Icon(Icons.camera_alt, size: 28, color: AppColors.textSecondary)
                                      : null,
                            ),
                            if (_photoUrl != null)
                              const Positioned(
                                bottom: 0, right: 0,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: AppColors.success,
                                  child: Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('Foto (opcional)',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 20),

                    // ── Dados básicos ────────────────────────────────────────
                    _SectionLabel('Dados do aluno'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Data de nascimento
                    TextField(
                      controller: _birthDateCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_DateInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Data de nascimento',
                        prefixIcon: Icon(Icons.cake_outlined),
                        hintText: 'dd/mm/aaaa',
                        counterText: '',
                      ),
                      maxLength: 10,
                    ),
                    const SizedBox(height: 12),
                    // Ciclo escolar
                    DropdownButtonFormField<String>(
                      value: _cicloEscolar,
                      decoration: const InputDecoration(
                        labelText: 'Nível de ensino *',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: _ciclos.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _cicloEscolar = v),
                    ),
                    const SizedBox(height: 12),
                    // Turno
                    DropdownButtonFormField<String>(
                      value: _turno,
                      decoration: const InputDecoration(
                        labelText: 'Turno *',
                        prefixIcon: Icon(Icons.wb_sunny_outlined),
                      ),
                      items: _turnos.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                      onChanged: (v) => setState(() => _turno = v),
                    ),
                    const SizedBox(height: 20),

                    // ── Endereço residencial ──────────────────────────────────
                    _SectionLabel('Endereço residencial'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cepCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'CEP *',
                              prefixIcon: const Icon(Icons.location_on_outlined),
                              hintText: '00000-000',
                              suffixIcon: _loadingCep
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search, size: 18),
                                      onPressed: _lookupCep,
                                      tooltip: 'Buscar CEP',
                                    ),
                            ),
                            onChanged: (v) {
                              if (v.replaceAll(RegExp(r'\D'), '').length == 8) _lookupCep();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _logradouroCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Logradouro',
                        prefixIcon: Icon(Icons.signpost_outlined),
                        hintText: 'Preenchido pelo CEP',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _numeroCtrl,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Número *',
                              hintText: '123',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _complementoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Complemento',
                              hintText: 'Apto 42',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bairroCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        prefixIcon: Icon(Icons.map_outlined),
                        hintText: 'Preenchido pelo CEP',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Escola ───────────────────────────────────────────────
                    _SectionLabel('Escola'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _escolaSearchCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Buscar escola *',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _loadingEscolas
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _escolaId != null
                                ? const Icon(Icons.check_circle, color: AppColors.success)
                                : null,
                        hintText: 'Digite o nome da escola...',
                      ),
                      onChanged: (v) {
                        setState(() => _escolaId = null);
                        _searchEscolas(v);
                      },
                    ),
                    if (_escolaSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.surfaceVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: _escolaSuggestions.map((e) {
                            final bairro = e['bairro']?.toString() ?? '';
                            final sub = bairro.isNotEmpty ? bairro : '';
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.school_outlined, size: 18),
                              title: Text(e['nome'].toString(), style: const TextStyle(fontSize: 13)),
                              subtitle: sub.isNotEmpty ? Text(sub, style: const TextStyle(fontSize: 11)) : null,
                              onTap: () {
                                setState(() {
                                  _escolaId = (e['id'] as num).toInt();
                                  _escolaSearchCtrl.text = e['nome'].toString();
                                  _escolaSuggestions = [];
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // ── VanCode ──────────────────────────────────────────────
                    _SectionLabel('Motorista'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _vanCodeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'VanCode (opcional)',
                        prefixIcon: Icon(Icons.directions_bus_outlined),
                        hintText: 'Ex: RJ001001',
                        helperText: 'Preencha para solicitar vaga ao motorista',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Botão salvar ─────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(
                          isEdit ? 'Salvar alterações' : 'Cadastrar',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
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
  final VoidCallback onReactivate;

  const _StudentCard({
    required this.student,
    required this.onToggleGoToday,
    required this.onToggleTalk,
    required this.onWhatsApp,
    required this.onEdit,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    // Card inativo — exibe simplificado com botão reativar
    if (!student.ativo) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.textDisabled.withAlpha(60),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.textDisabled, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.lineThrough)),
                    const Text('Removido', style: TextStyle(fontSize: 11, color: AppColors.textDisabled)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onReactivate,
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Reativar', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AppColors.success),
              ),
            ],
          ),
        ),
      );
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  backgroundImage: student.photoUrl != null
                      ? NetworkImage(student.photoUrl!)
                      : null,
                  child: student.photoUrl == null
                      ? Text(
                          student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          if (student.cicloEscolar.isNotEmpty &&
                              student.cicloEscolar != 'A definir')
                            Text(
                              student.cicloEscolar,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Editar',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Banner: aguardando motorista aceitar
          if (student.awaitingDriverAccept)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                border: Border(
                  bottom: BorderSide(
                      color: AppColors.warning.withAlpha(80), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Aguardando motorista aceitar a vaga',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  Text(
                    'Van: ${student.vanCode}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.warning.withAlpha(180),
                    ),
                  ),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    StatusChip(status: student.status),
                    const Spacer(),
                    if (student.lastUpdateTime != null) ...[
                      const Icon(Icons.access_time,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        student.lastUpdateTime!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
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
                        onTap: () => _showTalkSheet(
                          context,
                          student.driverName,
                          student.driverWhatsapp,
                          onToggleTalk,
                          onWhatsApp,
                        ),
                      ),
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

  void _showTalkSheet(
    BuildContext context,
    String driverName,
    String driverWhatsapp,
    VoidCallback onLeaveRequest,
    VoidCallback onWhatsApp,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              driverName.isNotEmpty
                  ? 'Falar com o Motorista $driverName'
                  : 'Falar com o Motorista',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withAlpha(80)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'O motorista não pode responder enquanto estiver dirigindo. '
                      'Assim que puder, ele entrará em contato pelo WhatsApp.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLeaveRequest();
                },
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Deixar chamado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onWhatsApp();
                },
                icon: SvgPicture.asset(
                  'assets/icons/whatsapp.svg',
                  width: 18, height: 18,
                  colorFilter: const ColorFilter.mode(
                      Color(0xFF25D366), BlendMode.srcIn),
                ),
                label: const Text('WhatsApp — apenas se urgente'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                  side: const BorderSide(color: Color(0xFF25D366)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
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

    final List<Widget> items = [];
    for (int i = 0; i < steps.length; i++) {
      final s = steps[i];
      final isDone = i < currentIndex;
      final isCurrent = i == currentIndex;
      final showTime = (isDone || isCurrent) &&
          stepTimes != null &&
          i < stepTimes!.length &&
          stepTimes![i].isNotEmpty;
      final timeLabel = showTime ? stepTimes![i] : '';

      // Círculo + label
      items.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
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
                size: 18,
                color: isDone || isCurrent
                    ? AppColors.text
                    : AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _shortLabel(s),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? AppColors.text : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            if (timeLabel.isNotEmpty)
              Text(
                timeLabel,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              )
            else
              const SizedBox(height: 12),
          ],
        ),
      );

      // Conector entre círculos
      if (i < steps.length - 1) {
        items.add(
          Expanded(
            child: Container(
              height: 2,
              color: i < currentIndex
                  ? AppColors.primary
                  : AppColors.textDisabled,
              margin: const EdgeInsets.only(bottom: 38),
            ),
          ),
        );
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
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
                  child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
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

// ---------------------------------------------------------------------------
// Formatador de data dd/mm/aaaa com inserção automática de "/"
// ---------------------------------------------------------------------------

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Só dígitos
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }

    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
