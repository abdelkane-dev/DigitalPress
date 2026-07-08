import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM — Digital Press Fusion
// Dark Navy theme extracted from new lib + functional palette from old lib
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Primary brand palette (from new lib dark navy)
  static const Color primary        = Color(0xFF2C74B3);
  static const Color primaryDark    = Color(0xFF0A2647);
  static const Color primaryMid     = Color(0xFF144272);
  static const Color primaryLight   = Color(0xFF90CAF9);
  static const Color accent         = Color(0xFF42A5F5);

  // Gradient colors (dark navy from new lib)
  static const Color gradientStart  = Color(0xFF0A2647);
  static const Color gradientMid    = Color(0xFF144272);
  static const Color gradientEnd    = Color(0xFF2C5364);

  // Auth screen gradient (from new lib login)
  static const Color authGradStart  = Color(0xFF0F2027);
  static const Color authGradMid    = Color(0xFF203A43);
  static const Color authGradEnd    = Color(0xFF2C5364);

  // Status colors
  static const Color success        = Color(0xFF10B981);
  static const Color warning        = Color(0xFFF59E0B);
  static const Color error          = Color(0xFFEF4444);
  static const Color info           = Color(0xFF3B82F6);

  // Role colors
  static const Color adminColor     = Color(0xFF0A2647);
  static const Color entrepriseColor= Color(0xFFEA580C);
  static const Color clientColor    = Color(0xFF059669);

  // Neutral palette
  static const Color background     = Color(0xFFF8FAFC);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color divider        = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary    = Color(0xFF0A2647);
  static const Color textSecondary  = Color(0xFF64748B);
  static const Color textHint       = Color(0xFF94A3B8);
  static const Color textOnDark     = Color(0xFFFFFFFF);

  // Glass / overlay
  static Color glassWhite           = Colors.white.withValues(alpha: 0.08);
  static Color glassBorder          = Colors.white.withValues(alpha: 0.2);
  static Color glassDark            = Colors.black.withValues(alpha: 0.15);

  // Payment method colors (from new lib)
  static const Color wave           = Color(0xFF49B8E7);
  static const Color orangeMoney    = Color(0xFFFF7900);
  static const Color moovMoney      = Color(0xFF003399);
  static const Color samaMoney      = Color(0xFF28A745);
  static const Color stripe         = Color(0xFF635BFF);
}

class AppDimensions {
  // Padding
  static const double paddingXS     = 4.0;
  static const double paddingSM     = 8.0;
  static const double paddingMD     = 16.0;
  static const double paddingLG     = 24.0;
  static const double paddingXL     = 32.0;

  // Border radius
  static const double radiusSM      = 8.0;
  static const double radiusMD      = 12.0;
  static const double radiusLG      = 16.0;
  static const double radiusXL      = 20.0;
  static const double radiusXXL     = 28.0;
  static const double radiusRound   = 100.0;

  // Button
  static const double buttonHeight  = 56.0;

  // Card
  static const double cardElevation = 0.0;
  static const double cardRadius    = 20.0;

  // Icon
  static const double iconSM        = 18.0;
  static const double iconMD        = 24.0;
  static const double iconLG        = 32.0;
  static const double iconXL        = 48.0;

  // AppBar
  static const double appBarHeight  = 64.0;
}

class AppTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
    height: 1.1,
  );
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
  static const TextStyle price = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w900,
    color: AppColors.primary,
  );
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.8,
  );
  static const TextStyle onDark = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.gradientStart, AppColors.gradientMid],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient auth = LinearGradient(
    colors: [AppColors.authGradStart, AppColors.authGradMid, AppColors.authGradEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient button = LinearGradient(
    colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient admin = LinearGradient(
    colors: [Color(0xFF0A2647), Color(0xFF144272)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient entreprise = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient client = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warning = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient error = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient card = LinearGradient(
    colors: [Color(0xFF144272), Color(0xFF0A2647)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF0A2647).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> button = [
    BoxShadow(
      color: const Color(0xFF1976D2).withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  static List<BoxShadow> appBar = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// StorageKeys — shared_preferences key constants
// ─────────────────────────────────────────────────────────────────────────────
class StorageKeys {
  static const String accessToken  = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userRole     = 'user_role';
  static const String userId       = 'user_id';
  static const String username     = 'username';
  static const String email        = 'email';
  static const String isDarkMode   = 'is_dark_mode';
}
