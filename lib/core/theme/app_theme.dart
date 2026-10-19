import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// One theme's colours: the canvas, the cards, the words, and the greys
/// between them. Same family as the HRM app so the two feel related.
class _Palette {
  final Color primary;
  final Color background;
  final Color surface;
  final Color text;
  final List<Color> greys;

  const _Palette({
    required this.primary,
    required this.background,
    required this.surface,
    required this.text,
    required this.greys,
  });
}

const _light = _Palette(
  primary: Color(0xFF006B3C),
  background: Color(0xFFF4F6F5),
  surface: Color(0xFFFFFFFF),
  text: Color(0xFF1A1A1A),
  greys: [
    Color(0xFFFAFAFA),
    Color(0xFFF5F5F5),
    Color(0xFFEEEEEE),
    Color(0xFFE0E0E0),
    Color(0xFFBDBDBD),
    Color(0xFF9E9E9E),
    Color(0xFF757575),
    Color(0xFF616161),
    Color(0xFF424242),
    Color(0xFF212121),
  ],
);

const _dark = _Palette(
  primary: Color(0xFF3DCB86),
  background: Color(0xFF0F1412),
  surface: Color(0xFF19201C),
  text: Color(0xFFE8ECEA),
  greys: [
    Color(0xFF1C2420),
    Color(0xFF212A25),
    Color(0xFF2B3530),
    Color(0xFF36413B),
    Color(0xFF56625C),
    Color(0xFF7F8A84),
    Color(0xFFA0AAA5),
    Color(0xFFB7C0BB),
    Color(0xFFD0D7D3),
    Color(0xFFE6EBE8),
  ],
);

/// Colours that mean money moving in or out. Read them with
/// `context.cash` so they follow the theme.
@immutable
class CashColors extends ThemeExtension<CashColors> {
  /// Words and numbers for money in / out.
  final Color inText;
  final Color outText;

  /// The two big bright action buttons. Same in both themes.
  final Color inButton;
  final Color outButton;

  /// Chart marks, validated for colour-blind separation on each surface.
  final Color inChart;
  final Color outChart;

  /// Faint wash behind an in / out icon.
  final Color inSoft;
  final Color outSoft;

  final Color hairline;
  final Color muted;
  final Color canvas;

  const CashColors({
    required this.inText,
    required this.outText,
    required this.inButton,
    required this.outButton,
    required this.inChart,
    required this.outChart,
    required this.inSoft,
    required this.outSoft,
    required this.hairline,
    required this.muted,
    required this.canvas,
  });

  @override
  CashColors copyWith() => this;

  @override
  CashColors lerp(ThemeExtension<CashColors>? other, double t) {
    if (other is! CashColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CashColors(
      inText: l(inText, other.inText),
      outText: l(outText, other.outText),
      inButton: l(inButton, other.inButton),
      outButton: l(outButton, other.outButton),
      inChart: l(inChart, other.inChart),
      outChart: l(outChart, other.outChart),
      inSoft: l(inSoft, other.inSoft),
      outSoft: l(outSoft, other.outSoft),
      hairline: l(hairline, other.hairline),
      muted: l(muted, other.muted),
      canvas: l(canvas, other.canvas),
    );
  }
}

extension CashColorsX on BuildContext {
  CashColors get cash => Theme.of(this).extension<CashColors>()!;
}

class AppTheme {
  AppTheme._();

  static const Color brandColor = Color(0xFF006B3C);
  static const Color secondaryColor = Color(0xFF6DBE45);
  static const Color accentColor = Color(0xFFFEDD00);
  static const Color errorColor = Color(0xFFD32F2F);

  /// The bright action colours for the Cash In / Cash Out buttons.
  static const Color cashInButton = Color(0xFF16A34A);
  static const Color cashOutButton = Color(0xFFE53935);

  static const double radius = 12;

  static ThemeData get lightTheme => _theme(_light, Brightness.light);
  static ThemeData get darkTheme => _theme(_dark, Brightness.dark);

