import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../app/core/constants/api_constants.dart';
import '../../../../app/theme/app_colors.dart';

class DriverFrotaTab extends StatefulWidget {
  const DriverFrotaTab({super.key});

  @override
  State<DriverFrotaTab> createState() => _DriverFrotaTabState();
}

class _DriverFrotaTabState extends State<DriverFrotaTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _vans = [];

  @override
  void initState() {
    super.initState();
    _loadFrota();
  }

  Future<void> _loadFrota() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.driverFrota}',
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );
      if (response.data is Map && response.data['success'] == true) {
        setState(() {
          _vans = response.data['data']['vans'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _error = 'Erro ao carregar frota.'; _loading = false; });
    }
  }

  Future<void> _addVan() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final dio = Dio();
      await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.driverFrota}',
        data: {'action': 'add_van'},
        options: Options(
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        ),
      );
      await _loadFrota();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao adicionar van.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadFrota, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFrota,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_vans.length} ${_vans.length == 1 ? 'van' : 'vans'} na frota',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              FilledButton.icon(
                onPressed: _addVan,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar van'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_vans.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.directions_bus_outlined, size: 64, color: AppColors.textSecondary.withAlpha(100)),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma van na frota ainda.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toque em "Adicionar van" para começar.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...(_vans.map((van) => _VanCard(van: van)).toList()),
        ],
      ),
    );
  }
}

class _VanCard extends StatelessWidget {
  final Map<String, dynamic> van;
  const _VanCard({required this.van});

  @override
  Widget build(BuildContext context) {
    final placa  = van['veiculo_placa']?.toString()  ?? '—';
    final modelo = van['veiculo_modelo']?.toString() ?? 'Veículo não cadastrado';
    final vagas  = van['vagas_van']?.toString()      ?? '0';
    final code   = van['van_code']?.toString()       ?? '—';
    final motoristaNome = van['motorista_atual_nome']?.toString();
    final pool   = (van['motoristas_pool'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: AppColors.primaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    modelo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(code, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.badge_outlined,       label: 'Placa',    value: placa),
            _InfoRow(icon: Icons.event_seat_outlined,  label: 'Vagas',    value: vagas),
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Motorista atual',
              value: motoristaNome ?? 'Sem motorista designado',
              valueColor: motoristaNome == null ? AppColors.textSecondary : null,
            ),
            _InfoRow(
              icon: Icons.group_outlined,
              label: 'Pool autorizado',
              value: '$pool motorista${pool == 1 ? '' : 's'}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
