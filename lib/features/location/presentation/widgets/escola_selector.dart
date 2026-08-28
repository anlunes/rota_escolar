import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../domain/models/bairro.dart';
import '../../domain/models/escola.dart';
import '../../data/location_repository.dart';

/// Seletor de escolas atendidas pelo motorista.
/// Depende de uma lista de bairros já selecionados — escolas são filtradas por bairro.
class EscolaSelector extends StatefulWidget {
  final List<int> selectedEscolaIds;
  final List<Bairro> bairrosDoMotorista;
  final ValueChanged<List<int>> onSelectionChanged;
  final ValueChanged<String>? onPendingAdded;

  const EscolaSelector({
    super.key,
    required this.selectedEscolaIds,
    required this.bairrosDoMotorista,
    required this.onSelectionChanged,
    this.onPendingAdded,
  });

  @override
  State<EscolaSelector> createState() => _EscolaSelectorState();
}

class _EscolaSelectorState extends State<EscolaSelector> {
  final _repo = LocationRepository();

  Bairro? _selectedBairro;
  List<Escola> _escolas = [];
  final Set<int> _selectedEscolas = {};
  final List<String> _pendentes = [];
  bool _loadingEscolas = false;

  @override
  void initState() {
    super.initState();
    _selectedEscolas.addAll(widget.selectedEscolaIds);
    if (widget.bairrosDoMotorista.length == 1) {
      _selectedBairro = widget.bairrosDoMotorista.first;
      _loadEscolas(_selectedBairro!.id);
    }
  }

  Future<void> _loadEscolas(int bairroId) async {
    setState(() {
      _loadingEscolas = true;
      _escolas = [];
    });
    try {
      _escolas = await _repo.fetchEscolas(bairroId);
    } catch (e) {
      debugPrint('Erro ao carregar escolas: $e');
    }
    setState(() => _loadingEscolas = false);
  }

  void _toggleEscola(int escolaId) {
    setState(() {
      if (_selectedEscolas.contains(escolaId)) {
        _selectedEscolas.remove(escolaId);
      } else {
        _selectedEscolas.add(escolaId);
      }
    });
    widget.onSelectionChanged(_selectedEscolas.toList());
  }

  Future<void> _abrirFormEscola() async {
    if (_selectedBairro == null) return;

    final result = await showModalBottomSheet<_NovaEscolaResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NovaEscolaSheet(
        bairro: _selectedBairro!,
        escolasExistentes: _escolas,
      ),
    );

    if (result == null || !mounted) return;