  static OutlineInputBorder _inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData _theme(_Palette p, Brightness brightness) {
    final g = p.greys;
    final text = p.text;
    final dark = brightness == Brightness.dark;
    final onPrimary = dark ? const Color(0xFF06150D) : Colors.white;

    final cash = CashColors(
      inText: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      outText: dark ? const Color(0xFFFF7B72) : const Color(0xFFD32F2F),
      inButton: cashInButton,
      outButton: cashOutButton,
      inChart: dark ? const Color(0xFF127856) : const Color(0xFF0B7A5E),
      outChart: dark ? const Color(0xFFE46A4F) : const Color(0xFFEE6A4D),
      inSoft: dark ? const Color(0xFF143323) : const Color(0xFFE3F5EA),
      outSoft: dark ? const Color(0xFF3A1D1B) : const Color(0xFFFDE8E7),
      hairline: g[2],
      muted: g[6],
      canvas: p.background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.surface,
      splashFactory: InkRipple.splashFactory,
      extensions: [cash],
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: _light.primary,
            brightness: brightness,
          ).copyWith(
            primary: p.primary,
            onPrimary: onPrimary,
            secondary: secondaryColor,
            surface: p.surface,
            onSurface: text,
            onSurfaceVariant: g[6],
            outline: g[3],
            outlineVariant: g[2],
            surfaceContainerLowest: p.surface,
            surfaceContainerLow: p.surface,
            surfaceContainer: p.surface,
            surfaceContainerHigh: g[1],
            surfaceContainerHighest: g[1],
            error: errorColor,
            onError: Colors.white,
          ),

      // Flat, borderless app bar that blends with the page.
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: text,
        ),
        iconTheme: IconThemeData(color: text, size: 24),
        actionsIconTheme: IconThemeData(color: text, size: 24),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: g[2],
          disabledForegroundColor: g[5],
          minimumSize: const Size(64, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: g[2],
          disabledForegroundColor: g[5],
          minimumSize: const Size(64, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: g[4],
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: g[4],
          side: BorderSide(color: g[3]),
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Inputs: cards with a hairline border on the canvas.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: _inputBorder(g[3]),
        enabledBorder: _inputBorder(g[3]),
        focusedBorder: _inputBorder(p.primary, 1.5),
        errorBorder: _inputBorder(errorColor),
        focusedErrorBorder: _inputBorder(errorColor, 1.5),
        disabledBorder: _inputBorder(g[2]),
        labelStyle: TextStyle(color: g[6]),
        hintStyle: TextStyle(color: g[5], fontSize: 15),
        errorStyle: const TextStyle(color: errorColor),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.focused) ? p.primary : g[6],
        ),
        suffixIconColor: p.primary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark
            ? const Color(0xFF2C3631)
            : const Color(0xFF212121),
        actionTextColor: accentColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        width: 420,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary.withValues(alpha: 0.14),
        side: BorderSide(color: g[3]),
        labelStyle: TextStyle(
          fontSize: 14,
          color: text,
          fontWeight: FontWeight.w500,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),

      dividerTheme: DividerThemeData(color: g[2], thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: g[2]),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 640),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 14,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? p.primary : g[7],
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.primary : g[7],
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: g[7],
        textColor: text,
        subtitleTextStyle: TextStyle(fontSize: 13, color: g[6]),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: g[2],
        circularTrackColor: g[2],
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: p.primary.withValues(alpha: 0.14),
          selectedForegroundColor: p.primary,
          foregroundColor: g[7],
          side: BorderSide(color: g[3]),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : g[5],
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : g[2],
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.primary : g[4],
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(onPrimary),
        side: BorderSide(color: g[4], width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.25),
        selectionHandleColor: p.primary,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2C3631) : const Color(0xFF212121),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),

      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: text),
        bodyMedium: TextStyle(fontSize: 14, color: text),
        bodySmall: TextStyle(fontSize: 12, color: g[6]),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: g[6],
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: g[6],
        ),
      ),
    );
  }
}
