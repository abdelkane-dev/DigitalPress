import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Charte graphique DigitalPress (2026).
///
/// Palette inchangée (identité de marque) :
///   navy   0xFF0A2647  — fonds profonds, titres
///   blue   0xFF2C74B3  — actions, liens
///   steel  0xFF336B82  — couleur primaire (boutons, sélection)
///   sky    0xFF56B4E9  — accents clairs (dark mode)
///   orange 0xFFEA580C  — accent éditeur / actions
/// Le passage « 2026 » porte sur la matière : ombres douces en couches,
/// coins généreusement arrondis, barres de progression arrondies, contrôles
/// (switch/checkbox/texte) cohérents, dark mode plus profond.
class AppTheme {
  /// Named constructor aliases used by main.dart
  static ThemeData light() => lightTheme;
  static ThemeData dark() => darkTheme;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // Même ripple moderne (InkSparkle) que sur Android, partout.
      splashFactory: InkSparkle.splashFactory,
      // Mêmes animations de navigation sur toutes les plateformes
      // (iOS/Android/Web) et donc sur chaque rôle : sans ceci, Flutter
      // utilise par défaut un swipe iOS vs un fade Android, ce qui rendait
      // l'app visuellement incohérente d'une plateforme à l'autre.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF336B82),
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      fontFamily: GoogleFonts.poppins().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0A2647),
        elevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: const Color(0xFF0A2647),
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0A2647)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF336B82),
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          // Ombre douce et large (tendance 2026) plutôt que l'ombre dure
          // par défaut : les boutons semblent flotter sur la page.
          elevation: 0,
          shadowColor: const Color(0xFF336B82).withValues(alpha: 0.35),
          textStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF336B82),
          side: const BorderSide(color: Color(0xFF336B82), width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF336B82), width: 2.0),
        ),
        errorStyle: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.w500, fontSize: 12),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
        floatingLabelStyle: GoogleFonts.poppins(
          color: const Color(0xFF336B82),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF336B82),
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0A2647),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF336B82).withValues(alpha: 0.1),
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF336B82),
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: const Color(0xFF336B82),
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.grey.shade200,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 0,
      ),
      // ─── 2026 : barres de progression arrondies partout ──────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF336B82),
        linearTrackColor: Color(0xFFE8EEF3),
        linearMinHeight: 8,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      // ─── 2026 : curseur et sélection de texte à l'accent de marque ──
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: const Color(0xFF336B82),
        selectionColor: const Color(0xFF336B82).withValues(alpha: 0.25),
        selectionHandleColor: const Color(0xFF2C74B3),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.grey.shade300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF336B82);
          }
          return Colors.grey.shade300;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF336B82);
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: Colors.grey.shade400, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF336B82);
          }
          return Colors.grey.shade400;
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF336B82),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      // Voir lightTheme ci-dessus : même raisonnement, mêmes animations.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF336B82), // Primary from login button
        brightness: Brightness.dark,
        surface: const Color(0xFF151E31),
      ),
      // Fond très sombre à dominante bleu nuit — l'ancienne valeur translucide
      // faisait transparaître le contenu derrière les routes.
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      fontFamily: GoogleFonts.poppins().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shadowColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF336B82),
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
          shadowColor: const Color(0xFF56B4E9).withValues(alpha: 0.3),
          textStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF56B4E9),
          side: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.6), width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.6), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.6), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF56B4E9), width: 2.0),
        ),
        errorStyle: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.w500, fontSize: 12),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: GoogleFonts.poppins(color: const Color(0xFFE5E7EB)),
        floatingLabelStyle: GoogleFonts.poppins(
          color: const Color(0xFF56B4E9),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.poppins(color: const Color(0xFFE5E7EB).withValues(alpha: 0.8), fontSize: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.black.withValues(alpha: 0.25), // Glassmorphism base
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1), // Subtle light border
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXXL),
          side: BorderSide(color: const Color(0xFF56B4E9).withValues(alpha: 0.3), width: 1),
        ),
        backgroundColor: const Color(0xFF1A2938).withValues(alpha: 0.95), // Dark glass
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF0A2647), // Fond opaque
        selectedItemColor: const Color(0xFF56B4E9),
        unselectedItemColor: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF336B82).withValues(alpha: 0.9),
        contentTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.black.withValues(alpha: 0.2),
        selectedColor: const Color(0xFF336B82),
        labelStyle: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFFE5E7EB).withValues(alpha: 0.6),
        indicatorColor: const Color(0xFF56B4E9),
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.white.withValues(alpha: 0.1),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.15),
        thickness: 1,
        space: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF56B4E9),
        linearTrackColor: Colors.white12,
        linearMinHeight: 8,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: const Color(0xFF56B4E9),
        selectionColor: const Color(0xFF56B4E9).withValues(alpha: 0.3),
        selectionHandleColor: const Color(0xFF56B4E9),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return Colors.grey.shade500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF336B82);
          }
          return Colors.white.withValues(alpha: 0.15);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF336B82);
          }
          return Colors.transparent;
        }),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF56B4E9);
          }
          return Colors.white.withValues(alpha: 0.4);
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF336B82),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }
}