    if (result.status == 'ativo') {
      await _loadEscolas(_selectedBairro!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escola adicionada!')),
      );
    } else {
      setState(() => _pendentes.add(result.nome));
      widget.onPendingAdded?.call(result.nome);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escola enviada para aprovação.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bairrosDoMotorista.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Configure seus bairros primeiro para selecionar as escolas.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown de bairros
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Bairro',
            border: OutlineInputBorder(),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Bairro>(
              isExpanded: true,
              value: _selectedBairro,
              hint: const Text('Selecione o bairro'),
              items: widget.bairrosDoMotorista
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.nome)))
                  .toList(),
              onChanged: (b) {
                setState(() {
                  _selectedBairro = b;
                  _escolas = [];
                  _pendentes.clear();
                });
                if (b != null) _loadEscolas(b.id);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_selectedBairro != null) ...[
          if (_loadingEscolas)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_escolas.isNotEmpty) ...[
              const Text('Escolas disponíveis:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _escolas.map((e) {
                  final isSelected = _selectedEscolas.contains(e.id);
                  return FilterChip(
                    label: Text(e.nome),
                    selected: isSelected,
                    onSelected: (_) => _toggleEscola(e.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const Text(
                'Nenhuma escola cadastrada neste bairro ainda.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],

            if (_pendentes.isNotEmpty) ...[
              const Text('Aguardando aprovação:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pendentes
                    .map((nome) => Chip(
                          label: Text(nome),
                          backgroundColor: Colors.orange.shade100,
                          avatar: const Icon(Icons.access_time,
                              size: 14, color: Colors.orange),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            OutlinedButton.icon(
              onPressed: _abrirFormEscola,
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Cadastrar nova escola'),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Resultado devolvido pelo BottomSheet
// ---------------------------------------------------------------------------
class _NovaEscolaResult {
  final String nome;
  final String status;
  _NovaEscolaResult({required this.nome, required this.status});
}

// ---------------------------------------------------------------------------
// BottomSheet de cadastro de nova escola
// ---------------------------------------------------------------------------
class _NovaEscolaSheet extends StatefulWidget {
  final Bairro bairro;
  final List<Escola> escolasExistentes;

  const _NovaEscolaSheet({
    required this.bairro,
    required this.escolasExistentes,
  });

  @override
  State<_NovaEscolaSheet> createState() => _NovaEscolaSheetState();
}

class _NovaEscolaSheetState extends State<_NovaEscolaSheet> {
  final _formKey    = GlobalKey<FormState>();
  final _nomeCtrl   = TextEditingController();
  final _cepCtrl    = TextEditingController();
  final _endCtrl    = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();

  String? _administracao;
  final Set<String> _niveis = {};
  bool _loading     = false;
  bool _buscandoCep = false;

  static const _opcoesAdm = ['Municipal', 'Estadual', 'Federal', 'Privada'];

  static const _opcoesNivel = [
    'Creche (0–3 anos)',
    'Pré-escola (4–5 anos)',
    'Fundamental – Anos Iniciais (1º–5º)',
    'Fundamental – Anos Finais (6º–9º)',
    'Ensino Médio',
  ];

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cepCtrl.dispose();
    _endCtrl.dispose();
    _cidadeCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    final cep = _cepCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) return;

    setState(() => _buscandoCep = true);
    try {
      final res = await Dio().get('https://viacep.com.br/ws/$cep/json/');
      final data = res.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP não encontrado.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          if ((data['logradouro'] as String? ?? '').isNotEmpty) {
            _endCtrl.text = data['logradouro'] as String;
          }
          _cidadeCtrl.text = data['localidade'] as String? ?? '';
          _estadoCtrl.text = data['uf'] as String? ?? '';
        });
      }
    } catch (_) {
      // falha silenciosa — usuário preenche manualmente
    } finally {
      if (mounted) setState(() => _buscandoCep = false);
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    final nome = _nomeCtrl.text.trim();
    final jaExiste = widget.escolasExistentes
        .any((e) => e.nome.toLowerCase() == nome.toLowerCase());
    if (jaExiste) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta escola já está na lista.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final repo  = LocationRepository();
      final token = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
      final result = await repo.createEscola(
        nome: nome,
        bairroId: widget.bairro.id,
        bairroNome: widget.bairro.nome,
        cep: _cepCtrl.text.trim().isEmpty ? null : _cepCtrl.text.trim(),
        endereco: _endCtrl.text.trim().isEmpty ? null : _endCtrl.text.trim(),
        cidade: _cidadeCtrl.text.trim().isEmpty ? null : _cidadeCtrl.text.trim(),
        estado: _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text.trim(),
        administracao: _administracao,
        nivelEscolar: _niveis.isEmpty ? null : _niveis.join(', '),
        token: token,
      );
      if (mounted) {
        Navigator.of(context).pop(
          _NovaEscolaResult(nome: nome, status: result['status'] as String),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'Cadastrar escola',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Bairro: ${widget.bairro.nome}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            // Nome
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome da escola *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome da escola' : null,
            ),
            const SizedBox(height: 14),

            // Administração
            DropdownButtonFormField<String>(
              value: _administracao,
              decoration: const InputDecoration(
                labelText: 'Administração',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              hint: const Text('Selecione (opcional)'),
              items: _opcoesAdm
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: (v) => setState(() => _administracao = v),
            ),
            const SizedBox(height: 14),

            // CEP com busca automática
            TextFormField(
              controller: _cepCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'CEP *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
                hintText: '00000-000',
                suffixIcon: _buscandoCep
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: 'Buscar CEP',
                        onPressed: _buscarCep,
                      ),
              ),
              onEditingComplete: _buscarCep,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o CEP da escola' : null,
            ),
            const SizedBox(height: 14),

            // Endereço (logradouro + número)
            TextFormField(
              controller: _endCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Endereço (rua e número) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.signpost_outlined),
                hintText: 'Ex: Rua das Flores, 123',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o endereço' : null,
            ),
            const SizedBox(height: 14),

            // Cidade e Estado lado a lado
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cidadeCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Cidade',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _estadoCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                      labelText: 'UF',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nível escolar
            const Text(
              'Nível escolar atendido',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            ..._opcoesNivel.map((nivel) => CheckboxListTile(
                  title: Text(nivel, style: const TextStyle(fontSize: 14)),
                  value: _niveis.contains(nivel),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _niveis.add(nivel);
                      } else {
                        _niveis.remove(nivel);
                      }
                    });
                  },
                )),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _enviar,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar para aprovação',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
