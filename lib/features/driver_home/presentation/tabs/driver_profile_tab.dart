import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/domain/models/bairro.dart';
import '../../../location/domain/models/escola.dart';
import '../../../location/domain/models/estado.dart';
import '../../../location/domain/models/municipio.dart';
import '../../../location/presentation/widgets/bairro_selector.dart';
import '../../../location/presentation/widgets/escola_selector.dart';

class DriverProfileTab extends StatefulWidget {
  const DriverProfileTab({super.key});

  @override
  State<DriverProfileTab> createState() => _DriverProfileTabState();
}

class _DriverProfileTabState extends State<DriverProfileTab> {
  bool _editingLocation = false;
  List<int> _selectedBairroIds = [];
  List<String> _bairroNomes = [];
  List<Bairro> _bairrosCompletos = [];
  int? _prefEstadoId;
  int? _prefMunicipioId;
  String? _prefEstadoNome;
  String? _prefMunicipioNome;

  List<int> _selectedEscolaIds = [];
  List<String> _escolaNomes = [];
  List<String> _escolasPendentesNomes = [];
  bool _editingEscolas = false;
  bool _savingProfile = false;

  // Track which documents are uploaded
  final Map<String, bool> _uploadedDocs = {
    'cnh': false,
    'crlv': false,
    'autorizacao': false,
    'app': false,
    'perfil': false,
  };

  // Store document URLs for display
  final Map<String, String> _documentUrls = {
    'cnh': '',
    'crlv': '',
    'autorizacao': '',
    'app': '',
    'perfil': '',
  };

  bool _uploadingDoc = false;
  bool _loadingProfile = false;
  int _perfilCacheBust = 0;
  bool _editingDadosPessoais = false;
  bool _isLoadingCep = false;
  String? _cepError;

