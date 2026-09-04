import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/evaluation_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _mesLabel(String mes) {
  // mes = 'Y-m', ex: '2026-09'
  const nomes = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];
  final parts = mes.split('-');
  if (parts.length != 2) return mes;
  final ano = parts[0];
  final mes0 = int.tryParse(parts[1]) ?? 0;
  if (mes0 < 1 || mes0 > 12) return mes;
  return '${nomes[mes0]}/$ano';
}

// ---------------------------------------------------------------------------
// MonthlyEvaluationModal
// ---------------------------------------------------------------------------

class MonthlyEvaluationModal extends ConsumerStatefulWidget {
  final int motoristaId;
  final String mes;

  const MonthlyEvaluationModal({
    super.key,
    required this.motoristaId,
    required this.mes,
  });

  @override
  ConsumerState<MonthlyEvaluationModal> createState() =>
      _MonthlyEvaluationModalState();
}

class _MonthlyEvaluationModalState
    extends ConsumerState<MonthlyEvaluationModal> {
  double _punctuality = 0;
  double _safety = 0;
  double _courtesy = 0;
  final _commentCtrl = TextEditingController();
  bool _saving = false;
  bool _submitted = false;
  String? _errorMsg;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  double get _nota {
    return ((_punctuality + _safety + _courtesy) / 3).clamp(1.0, 5.0);
  }

  Future<void> _submit() async {
    if (_punctuality == 0 || _safety == 0 || _courtesy == 0) {
      setState(() => _errorMsg = 'Avalie todos os critérios antes de enviar.');
      return;
    }

    setState(() { _saving = true; _errorMsg = null; });

    try {
      await ref.read(evaluationRepositoryProvider).submit(
        motoristaId: widget.motoristaId,
        nota: _nota,
        mes: widget.mes,
        comentario: _commentCtrl.text.trim(),
      );
      if (mounted) setState(() => _submitted = true);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = 'Não foi possível enviar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submitted ? _buildThanks() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildThanks() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 64),
        const SizedBox(height: 16),
        Text(
          'Obrigado pela avaliação!',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Sua opinião ajuda a melhorar o serviço.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avaliação Mensal',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_mesLabel(widget.mes)} — Obrigatório',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // Sliders
        _RatingSlider(
          label: 'Pontualidade',
          icon: Icons.access_time,
          value: _punctuality,
          onChanged: (v) => setState(() => _punctuality = v),
        ),
        const SizedBox(height: 16),
        _RatingSlider(
          label: 'Segurança',
          icon: Icons.security,
          value: _safety,
          onChanged: (v) => setState(() => _safety = v),
        ),
        const SizedBox(height: 16),
        _RatingSlider(
          label: 'Cordialidade',
          icon: Icons.sentiment_satisfied,
          value: _courtesy,
          onChanged: (v) => setState(() => _courtesy = v),
        ),
        const SizedBox(height: 20),

        // Comentário
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Comentário (opcional — anônimo)',
            hintText: 'Sugestões, elogios ou críticas...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMsg!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.text,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.text),
                  )
                : const Text(
                    'Enviar e Acessar App',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Slider de avaliação
// ---------------------------------------------------------------------------

class _RatingSlider extends StatelessWidget {
  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const _RatingSlider({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final stars = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                return Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  size: 18,
                  color: AppColors.primary,
                );
              }),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            thumbColor: AppColors.primaryDark,
            overlayColor: AppColors.primary.withAlpha(40),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
