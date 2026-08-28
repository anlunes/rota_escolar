import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  String? _veiculoPlaca;
  String? _veiculoModelo;
  String? _vanCode;
  String? _whatsapp;
  final TextEditingController _whatsappController = TextEditingController();

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
          : ApiConstants.uploadFotoCnh;

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
        '${ApiConstants.baseUrl}${ApiConstants.uploadFotoCnh}',
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
            _vanCode  = data['van_code'];
            _whatsapp = data['whatsapp'];
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

  Future<void> _saveBairros() async {
    final dio = Dio();
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await dio.post(
      '${ApiConstants.baseUrl}${ApiConstants.driverBairros}',
      data: {
        'bairro_ids':   _selectedBairroIds,
        'estado_id':    _prefEstadoId,
        'municipio_id': _prefMunicipioId,
        'whatsapp':     _whatsappController.text.trim(),
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
                      _InfoRow(label: 'Alunos ativos', value: '—'),
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
                      _InfoRow(label: 'Avaliação média', value: '—'),
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
