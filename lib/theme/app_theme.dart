import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Monochrome palette: white, black and a single blue accent.
/// Red is used only for validation errors and destructive actions.
class AppColors {
  static const white = Colors.white;
  static const background = Color(0xFFF5F5F7);
  static const ink = Color(0xFF111114);
  static const muted = Color(0xFF6B6B74);
  static const faint = Color(0xFF9C9CA5);
  static const line = Color(0xFFE4E4E9);
  static const hover = Color(0xFFF9F9FB);
  static const blue = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFEFF4FF);
  static const error = Color(0xFFB42318);
}

TextStyle monoStyle({double size = 13, FontWeight weight = FontWeight.w500}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: AppColors.ink,
    );

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.blue,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.ink,
      error: AppColors.error,
    ),
  );
  final radius = BorderRadius.circular(8);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: c, width: w),
  );
  final text = base.textTheme.apply(
    fontFamily: GoogleFonts.inter().fontFamily,
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      isDense: true,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: AppColors.blue),
      hintStyle: const TextStyle(color: AppColors.faint),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.blue, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.5),
        disabledForegroundColor: AppColors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.blue,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.blueSoft,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: radius),
      labelStyle: const TextStyle(color: AppColors.ink, fontSize: 13),
      checkmarkColor: AppColors.blue,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: GoogleFonts.inter(color: AppColors.white),
      actionTextColor: const Color(0xFF9DB8FF),
      shape: RoundedRectangleBorder(borderRadius: radius),
      width: 420,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
    ),
  );
}

/// White surface with a hairline border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Stock status label: outlined for low stock, solid black when out.
class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.quantity, required this.reorder});

  final int quantity;
  final int reorder;

  @override
  Widget build(BuildContext context) {
    final out = quantity == 0;
    final low = quantity <= reorder;
    if (!out && !low) {
      return const Text(
        'In stock',
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: out ? AppColors.ink : AppColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.ink),
      ),
      child: Text(
        out ? 'Out of stock' : 'Low stock',
        style: TextStyle(
          color: out ? AppColors.white : AppColors.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