  String? _veiculoPlaca;
  String? _veiculoModelo;
  String? _vanCode;
  String? _whatsapp;
  int _alunosAtivos = 0;
  int _motoristaId = 0;
  double _rating = 0;
  int _ratingCount = 0;
  int _vagasVan = 0;
  int _alunosManha = 0;
  int _alunosTarde = 0;
  final TextEditingController _whatsappController      = TextEditingController();
  final TextEditingController _vagasVanController      = TextEditingController();
  final TextEditingController _precoKmController       = TextEditingController();
  final TextEditingController _valorServicoController  = TextEditingController();
  final TextEditingController _cpfController           = TextEditingController();
  final TextEditingController _cepController           = TextEditingController();
  final TextEditingController _logradouroController    = TextEditingController();
  final TextEditingController _numeroController        = TextEditingController();
  final TextEditingController _complementoController   = TextEditingController();
  final TextEditingController _bairroNomeController    = TextEditingController();
  final TextEditingController _cidadeController        = TextEditingController();
  final TextEditingController _estadoUfController      = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDriverProfile();
    _loadDriverBairros();
    _loadDriverEscolas();
  }

  Future<void> _loadDriverProfile() async {
    setState(() => _loadingProfile = true);
    try {
      final dio = Dio();
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.driversProfile}',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );

      if (response.data is Map && response.data['success'] == true) {
        final driver = response.data['data'] ?? response.data;
        if (mounted) {
          setState(() {
            // Check if documents are uploaded based on URL fields
            _uploadedDocs['cnh']        = driver['cnh_url']          != null && driver['cnh_url'].toString().isNotEmpty;
            _uploadedDocs['crlv']       = driver['crlv_url']         != null && driver['crlv_url'].toString().isNotEmpty;
            _uploadedDocs['perfil']     = driver['foto_url']         != null && driver['foto_url'].toString().isNotEmpty;
            _uploadedDocs['app']        = driver['seguro_url']       != null && driver['seguro_url'].toString().isNotEmpty;
            _uploadedDocs['autorizacao'] = driver['autorizacao_url'] != null && driver['autorizacao_url'].toString().isNotEmpty;

            // Store URLs for display
            _documentUrls['cnh']        = driver['cnh_url']          ?? '';
            _documentUrls['crlv']       = driver['crlv_url']         ?? '';
            _documentUrls['perfil']     = driver['foto_url']         ?? '';
            _documentUrls['app']        = driver['seguro_url']       ?? '';
            _documentUrls['autorizacao'] = driver['autorizacao_url'] ?? '';

            // Dados do veículo extraídos do CRLV
            _veiculoPlaca  = driver['veiculo_placa']  ?? null;
            _veiculoModelo = driver['veiculo_modelo'] ?? null;

            _motoristaId = int.tryParse(driver['motorista_id']?.toString() ?? '0') ?? 0;

            final avaliacoes = driver['avaliacoes'] as Map?;
            _rating      = (avaliacoes?['rating'] as num?)?.toDouble() ?? 0;
            _ratingCount = (avaliacoes?['count']  as num?)?.toInt()    ?? 0;

            // Cache bust da foto de perfil baseado no updated_at do banco
            if ((driver['foto_url'] ?? '').isNotEmpty) {
              final updatedAt = driver['updated_at']?.toString() ?? '';
              _perfilCacheBust = updatedAt.isNotEmpty
                  ? updatedAt.hashCode.abs()
                  : DateTime.now().millisecondsSinceEpoch;
            }
          });
        }
      }
    } catch (e) {
      // Silently fail - keep default false values
      debugPrint('Error loading driver profile: $e');
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _vagasVanController.dispose();
    _precoKmController.dispose();
    _valorServicoController.dispose();
    _cpfController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroNomeController.dispose();
    _cidadeController.dispose();
    _estadoUfController.dispose();
    super.dispose();
  }

  Future<void> _uploadDocument(String tipo) async {
    if (_uploadingDoc) return;

    // Mostra opções de origem do arquivo
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Selecionar PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (escolha == null) return;

    late final List<int> bytes;
    late final String filename;
    late final String contentType;

    if (escolha == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;
      bytes = result.files.single.bytes!;
      filename = '$tipo.pdf';
      contentType = 'application/pdf';
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: escolha == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
      filename = '$tipo.jpg';
      contentType = 'image/jpeg';
    }

    setState(() => _uploadingDoc = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      final dio = Dio();
      final formData = FormData.fromMap({
        'referencia': 'motorista',
        'referencia_id': uid,
        'tipo': tipo,
        'arquivo': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(contentType),
        ),
      });

      final endpoint = tipo == 'crlv'
          ? ApiConstants.uploadFotoCrlv
          : ApiConstants.uploadFoto;

      final response = await dio.post(
        '${ApiConstants.baseUrl}$endpoint',
        data: formData,
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );

      if (response.data is Map && response.data['success'] == true) {
        if (mounted) {
          setState(() {
            _uploadedDocs[tipo] = true;
            _documentUrls[tipo] = response.data['url'] ?? '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento enviado com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  void _viewDocument(String tipo) {
    final url = _documentUrls[tipo] ?? '';
    if (url.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadProfilePhoto() async {
    if (_uploadingDoc) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _uploadingDoc = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      final dio = Dio();
      final bytes = await picked.readAsBytes();
      final formData = FormData.fromMap({
        'referencia': 'motorista',
        'referencia_id': uid,
        'tipo': 'perfil',
        'arquivo': MultipartFile.fromBytes(
          bytes,
          filename: 'perfil.jpg',
        ),
      });

      await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.uploadFoto}',
        data: formData,
        options: Options(
          headers: token != null
              ? {'Authorization': 'Bearer $token'}
              : {},
        ),
      );

      if (mounted) {
        setState(() {
          _uploadedDocs['perfil'] = true;
          _documentUrls['perfil'] = '${ApiConstants.baseUrl}/uploads/motoristas/$uid/perfil.webp';
          _perfilCacheBust = DateTime.now().millisecondsSinceEpoch;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada!'),
            backgroundColor: AppColors.success,
          ),
        );
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
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  void _showMessage(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _loadDriverBairros() async {
    try {
      final dio = Dio();
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.driverBairros}',
        options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
      );
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final bairros = data['bairros'] as List;
        final estadoId    = data['estado_id']    != null ? (data['estado_id']    as num).toInt() : null;
        final municipioId = data['municipio_id'] != null ? (data['municipio_id'] as num).toInt() : null;
        if (mounted) {
          setState(() {
            _selectedBairroIds = bairros.map<int>((b) => b['id'] as int).toList();
            _bairroNomes       = bairros.map<String>((b) => (b['nome'] ?? '') as String).toList();
            _bairrosCompletos  = bairros.map<Bairro>((b) => Bairro(
              id: b['id'] as int,
              nome: (b['nome'] ?? '') as String,
            )).toList();
            _prefEstadoId      = estadoId;
            _prefMunicipioId   = municipioId;
            _vanCode      = data['van_code'];
            _whatsapp     = data['whatsapp'];
            _cpfController.text          = (data['cpf']         as String?) ?? '';
            _cepController.text          = (data['cep']         as String?) ?? '';
            _logradouroController.text   = (data['logradouro']  as String?) ?? '';
            _numeroController.text       = (data['numero']      as String?) ?? '';
            _complementoController.text  = (data['complemento'] as String?) ?? '';
            _bairroNomeController.text   = (data['bairro_nome'] as String?) ?? '';
            _cidadeController.text       = (data['cidade']      as String?) ?? '';
            _estadoUfController.text     = (data['estado_uf']   as String?) ?? '';
            _alunosAtivos = int.tryParse(data['alunos_ativos']?.toString() ?? '0') ?? 0;
            _alunosManha = int.tryParse(data['alunos_manha']?.toString() ?? '0') ?? 0;
            _alunosTarde = int.tryParse(data['alunos_tarde']?.toString() ?? '0') ?? 0;
            _vagasVan    = int.tryParse(data['vagas_van']?.toString()    ?? '0') ?? 0;
            _vagasVanController.text = _vagasVan > 0 ? '$_vagasVan' : '';
            final precoKm = double.tryParse(data['preco_km']?.toString() ?? '');
            _precoKmController.text  = precoKm != null && precoKm > 0
                ? precoKm.toStringAsFixed(2)
                : '';
            final valorServico = double.tryParse(data['valor_servico']?.toString() ?? '');
            _valorServicoController.text = valorServico != null && valorServico > 0
                ? valorServico.toStringAsFixed(2)
                : '';
            final whatsappDb       = (data['whatsapp']           as String?) ?? '';
            final telefoneCadastro = (data['telefone_cadastro']  as String?) ?? '';
            _whatsappController.text = whatsappDb.isNotEmpty
                ? whatsappDb
                : telefoneCadastro;
          });
        }
        if (estadoId != null) {
          _fetchLocationNames(estadoId, municipioId);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar bairros do motorista: $e');
    }
  }

  Future<void> _fetchLocationNames(int estadoId, int? municipioId) async {
    try {
      final repo = LocationRepository();
      final estados = await repo.fetchEstados();
      final estado = estados.firstWhere(
        (e) => e.id == estadoId,
        orElse: () => Estado(id: 0, uf: '', nome: ''),
      );
      if (estado.id != 0 && mounted) {
        setState(() => _prefEstadoNome = '${estado.uf} - ${estado.nome}');
      }
      if (municipioId != null) {
        final municipios = await repo.fetchMunicipios(estadoId);
        final municipio = municipios.firstWhere(
          (m) => m.id == municipioId,
          orElse: () => Municipio(id: 0, nome: ''),
        );
        if (municipio.id != 0 && mounted) {
          setState(() => _prefMunicipioNome = municipio.nome);
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar nomes de localização: $e');
    }
  }

  Future<void> _lookupCep(String value) async {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return;
    setState(() { _isLoadingCep = true; _cepError = null; });
    try {
      final response = await Dio().get('https://viacep.com.br/ws/$digits/json/');
      final data = response.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepError = 'CEP não encontrado.');
        return;
      }
      setState(() {
        _logradouroController.text = data['logradouro'] ?? '';
        _bairroNomeController.text = data['bairro']     ?? '';
        _cidadeController.text     = data['localidade'] ?? '';
        _estadoUfController.text   = data['uf']         ?? '';
      });
    } catch (_) {
      setState(() => _cepError = 'Não foi possível consultar o CEP.');
    } finally {
      if (mounted) setState(() => _isLoadingCep = false);
    }
  }

  String _maskCpf(String cpf) {
    final d = cpf.replaceAll(RegExp(r'\D'), '');
    if (d.length != 11) return cpf.isEmpty ? 'Não informado' : cpf;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9, 11)}';
  }

  String get _enderecoDisplay {
    final parts = <String>[
      if (_logradouroController.text.isNotEmpty) _logradouroController.text,
      if (_numeroController.text.isNotEmpty)     _numeroController.text,
      if (_complementoController.text.isNotEmpty) _complementoController.text,
      if (_bairroNomeController.text.isNotEmpty) _bairroNomeController.text,
      if (_cidadeController.text.isNotEmpty)
        '${_cidadeController.text}${_estadoUfController.text.isNotEmpty ? '/${_estadoUfController.text}' : ''}',
    ];
    return parts.isEmpty ? 'Não informado' : parts.join(', ');
  }

  Future<void> _saveBairros() async {
    final dio = Dio();
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.driverBairros}',
      data: {
        'bairro_ids':    _selectedBairroIds,
        'estado_id':     _prefEstadoId,
        'municipio_id':  _prefMunicipioId,
        'whatsapp':      _whatsappController.text.trim(),
        'vagas_van':     int.tryParse(_vagasVanController.text.trim()) ?? 0,
        'preco_km':      double.tryParse(_precoKmController.text.trim().replaceAll(',', '.')) ?? 0,
        'valor_servico': double.tryParse(_valorServicoController.text.trim().replaceAll(',', '.')) ?? 0,
        'cpf':           _cpfController.text.replaceAll(RegExp(r'\D'), ''),
        'cep':           _cepController.text.replaceAll(RegExp(r'\D'), ''),
        'logradouro':    _logradouroController.text.trim(),
        'numero':        _numeroController.text.trim(),
        'complemento':   _complementoController.text.trim(),
        'bairro_nome':   _bairroNomeController.text.trim(),
        'cidade':        _cidadeController.text.trim(),
        'estado_uf':     _estadoUfController.text.trim(),
      },
      options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
    );
    if (response.data is Map && response.data['success'] == true) {
      final code = response.data['data']?['van_code'];
      if (code != null && mounted) setState(() => _vanCode = code);
    }
  }

  Future<void> _loadDriverEscolas() async {
    try {
      final dio = Dio();
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.driverEscolas}',
        options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
      );
      if (response.data['success'] == true) {
        final escolas = response.data['data'] as List;
        if (mounted) {
          setState(() {
            _selectedEscolaIds = escolas.map<int>((e) => e['id'] as int).toList();
            _escolaNomes       = escolas.map<String>((e) => (e['nome'] ?? '') as String).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar escolas do motorista: $e');
    }
  }

  Future<void> _saveEscolas() async {
    final dio = Dio();
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    await dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.driverEscolas}',
      data: {'escola_ids': _selectedEscolaIds},
      options: Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {}),
    );
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      await _saveBairros();
      await _saveEscolas();
      // Futuramente: await _savePersonalInfo(); await _saveVehicleInfo(); etc.
      await _loadDriverEscolas();
      if (mounted) {
        setState(() {
          _editingLocation = false;
          _editingEscolas  = false;
        });
        _showMessage('Perfil atualizado com sucesso!');
      }
    } catch (e) {
      _showMessage('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _showMyReviews(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MyReviewsSheet(motoristaId: _motoristaId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Avatar
              Stack(
                children: [
                  GestureDetector(
                    onTap: _documentUrls['perfil']!.isNotEmpty
                        ? () => _viewDocument('perfil')
                        : null,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.surfaceVariant,
                      child: ClipOval(
                        child: _documentUrls['perfil']!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: '${_documentUrls['perfil']}?v=$_perfilCacheBust',
                                width: 104,
                                height: 104,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const CircularProgressIndicator(),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 52,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : const Icon(Icons.person,
                                size: 52, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploadProfilePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                FirebaseAuth.instance.currentUser?.displayName ?? 'Motorista',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                FirebaseAuth.instance.currentUser?.email ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // ── Dados Pessoais ─────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _SectionHeader(title: 'Dados Pessoais')),
                  IconButton(
                    onPressed: () => setState(() => _editingDadosPessoais = !_editingDadosPessoais),
                    icon: Icon(
                      _editingDadosPessoais ? Icons.close : Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    tooltip: _editingDadosPessoais ? 'Cancelar' : 'Editar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editingDadosPessoais) ...[
                TextField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CpfFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cepController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CepFormatter()],
                  onChanged: _lookupCep,
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: _isLoadingCep
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    errorText: _cepError,
                  ),
                ),
                const SizedBox(height: 10),
                _EditableField(
                  label: 'Logradouro',
                  controller: _logradouroController,
                  icon: Icons.edit_road_outlined,
                  enabled: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: _EditableField(
                        label: 'Número',
                        controller: _numeroController,
                        icon: Icons.tag_outlined,
                        enabled: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _EditableField(
                        label: 'Complemento',
                        controller: _complementoController,
                        icon: Icons.info_outline,
                        enabled: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _EditableField(
                  label: 'Bairro',
                  controller: _bairroNomeController,
                  icon: Icons.holiday_village_outlined,
                  enabled: false,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _EditableField(
                        label: 'Cidade',
                        controller: _cidadeController,
                        icon: Icons.location_city_outlined,
                        enabled: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 72,
                      child: _EditableField(
                        label: 'UF',
                        controller: _estadoUfController,
                        icon: Icons.map_outlined,
                        enabled: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ] else ...[
                _EditableField(
                  label: 'CPF',
                  controller: TextEditingController(text: _maskCpf(_cpfController.text)),
                  icon: Icons.badge_outlined,
                  enabled: false,
                ),
                const SizedBox(height: 8),
                _EditableField(
                  label: 'Endereço',
                  controller: TextEditingController(text: _enderecoDisplay),
                  icon: Icons.home_outlined,
                  enabled: false,
                ),
              ],
              const SizedBox(height: 20),

              // Location fields
              Row(
                children: [
                  Expanded(child: _SectionHeader(title: 'Localização / Atendimento')),
                  IconButton(
                    onPressed: () => setState(() => _editingLocation = !_editingLocation),
                    icon: Icon(
                      _editingLocation ? Icons.close : Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    tooltip: _editingLocation ? 'Cancelar' : 'Editar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editingLocation) ...[
                BairroSelector(
                  selectedBairroIds: _selectedBairroIds,
                  initialEstadoId: _prefEstadoId,
                  initialMunicipioId: _prefMunicipioId,
                  onSelectionChanged: (ids) => setState(() => _selectedBairroIds = ids),
                  onLocationChanged: (estadoId, municipioId) => setState(() {
                    _prefEstadoId    = estadoId;
                    _prefMunicipioId = municipioId;
                  }),
                ),
                const SizedBox(height: 10),
              ] else ...[
                if (_prefEstadoNome != null) ...[
                  _EditableField(
                    label: 'Estado',
                    controller: TextEditingController(text: _prefEstadoNome!),
                    icon: Icons.map_outlined,
                    enabled: false,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_prefMunicipioNome != null) ...[
                  _EditableField(
                    label: 'Município',
                    controller: TextEditingController(text: _prefMunicipioNome!),
                    icon: Icons.location_city_outlined,
                    enabled: false,
                  ),
                  const SizedBox(height: 8),
                ],
                if (_selectedBairroIds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhum bairro selecionado.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  _EditableField(
                    label: 'Bairros que atende',
                    controller: TextEditingController(
                        text: _bairroNomes.isNotEmpty
                            ? _bairroNomes.join(', ')
                            : '${_selectedBairroIds.length} bairro(s)'),
                    icon: Icons.grid_view_outlined,
                    enabled: false,
                    hint: 'Ex: Jardim Primavera, Centro',
                  ),
              ],
              const SizedBox(height: 20),

              // Escolas
              Row(
                children: [
                  Expanded(child: _SectionHeader(title: 'Escolas que Atende')),
                  IconButton(
                    onPressed: () => setState(() => _editingEscolas = !_editingEscolas),
                    icon: Icon(
                      _editingEscolas ? Icons.close : Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    tooltip: _editingEscolas ? 'Cancelar' : 'Editar',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_editingEscolas) ...[
                EscolaSelector(
                  selectedEscolaIds: _selectedEscolaIds,
                  bairrosDoMotorista: _bairrosCompletos,
                  onSelectionChanged: (ids) => setState(() => _selectedEscolaIds = ids),
                  onPendingAdded: (nome) => setState(() => _escolasPendentesNomes.add(nome)),
                ),
                const SizedBox(height: 10),
              ] else ...[
                if (_escolaNomes.isEmpty && _escolasPendentesNomes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nenhuma escola selecionada.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else ...[
                  if (_escolaNomes.isNotEmpty)
                    _EditableField(
                      label: 'Escolas que atende',
                      controller: TextEditingController(text: _escolaNomes.join(', ')),
                      icon: Icons.school_outlined,
                      enabled: false,
                    ),
                  if (_escolasPendentesNomes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _escolasPendentesNomes
                          .map((nome) => Chip(
                                label: Text(nome,
                                    style: const TextStyle(fontSize: 13)),
                                backgroundColor: Colors.orange.shade100,
                                avatar: const Icon(Icons.access_time,
                                    size: 14, color: Colors.orange),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 4),
                    const Text('Aguardando aprovação do administrador.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ],
              ],
              const SizedBox(height: 24),

              // Required documents
              _SectionHeader(title: 'Documentos Obrigatórios'),
              const SizedBox(height: 10),
              _DocumentCard(
                title: 'CNH',
                subtitle: 'Carteira Nacional de Habilitação',
                icon: Icons.credit_card,
                uploaded: _uploadedDocs['cnh']!,
                onTap: () => _uploadDocument('cnh'),
                onViewTap: _uploadedDocs['cnh']! ? () => _viewDocument('cnh') : null,
              ),
              const SizedBox(height: 10),
              _DocumentCard(
                title: 'CRLV',
                subtitle: 'Certificado de Registro e Licenciamento',
                icon: Icons.directions_bus,
                uploaded: _uploadedDocs['crlv']!,
                onTap: () => _uploadDocument('crlv'),
                onViewTap: _uploadedDocs['crlv']! ? () => _viewDocument('crlv') : null,
              ),
              const SizedBox(height: 20),

              // Optional documents
              _SectionHeader(title: 'Documentos Opcionais'),
              const SizedBox(height: 10),
              _DocumentCard(
                title: 'Autorização Prefeitura',
                subtitle: 'Alvará de transporte escolar municipal',
                icon: Icons.account_balance,
                uploaded: _uploadedDocs['autorizacao']!,
                onTap: () => _uploadDocument('autorizacao'),
                onViewTap: _uploadedDocs['autorizacao']! ? () => _viewDocument('autorizacao') : null,
                optional: true,
              ),
              const SizedBox(height: 10),
              _DocumentCard(
                title: 'Apólice APP',
                subtitle: 'Seguro de Acidentes Pessoais de Passageiros',
                icon: Icons.shield_outlined,
                uploaded: _uploadedDocs['app']!,
                onTap: () => _uploadDocument('app'),
                onViewTap: _uploadedDocs['app']! ? () => _viewDocument('app') : null,
                optional: true,
              ),
              const SizedBox(height: 24),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                    label: 'Van',
                    value: (_veiculoModelo != null || _veiculoPlaca != null)
                        ? [
                            if (_veiculoModelo != null) _veiculoModelo!,
                            if (_veiculoPlaca  != null) _veiculoPlaca!,
                          ].join(' — ')
                        : 'Não informado',
                  ),
                      const Divider(height: 20),
                      _InfoRow(
                        label: 'Alunos ativos',
                        value: _alunosAtivos > 0 ? '$_alunosAtivos' : '—',
                      ),
                      const Divider(height: 20),
                      // Capacidade total da van
                      Row(
                        children: [
                          const Text('Vagas no veículo',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Spacer(),
                          SizedBox(
                            width: 56,
                            child: TextField(
                              controller: _vagasVanController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_vagasVan > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _TurnoVagasIndicator(
                                turno: 'Manhã',
                                ocupadas: _alunosManha,
                                total: _vagasVan),
                            const SizedBox(width: 8),
                            _TurnoVagasIndicator(
                                turno: 'Tarde',
                                ocupadas: _alunosTarde,
                                total: _vagasVan),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Preço por km',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Spacer(),
                          const Text('R\$ ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _precoKmController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '0,00',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('/km',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('Valor mensal por aluno',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const Spacer(),
                          const Text('R\$ ',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _valorServicoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '0,00',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('/mês',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          const Text('WhatsApp',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _whatsappController,
                              keyboardType: TextInputType.phone,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: '(XX) 9XXXX-XXXX',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      InkWell(
                        onTap: () => _showMyReviews(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Text('Avaliações',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              const Spacer(),
                              if (_rating > 0) ...[
                                const Icon(Icons.star,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${_rating.toStringAsFixed(2)} · $_ratingCount avaliação(ões)',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ] else
                                const Text('Ver avaliações',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary)),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      if (_vanCode != null) ...[
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('VanCode',
                                style: TextStyle(color: AppColors.textSecondary)),
                            Text(
                              _vanCode!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 2,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Botão único de salvar tudo
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _savingProfile ? null : _saveProfile,
                  icon: _savingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _savingProfile ? 'Salvando...' : 'Salvar Perfil',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (_uploadingDoc)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _CepFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue _, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buf.write('-');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String? hint;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.enabled,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: !enabled,
        fillColor: enabled ? null : AppColors.surfaceVariant.withAlpha(80),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: AppColors.surfaceVariant,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool uploaded;
  final VoidCallback onTap;
  final VoidCallback? onViewTap;
  final bool optional;
  final String? fileName;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.uploaded,
    required this.onTap,
    this.onViewTap,
    this.optional = false,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: uploaded
                ? AppColors.success.withAlpha(30)
                : optional
                    ? AppColors.textDisabled.withAlpha(30)
                    : AppColors.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: uploaded
                ? AppColors.success
                : optional
                    ? AppColors.textSecondary
                    : AppColors.primaryDark,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
            ),
            if (optional) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.textDisabled.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Opcional',
                  style: TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        subtitle: fileName != null && fileName!.isNotEmpty
            ? Row(
                children: [
                  const Icon(Icons.check_circle, 
                    size: 14, 
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fileName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: uploaded
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onViewTap,
                    child: const Icon(Icons.check_circle, color: AppColors.success),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: onTap,
                    tooltip: 'Atualizar documento',
                    color: AppColors.textSecondary,
                  ),
                ],
              )
            : ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Enviar', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      optional ? AppColors.surfaceVariant : AppColors.primary,
                  foregroundColor:
                      optional ? AppColors.textSecondary : AppColors.text,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minhas avaliações — visão do motorista
// ---------------------------------------------------------------------------

class _MyReviewsSheet extends StatefulWidget {
  final int motoristaId;
  const _MyReviewsSheet({required this.motoristaId});

  @override
  State<_MyReviewsSheet> createState() => _MyReviewsSheetState();
}

class _MyReviewsSheetState extends State<_MyReviewsSheet> {
  bool _loading = true;
  String? _error;
  double? _media;
  int _total = 0;
  List<Map<String, dynamic>> _avaliacoes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final params = widget.motoristaId > 0
          ? {'motorista_id': widget.motoristaId}
          : null;
      final res = await Dio().get(
        '${ApiConstants.baseUrl}${ApiConstants.evaluationsIndex}',
        queryParameters: params,
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );
      if (res.data is Map && res.data['success'] == true) {
        final raw = res.data['data'];
        List<Map<String, dynamic>> list;
        double? media;
        int total;

        if (raw is Map) {
          // Formato novo: { media, total, avaliacoes: [...] }
          media = raw['media'] != null
              ? double.tryParse(raw['media'].toString())
              : null;
          total = int.tryParse(raw['total']?.toString() ?? '0') ?? 0;
          list  = List<Map<String, dynamic>>.from(raw['avaliacoes'] ?? []);
        } else {
          // Formato antigo: lista plana
          list  = List<Map<String, dynamic>>.from(raw ?? []);
          total = list.length;
          if (total > 0) {
            final sum = list.fold<double>(0, (acc, e) =>
                acc + (double.tryParse(e['nota']?.toString() ?? '0') ?? 0));
            media = sum / total;
          }
        }

        if (mounted) {
          setState(() {
            _media = media;
            _total = total;
            _avaliacoes = list;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() { _error = 'Erro ao carregar avaliações.'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _mesLabel(String mes) {
    const nomes = ['', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                       'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final parts = mes.split('-');
    if (parts.length != 2) return mes;
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return mes;
    return '${nomes[m]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
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
                const Row(
                  children: [
                    Icon(Icons.star, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Minhas avaliações',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Anônimas — use para melhorar seu serviço.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                        ),
                      )
                    : _total == 0
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_border,
                                    size: 48, color: AppColors.textDisabled),
                                SizedBox(height: 12),
                                Text('Ainda sem avaliações dos responsáveis.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView(
                            controller: controller,
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Resumo
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star,
                                        color: AppColors.primary, size: 28),
                                    const SizedBox(width: 8),
                                    Text(
                                      _media != null
                                          ? _media!.toStringAsFixed(2)
                                          : '—',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'de 5.00\n$_total avaliação(ões)',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._avaliacoes.map((av) {
                                final nota =
                                    double.tryParse(av['nota']?.toString() ?? '0') ?? 0;
                                final comentario =
                                    av['comentario']?.toString().trim() ?? '';
                                final mes =
                                    av['mes_referencia']?.toString() ?? '';
                                final stars = nota.round().clamp(1, 5);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Row(
                                              children: List.generate(
                                                5,
                                                (i) => Icon(
                                                  i < stars
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  size: 16,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              nota.toStringAsFixed(2),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _mesLabel(mes),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                        if (comentario.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            '"$comentario"',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TurnoVagasIndicator extends StatelessWidget {
  final String turno;
  final int ocupadas;
  final int total;

  const _TurnoVagasIndicator({
    required this.turno,
    required this.ocupadas,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final livres = (total - ocupadas).clamp(0, total);
    final color = livres > 0 ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$turno: $livres livre${livres != 1 ? 's' : ''} · $ocupadas ocupada${ocupadas != 1 ? 's' : ''}',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
