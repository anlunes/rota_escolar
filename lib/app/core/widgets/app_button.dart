import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary => Colors.white,
      AppButtonVariant.danger => AppColors.error,
    };
    final foregroundColor = switch (variant) {
      AppButtonVariant.primary => AppColors.text,
      AppButtonVariant.secondary => AppColors.text,
      AppButtonVariant.danger => Colors.white,
    };
    final borderSide = variant == AppButtonVariant.secondary
        ? const BorderSide(color: AppColors.primary, width: 2)
        : BorderSide.none;

    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold));

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: AppColors.textDisabled,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: borderSide,
        ),
        elevation: variant == AppButtonVariant.secondary ? 0 : 2,
      ),
      child: child,
    );

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}
