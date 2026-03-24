import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'utils/app_colors.dart';
import 'screens/dashboard_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows または Linux の場合は SQLite の FFI 用初期化を行う
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await NotificationService().init();
  await initializeDateFormatting('ja_JP');
  runApp(const SubStopApp());
}

class SubStopApp extends StatelessWidget {
  const SubStopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- ライトテーマ定義 ---
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.lightCard,
        surfaceContainerLowest: Colors.white,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        ThemeData.light().textTheme.apply(
              bodyColor: AppColors.lightTextMain,
              displayColor: AppColors.lightTextMain,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSansJp(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextMain,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextMain),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    // --- ダークテーマ定義 ---
    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.darkCard,
        surfaceContainerLowest: AppColors.darkCard,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: AppColors.darkTextMain,
              displayColor: AppColors.darkTextMain,
            ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        titleTextStyle: GoogleFonts.notoSansJp(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextMain,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextMain),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    return MaterialApp(
      title: 'SubStop',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // システム設定に追従
      theme: lightTheme,
      darkTheme: darkTheme,
      home: const DashboardScreen(),
    );
  }
}
