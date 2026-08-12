import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF22D3EE);
  static const Color primaryDark = Color(0xFF0891B2);
  static const Color primarySoft = Color(0xFF67E8F9);
  static const Color secondary = Color(0xFFA855F7);
  static const Color accent = Color(0xFFD946EF);

  static const Color background = Color(0xFF05131A);
  static const Color backgroundAlt = Color(0xFF07161F);
  static const Color surface = Color(0xFF0C1F2A);
  static const Color surfaceLight = Color(0xFF132A38);
  static const Color card = Color(0xFF0E2330);
  static const Color elevated = Color(0xFF183444);

  static const Color textPrimary = Color(0xFFEFF6FA);
  static const Color textSecondary = Color(0xFF9DB3C0);
  static const Color textMuted = Color(0xFF5E7684);

  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  static const Color border = Color(0xFF1A3544);
  static const Color borderSoft = Color(0xFF122835);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF22D3EE), Color(0xFFA855F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGlow = LinearGradient(
    colors: [Color(0xFF67E8F9), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient violetGlow = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFFD946EF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient ambient = RadialGradient(
    center: Alignment.topCenter,
    radius: 1.2,
    colors: [
      Color(0xFF0B2530),
      Color(0xFF05131A),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF0F2535), Color(0xFF0B1C26)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient featureGradient = LinearGradient(
    colors: [Color(0xFF1B3348), Color(0xFF0C2230)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    final base = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF041019),
        secondary: secondary,
        surface: surface,
        surfaceContainerHighest: elevated,
        error: danger,
      ),
      textTheme: base.copyWith(
        displayLarge: base.displayLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        displayMedium: base.displayMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        headlineLarge: base.headlineLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        headlineMedium: base.headlineMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleLarge: base.titleLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: base.bodySmall?.copyWith(color: textMuted),
        labelLarge: base.labelLarge?.copyWith(color: textPrimary, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF041019),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.45)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: danger.withValues(alpha: 0.6)),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.plusJakartaSans(color: textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}

class GlowChip extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final double size;
  final double iconSize;
  final double radius;
  final Color? glowColor;

  const GlowChip({
    super.key,
    required this.icon,
    this.gradient = AppTheme.primaryGradient,
    this.size = 48,
    this.iconSize = 22,
    this.radius = 16,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? AppTheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}
