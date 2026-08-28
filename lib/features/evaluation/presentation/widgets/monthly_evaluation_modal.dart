import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

// Show only on the 1st day of the month; in production persist with SharedPreferences
bool shouldShowMonthlyEvaluation() {
  return DateTime.now().day == 1;
}

class MonthlyEvaluationModal extends StatefulWidget {
  const MonthlyEvaluationModal({super.key});

  @override
  State<MonthlyEvaluationModal> createState() =>
      _MonthlyEvaluationModalState();
}

class _MonthlyEvaluationModalState extends State<MonthlyEvaluationModal> {
  double _punctuality = 0;
  double _safety = 0;
  double _courtesy = 0;
  final _commentCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submitted
              ? _buildThanks()
              : _buildForm(),
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
                  const Text(
                    'Maio/2026 — Obrigatório',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
        const SizedBox(height: 20),

        // Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Enviar e Acessar App',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
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
