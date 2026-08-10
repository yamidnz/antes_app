import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y tipografía de ANTES.
/// Estética de "estación de monitoreo": oscura, precisa, con acentos de
/// estado (teal = normal, ámbar = vigilancia, rojo = alerta/SOS).
class AppColors {
  static const bg = Color(0xFF0B0F14);
  static const bgElevated = Color(0xFF12181F);
  static const card = Color(0xFF171F27);
  static const line = Color(0xFF232D38);
  static const text = Color(0xFFE7EDF3);
  static const dim = Color(0xFF8A97A6);
  static const dim2 = Color(0xFF5C6774);
  static const teal = Color(0xFF35D0A6);
  static const amber = Color(0xFFF5A623);
  static const red = Color(0xFFFF4757);
  static const blue = Color(0xFF4C8DFF);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.teal,
        secondary: AppColors.blue,
        error: AppColors.red,
        surface: AppColors.card,
      ),
      textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgElevated,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.dim2,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  static TextStyle display({double size = 20, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: w, color: AppColors.text);

  static TextStyle mono({double size = 12, Color color = AppColors.dim}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, color: color);
}
