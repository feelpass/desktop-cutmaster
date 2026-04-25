import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const topBarTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnHeader,
  );

  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: AppColors.tableHeaderText,
  );

  static const tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.tableHeaderText,
  );

  static const tableCell = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const efficiencyNumber = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const emptyHint = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );
}
