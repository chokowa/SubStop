import 'package:flutter/material.dart';

import 'app_constants.dart';

class AppColors {
  static const Color primary = Color(0xFF2E5BFF);
  static const Color primaryLight = Color(0xFF6E8CFF);

  static const Color safe = Color(0xFF00E676);
  static const Color warning = Color(0xFFFF9100);
  static const Color danger = Color(0xFFFF1744);
  static const Color info = Color(0xFF00B0FF);

  static const Color darkBackground = Color(0xFF08090C);
  static const Color darkCard = Color(0xFF14171F);
  static const Color darkTextMain = Color(0xFFF1F4F9);
  static const Color darkTextSub = Color(0xFF9EABB8);

  static const Color lightBackground = Color(0xFFF9FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightTextMain = Color(0xFF1A1C1E);
  static const Color lightTextSub = Color(0xFF6B7280);

  static final List<Color> _categoryPalette = [
    const Color(0xFF2E5BFF), // Primary Blue
    const Color(0xFFD16BFF), // Purple
    const Color(0xFF10B981), // Teal/Green
    const Color(0xFFFF9100), // Orange
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF3B82F6), // Sky Blue
    const Color(0xFFEC4899), // Pink
    const Color(0xFFFF1744), // Red
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFF97316), // Deep Orange
    const Color(0xFF84CC16), // Lime
  ];

  static Color getCategoryColor(String category) {
    // 主要なカテゴリには馴染みのある色を優先的に割り当てる (ハッシュでも良いが、固定しておくと安心感がある)
    if (category == AppConstants.categoryEntertainment) return _categoryPalette[1]; // Purple
    if (category == AppConstants.categoryBooks) return _categoryPalette[5]; // Sky Blue
    if (category == AppConstants.categoryLifestyle) return _categoryPalette[2]; // Teal
    if (category == AppConstants.categoryFinance) return _categoryPalette[4]; // Amber
    if (category == AppConstants.categoryOther) return const Color(0xFF94A3B8); // Slate Gray

    // それ以外のカテゴリ（自作カテゴリなど）はハッシュでパレットから分散させる
    final int index = category.hashCode.abs() % _categoryPalette.length;
    return _categoryPalette[index];
  }

  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color textMain(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextMain
        : lightTextMain;
  }

  static Color textSub(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSub
        : lightTextSub;
  }
}
