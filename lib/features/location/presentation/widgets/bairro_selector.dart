import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/models/estado.dart';
import '../../domain/models/municipio.dart';
import '../../domain/models/bairro.dart';
import '../../data/location_repository.dart';

class BairroSelector extends StatefulWidget {
  final List<int> selectedBairroIds;
  final ValueChanged<List<int>> onSelectionChanged;
  final int? initialEstadoId;
  final int? initialMunicipioId;
  /// Chamado sempre que o município selecionado mudar
  final void Function(int? estadoId, int? municipioId)? onLocationChanged;

  const BairroSelector({
    super.key,
    required this.selectedBairroIds,
    required this.onSelectionChanged,
    this.initialEstadoId,
    this.initialMunicipioId,
    this.onLocationChanged,
  });

  @override
  State<BairroSelector> createState() => _BairroSelectorState();
}

class _BairroSelectorState extends State<BairroSelector> {
  final _repo = LocationRepository();
  final _novoBairroCtrl = TextEditingController();

  List<Estado> _estados = [];
  List<Municipio> _municipios = [];
  List<Bairro> _bairros = [];

  int? _selectedEstadoId;
  int? _selectedMunicipioId;
  final Set<int> _selectedBairros = {};

  // Bairros pendentes adicionados nesta sessão (nome → status)
  final List<Map<String, String>> _pendentes = [];

  bool _loadingEstados = false;
  bool _loadingMunicipios = false;
  bool _loadingBairros = false;
  bool _addingBairro = false;

  @override
  void initState() {
    super.initState();
    _selectedBairros.addAll(widget.selectedBairroIds);
    _loadEstados().then((_) {
      if (widget.initialEstadoId != null) {
        setState(() => _selectedEstadoId = widget.initialEstadoId);
        _loadMunicipios(widget.initialEstadoId!).then((_) {
          if (widget.initialMunicipioId != null) {
            setState(() => _selectedMunicipioId = widget.initialMunicipioId);
            _loadBairros(widget.initialMunicipioId!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _novoBairroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEstados() async {
    setState(() => _loadingEstados = true);
    try {
      _estados = await _repo.fetchEstados();
    } catch (e) {
      debugPrint('Erro ao carregar estados: $e');
    }
    setState(() => _loadingEstados = false);
  }

  Future<void> _loadMunicipios(int estadoId) async {
    setState(() {
      _loadingMunicipios = true;
      _municipios = [];
      _bairros = [];
      _pendentes.clear();
      _selectedMunicipioId = null;
    });
    try {
      _municipios = await _repo.fetchMunicipios(estadoId);
    } catch (e) {
      debugPrint('Erro ao carregar municípios: $e');
    }
    setState(() => _loadingMunicipios = false);
  }

  Future<void> _loadBairros(int municipioId) async {
    setState(() {
      _loadingBairros = true;
      _bairros = [];
      _pendentes.clear();
    });
    try {
      _bairros = await _repo.fetchBairros(municipioId);
    } catch (e) {
      debugPrint('Erro ao carregar bairros: $e');
    }
    setState(() => _loadingBairros = false);
  }

  Future<void> _adicionarBairro() async {
    final nome = _novoBairroCtrl.text.trim();
    debugPrint('[BairroSelector] _adicionarBairro chamado. nome=$nome, municipioId=$_selectedMunicipioId');
    if (nome.isEmpty || _selectedMunicipioId == null) {
      debugPrint('[BairroSelector] Retornando cedo: nome vazio ou municipio nulo');
      return;
    }

    // Verifica se já existe na lista ativa
    final jaExiste = _bairros.any((b) => b.nome.toLowerCase() == nome.toLowerCase());
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este bairro já está na lista.')),
      );
      return;
    }

    setState(() => _addingBairro = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      final municipioNome = _municipios
          .firstWhere((m) => m.id == _selectedMunicipioId,
              orElse: () => Municipio(id: 0, nome: '', ibge: 0))
          .nome;
      final result = await _repo.createBairro(
        nome: nome,
        municipioId: _selectedMunicipioId!,
        municipioNome: municipioNome,
        token: token,
      );

      final status = result['status'] as String;
      if (status == 'ativo') {
        // Já estava ativo — recarrega a lista
        await _loadBairros(_selectedMunicipioId!);
      } else {
        // Pendente — mostra na sessão atual
        setState(() => _pendentes.add({'nome': nome, 'status': 'pendente'}));
      }
      _novoBairroCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'ativo'
                ? 'Bairro adicionado!'
                : 'Bairro enviado para aprovação.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao cadastrar bairro: $e');
      String msg = 'Erro desconhecido';
      if (e is DioException) {
        msg = e.response?.data?.toString() ?? e.message ?? 'Erro Dio';
      } else {
        msg = e.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
        );
      }
    }
    setState(() => _addingBairro = false);
  }

  void _toggleBairro(int bairroId) {
    setState(() {
      if (_selectedBairros.contains(bairroId)) {
        _selectedBairros.remove(bairroId);
      } else {
        _selectedBairros.add(bairroId);
      }
    });
    widget.onSelectionChanged(_selectedBairros.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Estado
        _buildDropdown(
          label: 'Estado',
          value: _selectedEstadoId,
          items: _estados
              .map((e) => DropdownMenuItem(value: e.id, child: Text('${e.uf} - ${e.nome}')))
              .toList(),
          onChanged: (id) {
            setState(() => _selectedEstadoId = id);
            if (id != null) _loadMunicipios(id);
            widget.onLocationChanged?.call(id, null);
          },
          loading: _loadingEstados,
        ),
        const SizedBox(height: 12),

        // Município
        _buildDropdown(
          label: 'Município',
          value: _selectedMunicipioId,
          items: _municipios
              .map((m) => DropdownMenuItem(value: m.id, child: Text(m.nome)))
              .toList(),
          onChanged: (id) {
            setState(() => _selectedMunicipioId = id);
            if (id != null) _loadBairros(id);
            widget.onLocationChanged?.call(_selectedEstadoId, id);
          },
          loading: _loadingMunicipios,
          enabled: _selectedEstadoId != null,
        ),
        const SizedBox(height: 16),

        // Bairros ativos
        if (_selectedMunicipioId != null) ...[
          if (_loadingBairros)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_bairros.isNotEmpty) ...[
              const Text('Bairros disponíveis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bairros.map((b) {
                  final isSelected = _selectedBairros.contains(b.id);
                  return FilterChip(
                    label: Text(b.nome),
                    selected: isSelected,
                    onSelected: (_) => _toggleBairro(b.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Bairros pendentes desta sessão
            if (_pendentes.isNotEmpty) ...[
              const Text('Aguardando aprovação:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendentes
                    .map((p) => Chip(
                          label: Text(p['nome']!),
                          backgroundColor: Colors.orange.shade100,
                          avatar: const Icon(Icons.access_time,
                              size: 14, color: Colors.orange),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Campo para adicionar novo bairro
            const Text('Não encontrou seu bairro?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _novoBairroCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Digite o nome do bairro',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _adicionarBairro(),
                  ),
                ),
                const SizedBox(width: 8),
                _addingBairro
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: _adicionarBairro,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        child: const Text('Adicionar'),
                      ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
    bool loading = false,
    bool enabled = true,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          hint: Text('Selecione $label'),
          items: items,
          onChanged: enabled ? (v) => onChanged(v) : null,
        ),
      ),
    );
  }
}
