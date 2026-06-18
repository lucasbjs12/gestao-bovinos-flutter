import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2E7D32),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFB7F0B1),
    onPrimaryContainer: Color(0xFF002204),
    secondary: Color(0xFF52634F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD5E8CF),
    onSecondaryContainer: Color(0xFF101F0F),
    tertiary: Color(0xFF38656A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFBCEBF0),
    onTertiaryContainer: Color(0xFF002023),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF6FBF3),
    onSurface: Color(0xFF1A1C19),
    surfaceContainerHighest: Color(0xFFDEE5D9),
    onSurfaceVariant: Color(0xFF424940),
    outline: Color(0xFF72796F),
    outlineVariant: Color(0xFFC2C9BD),
    inverseSurface: Color(0xFF2F312D),
    onInverseSurface: Color(0xFFF0F1EA),
    inversePrimary: Color(0xFF9BDB96),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9BDB96),
    onPrimary: Color(0xFF003909),
    primaryContainer: Color(0xFF0A5E14),
    onPrimaryContainer: Color(0xFFB7F0B1),
    secondary: Color(0xFFB9CCB4),
    onSecondary: Color(0xFF243424),
    secondaryContainer: Color(0xFF3A4B39),
    onSecondaryContainer: Color(0xFFD5E8CF),
    tertiary: Color(0xFFA0CFD4),
    onTertiary: Color(0xFF00363B),
    tertiaryContainer: Color(0xFF1F4D52),
    onTertiaryContainer: Color(0xFFBCEBF0),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1A1C19),
    onSurface: Color(0xFFE2E3DB),
    surfaceContainerHighest: Color(0xFF424940),
    onSurfaceVariant: Color(0xFFC2C9BD),
    outline: Color(0xFF8C9389),
    outlineVariant: Color(0xFF424940),
    inverseSurface: Color(0xFFE2E3DB),
    onInverseSurface: Color(0xFF2F312D),
    inversePrimary: Color(0xFF2E7D32),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: const Color(0xFFF0F4F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 3,
          shadowColor: Color(0x33000000),
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE3E9E3)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC8D4C8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC8D4C8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 2),
          ),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
        chipTheme: const ChipThemeData(
          shape: StadiumBorder(),
          side: BorderSide.none,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: const Color(0xFFB7F0B1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEBEFEB),
          thickness: 1,
          space: 1,
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: _darkColorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: _darkColorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 2,
        ),
      );
}
