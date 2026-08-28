import 'package:flutter/material.dart';

/// Paleta de cores do Rota Escolar - inspirada em van escolar
class AppColors {
  AppColors._();

  // Amarelo van escolar (primária)
  static const primary = Color(0xFFFFD700); // gold
  static const primaryDark = Color(0xFFFFB300); // amber-700
  static const primaryLight = Color(0xFFFFE57F); // amber-200
  static const primaryVariant = Color(0xFFFFC107); // amber

  // Preto (texto e contraste)
  static const text = Color(0xFF212121); // grey-900
  static const textSecondary = Color(0xFF757575); // grey-600
  static const textDisabled = Color(0xFFBDBDBD); // grey-400

  // Branco (background)
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFAFAFA); // grey-50
  static const surfaceVariant = Color(0xFFF5F5F5); // grey-100

  // Status (semânticos)
  static const success = Color(0xFF4CAF50); // green-500
  static const warning = Color(0xFFFF9800); // orange-500
  static const error = Color(0xFFF44336); // red-500
  static const info = Color(0xFF2196F3); // blue-500

  // Status específicos do aluno
  static const statusWaiting = Color(0xFF9E9E9E); // grey-500
  static const statusToSchool = Color(0xFF2196F3); // blue-500
  static const statusAtSchool = Color(0xFF4CAF50); // green-500
  static const statusToHome = Color(0xFFFF9800); // orange-500
  static const statusAtHome = Color(0xFF8BC34A); // light-green-500

  // Transparências
  static const overlay = Color(0x80000000); // 50% black
  static const overlayLight = Color(0x40000000); // 25% black
}
