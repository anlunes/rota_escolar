import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/status_constants.dart';

class StatusChip extends StatelessWidget {
  final StudentStatus status;

  const StatusChip({super.key, required this.status});

  Color get _backgroundColor => switch (status) {
        StudentStatus.waitingVan => AppColors.statusWaiting,
        StudentStatus.toSchool => AppColors.statusToSchool,
        StudentStatus.atSchool => AppColors.statusAtSchool,
        StudentStatus.toHome => AppColors.statusToHome,
        StudentStatus.atHome => AppColors.statusAtHome,
      };

  IconData get _icon => switch (status) {
        StudentStatus.waitingVan => Icons.access_time,
        StudentStatus.toSchool => Icons.directions_bus,
        StudentStatus.atSchool => Icons.school,
        StudentStatus.toHome => Icons.directions_bus_filled,
        StudentStatus.atHome => Icons.home,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _backgroundColor.withAlpha(30),
        border: Border.all(color: _backgroundColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: _backgroundColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _backgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}
