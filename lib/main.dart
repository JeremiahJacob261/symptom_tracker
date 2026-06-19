import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:symptom_tracker/services/ai_insight_service.dart';
import 'package:symptom_tracker/services/app_backend.dart';
import 'package:symptom_tracker/services/health_analytics.dart';
import 'package:symptom_tracker/data/symptom_taxonomy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
  unawaited(
    AppBackend.bootstrap().catchError((Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('Backend bootstrap failed after app launch: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }),
  );
}

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('darkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _isDark);
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

String _preferredTemperatureUnit(BuildContext context) {
  return Localizations.localeOf(context).countryCode == 'US' ? 'F' : 'C';
}

class UserService {
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName');
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await AppBackend.updateProfileName(name);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (BuildContext context, _) {
        return MaterialApp(
          title: 'Symptom Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          home: const AppLaunchGate(),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF007C78),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFC7F0EA),
        onPrimaryContainer: Color(0xFF063F3D),
        secondary: Color(0xFF4B83A6),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFD7EAF6),
        onSecondaryContainer: Color(0xFF14384F),
        tertiary: Color(0xFFE6A23C),
        onTertiary: Color(0xFF2D1B00),
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF172121),
        onSurfaceVariant: Color(0xFF5D6A6A),
        error: Color(0xFFC62828),
        onError: Colors.white,
        outline: Color(0xFFC4D0D0),
      ),
      scaffoldBackgroundColor: const Color(0xFFF6FAF9),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6FAF9),
        foregroundColor: Color(0xFF172121),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF007C78),
        unselectedItemColor: Color(0xFF5D6A6A),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF007C78),
        inactiveTrackColor: const Color(0xFFE0E0E0),
        thumbColor: const Color(0xFF007C78),
        overlayColor: const Color(0xFF007C78).withValues(alpha: 0.12),
        trackHeight: 8,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F5F5),
        selectedColor: const Color(0xFFC7F0EA),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF212121),
        ),
        secondaryLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF063F3D)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007C78), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007C78),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF007C78),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFF007C78)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
            letterSpacing: 0),
        headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121)),
        headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121)),
        titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121)),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
            letterSpacing: 0),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF212121),
            letterSpacing: 0),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF212121),
            letterSpacing: 0),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF757575),
            letterSpacing: 0),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
            letterSpacing: 0),
      )),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF72D3C9),
        onPrimary: Color(0xFF053A38),
        primaryContainer: Color(0xFF0E504D),
        onPrimaryContainer: Color(0xFFC7F0EA),
        secondary: Color(0xFF9CCAE4),
        onSecondary: Color(0xFF113448),
        secondaryContainer: Color(0xFF224D66),
        onSecondaryContainer: Color(0xFFD7EAF6),
        tertiary: Color(0xFFF0B45B),
        onTertiary: Color(0xFF2D1B00),
        surface: Color(0xFF101818),
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFBDBDBD),
        error: Color(0xFFEF5350),
        onError: Colors.black,
        outline: Color(0xFF405454),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1111),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Color(0xFF4DB6AC),
        unselectedItemColor: Color(0xFF757575),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF4DB6AC),
        inactiveTrackColor: const Color(0xFF424242),
        thumbColor: const Color(0xFF4DB6AC),
        overlayColor: const Color(0xFF4DB6AC).withValues(alpha: 0.12),
        trackHeight: 8,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        selectedColor: const Color(0xFF004D40),
        labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFFFFFF)),
        secondaryLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB2DFDB)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4DB6AC),
          foregroundColor: const Color(0xFF00332C),
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4DB6AC),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0xFF4DB6AC)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0),
        headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFFFFF)),
        headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF)),
        titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFFFFFF)),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFFBDBDBD),
            letterSpacing: 0),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFFFFFF),
            letterSpacing: 0),
      )),
    );
  }
}

class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  static const _onboardingCompleteKey = 'onboardingComplete';
  bool _showSplash = true;
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _loadLaunchState();
  }

  Future<void> _loadLaunchState() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool(_onboardingCompleteKey) ?? false;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _onboardingComplete = complete;
      _showSplash = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (!mounted) return;
    setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash || _onboardingComplete == null) {
      return const SplashScreen();
    }
    if (_onboardingComplete == false) {
      return OnboardingScreen(onComplete: _completeOnboarding);
    }
    return const MainScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.health_and_safety_outlined,
                  color: theme.colorScheme.onPrimary,
                  size: 46,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Symptom Tracker',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track patterns. Share clearer health notes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _OnboardingPageData(
      icon: Icons.edit_note_outlined,
      title: 'Record symptoms clearly',
      body:
          'Log pain, body area, mood, temperature, and symptoms in one focused flow.',
    ),
    _OnboardingPageData(
      icon: Icons.insights_outlined,
      title: 'Understand patterns over time',
      body:
          'Use timeline, statistics, and insights to notice changes you can discuss with a clinician.',
    ),
    _OnboardingPageData(
      icon: Icons.privacy_tip_outlined,
      title: 'Keep health context grounded',
      body:
          'This app helps organize personal health notes. It does not diagnose or replace medical advice.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index == _pages.length - 1) {
      await widget.onComplete();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Symptom Tracker',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            page.icon,
                            size: 54,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final selected = _index == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _next,
                child: Text(
                    _index == _pages.length - 1 ? 'Get started' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    StatsScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home_outlined, Icons.home, 'Log', 0),
                _buildNavItem(
                    Icons.history_outlined, Icons.history, 'Timeline', 1),
                _buildNavItem(
                    Icons.bar_chart_outlined, Icons.bar_chart, 'Stats', 2),
                _buildNavItem(
                    Icons.lightbulb_outline, Icons.lightbulb, 'Insights', 3),
                _buildNavItem(
                    Icons.settings_outlined, Icons.settings, 'Settings', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== DATABASE ====================

class DatabaseHelper {
  static Future<int> insertEntry(Map<String, dynamic> entry) async {
    final id = await AppBackend.repository.insertEntry(entry);
    AppBackend.syncSoon();
    return id;
  }

  static Future<List<Map<String, dynamic>>> getEntries() async {
    AppBackend.syncSoon();
    return AppBackend.repository.getEntries();
  }

  static Future<int> deleteEntry(int id) async {
    final result = await AppBackend.repository.deleteEntry(id);
    AppBackend.syncSoon();
    return result;
  }

  static Future<int> insertMedication(Map<String, dynamic> med) async {
    final id = await AppBackend.repository.insertMedication(med);
    AppBackend.syncSoon();
    return id;
  }

  static Future<List<Map<String, dynamic>>> getMedications() async {
    AppBackend.syncSoon();
    return AppBackend.repository.getMedications();
  }

  static Future<int> updateMedication(int id, Map<String, dynamic> med) async {
    final result = await AppBackend.repository.updateMedication(id, med);
    AppBackend.syncSoon();
    return result;
  }

  static Future<int> deleteMedication(int id) async {
    final result = await AppBackend.repository.deleteMedication(id);
    AppBackend.syncSoon();
    return result;
  }

  static Future<int> insertAppointment(Map<String, dynamic> apt) async {
    final id = await AppBackend.repository.insertAppointment(apt);
    AppBackend.syncSoon();
    return id;
  }

  static Future<List<Map<String, dynamic>>> getAppointments() async {
    AppBackend.syncSoon();
    return AppBackend.repository.getAppointments();
  }

  static Future<int> deleteAppointment(int id) async {
    final result = await AppBackend.repository.deleteAppointment(id);
    AppBackend.syncSoon();
    return result;
  }
}

// ==================== HOME SCREEN ====================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _painLevel = 5;
  String? _selectedBodyArea;
  String? _selectedMood;
  final Set<String> _selectedSymptoms = {};
  final _notesController = TextEditingController();
  final _customSymptomsController = TextEditingController();
  final _temperatureController = TextEditingController();
  String _temperatureUnit = 'C';
  bool _temperatureUnitInitialized = false;
  String? _photoPath;
  String? _photoBytesBase64;
  Uint8List? _photoPreviewBytes;
  String? _userName;

  final List<String> _bodyAreas = [
    'Head',
    'Neck',
    'Shoulder',
    'Chest',
    'Back',
    'Lower Back',
    'Arm',
    'Elbow',
    'Wrist',
    'Hand',
    'Hip',
    'Leg',
    'Knee',
    'Ankle',
    'Foot'
  ];

  final Map<String, IconData> _moodIcons = {
    'Happy': Icons.sentiment_satisfied_outlined,
    'Calm': Icons.spa_outlined,
    'Neutral': Icons.sentiment_neutral_outlined,
    'Tired': Icons.nights_stay_outlined,
    'Stressed': Icons.cloud_outlined,
    'Anxious': Icons.warning_amber_outlined,
    'Sad': Icons.sentiment_dissatisfied_outlined,
    'Irritable': Icons.sentiment_very_dissatisfied_outlined,
  };

  final List<String> _moods = [
    'Happy',
    'Calm',
    'Neutral',
    'Tired',
    'Stressed',
    'Anxious',
    'Sad',
    'Irritable'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_temperatureUnitInitialized) return;
    final locale = Localizations.localeOf(context);
    _temperatureUnit = locale.countryCode == 'US' ? 'F' : 'C';
    _temperatureUnitInitialized = true;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customSymptomsController.dispose();
    _temperatureController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await UserService.getUserName();
    setState(() => _userName = name);
  }

  Color _getPainColor(double level) {
    if (level <= 2) return const Color(0xFF4CAF50);
    if (level <= 4) return const Color(0xFFFBC02D);
    if (level <= 6) return const Color(0xFFFF9800);
    if (level <= 8) return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }

  double? _readTemperatureCelsius() {
    final raw = _temperatureController.text.trim();
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null) return null;
    return celsiusFromInput(value, _temperatureUnit);
  }

  String _getPainLabel(double level) {
    if (level <= 1) return 'None';
    if (level <= 3) return 'Mild';
    if (level <= 5) return 'Moderate';
    if (level <= 7) return 'Distressing';
    if (level <= 9) return 'Severe';
    return 'Extreme';
  }

  Color _symptomChipForegroundColor(ThemeData theme, bool isSelected) {
    if (isSelected) return theme.colorScheme.onPrimaryContainer;
    return theme.brightness == Brightness.dark
        ? const Color(0xFFF5F7FA)
        : const Color(0xFF1F2937);
  }

  Color _symptomChipBackgroundColor(ThemeData theme, bool isSelected) {
    if (isSelected) return theme.colorScheme.primaryContainer;
    return theme.brightness == Brightness.dark
        ? const Color(0xFF2B3035)
        : const Color(0xFFFFFFFF);
  }

  BorderSide _symptomChipBorder(ThemeData theme, bool isSelected) {
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.9 : 0.7,
          );
    return BorderSide(color: color);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final bytes = kIsWeb ? await image.readAsBytes() : null;
      setState(() {
        _photoPath = image.path;
        _photoPreviewBytes = bytes;
        _photoBytesBase64 = bytes == null ? null : base64Encode(bytes);
      });
    }
  }

  Future<void> _saveEntry() async {
    if (_selectedBodyArea == null || _selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select body area and mood')),
      );
      return;
    }

    final temperatureCelsius = _readTemperatureCelsius();
    if (_temperatureController.text.trim().isNotEmpty &&
        temperatureCelsius == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid body temperature')),
      );
      return;
    }

    await DatabaseHelper.insertEntry({
      'pain_level': _painLevel.round(),
      'body_area': _selectedBodyArea,
      'mood': _selectedMood,
      'symptoms_json': jsonEncode(_selectedSymptoms.toList()),
      'custom_symptoms': _customSymptomsController.text.trim(),
      'temperature_celsius': temperatureCelsius,
      'notes': _notesController.text,
      'photo_path': _photoPath,
      'photo_bytes_base64': _photoBytesBase64,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    setState(() {
      _painLevel = 5;
      _selectedBodyArea = null;
      _selectedMood = null;
      _selectedSymptoms.clear();
      _notesController.clear();
      _customSymptomsController.clear();
      _temperatureController.clear();
      _photoPath = null;
      _photoBytesBase64 = null;
      _photoPreviewBytes = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Entry saved successfully!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showNameDialog() async {
    final controller = TextEditingController(text: _userName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Set Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: Icon(Icons.person),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await UserService.setUserName(result);
      setState(() => _userName = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final painColor = _getPainColor(_painLevel);

    return CustomScrollView(
      slivers: [
        // SliverAppBar with greeting
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          elevation: 0,
          backgroundColor: theme.scaffoldBackgroundColor,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _userName != null
                                ? 'Log today, ${_userName ?? ''}'
                                : 'Log symptoms',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.72,
                            child: Text(
                              'Record symptoms, mood, and body area to track health trends over time.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _showNameDialog,
                        icon: Icon(
                          _userName != null ? Icons.person : Icons.person_add,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        iconSize: 24,
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Pain Level Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pain Level',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: painColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getPainLabel(_painLevel),
                            style: TextStyle(
                              color: painColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: SliderTheme(
                            data: theme.sliderTheme.copyWith(
                              activeTrackColor: painColor,
                              thumbColor: painColor,
                            ),
                            child: Slider(
                              value: _painLevel,
                              min: 0,
                              max: 10,
                              divisions: 10,
                              onChanged: (value) =>
                                  setState(() => _painLevel = value),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                painColor,
                                painColor.withValues(alpha: 0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: painColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _painLevel.round().toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0', style: theme.textTheme.bodySmall),
                        Text('10', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Symptom Categories Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Symptoms',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose all symptoms you are experiencing today.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...symptomCategories.map((category) {
                      return Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: Text(
                            category.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${category.symptoms.length} common symptoms',
                            style: theme.textTheme.bodySmall,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: category.symptoms.map((symptom) {
                                  final isSelected =
                                      _selectedSymptoms.contains(symptom);
                                  final labelColor =
                                      _symptomChipForegroundColor(
                                          theme, isSelected);
                                  return FilterChip(
                                    backgroundColor:
                                        _symptomChipBackgroundColor(
                                            theme, false),
                                    selectedColor: _symptomChipBackgroundColor(
                                        theme, true),
                                    checkmarkColor:
                                        theme.colorScheme.onPrimaryContainer,
                                    side: _symptomChipBorder(theme, isSelected),
                                    labelStyle: TextStyle(
                                      color: labelColor,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                    label: Text(symptom),
                                    selected: isSelected,
                                    onSelected: (selected) => setState(() {
                                      if (selected) {
                                        _selectedSymptoms.add(symptom);
                                      } else {
                                        _selectedSymptoms.remove(symptom);
                                      }
                                    }),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customSymptomsController,
                      decoration: const InputDecoration(
                        labelText: 'Other symptoms',
                        hintText: 'Add anything not listed above',
                        prefixIcon: Icon(Icons.note_add_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Temperature Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Body Temperature',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Optional, but useful when fever or chills are present.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _temperatureController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  _temperatureUnit == 'F' ? '98.6' : '37.0',
                              prefixIcon: const Icon(Icons.thermostat_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'C', label: Text('C')),
                            ButtonSegment(value: 'F', label: Text('F')),
                          ],
                          selected: {_temperatureUnit},
                          onSelectionChanged: (value) => setState(
                            () => _temperatureUnit = value.first,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Body Area Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Body Area',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select where you are experiencing symptoms.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _bodyAreas.map((area) {
                        final isSelected = _selectedBodyArea == area;
                        final labelColor =
                            _symptomChipForegroundColor(theme, isSelected);
                        return ChoiceChip(
                          backgroundColor:
                              _symptomChipBackgroundColor(theme, false),
                          selectedColor:
                              _symptomChipBackgroundColor(theme, true),
                          checkmarkColor: theme.colorScheme.onPrimaryContainer,
                          side: _symptomChipBorder(theme, isSelected),
                          labelStyle: TextStyle(
                            color: labelColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Icon(Icons.check,
                                    size: 16,
                                    color:
                                        theme.colorScheme.onPrimaryContainer),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                area,
                                style: TextStyle(color: labelColor),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedBodyArea = area),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Mood Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mood can correlate with symptoms and pain patterns.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _moods.map((mood) {
                        final isSelected = _selectedMood == mood;
                        final labelColor =
                            _symptomChipForegroundColor(theme, isSelected);
                        return ChoiceChip(
                          backgroundColor:
                              _symptomChipBackgroundColor(theme, false),
                          selectedColor:
                              _symptomChipBackgroundColor(theme, true),
                          checkmarkColor: theme.colorScheme.onPrimaryContainer,
                          side: _symptomChipBorder(theme, isSelected),
                          labelStyle: TextStyle(
                            color: labelColor,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                          avatar: Icon(
                            _moodIcons[mood],
                            size: 18,
                            color: labelColor,
                          ),
                          label: Text(
                            mood,
                            style: TextStyle(color: labelColor),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedMood = mood),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Notes Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Add any additional details about how you feel...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Photo Card (if attached)
        if (_photoPath != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Photo Attached',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _photoPath = null;
                              _photoBytesBase64 = null;
                              _photoPreviewBytes = null;
                            }),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb && _photoPreviewBytes != null
                            ? Image.memory(
                                _photoPreviewBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_photoPath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Add Photo Button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Add Photo'),
            ),
          ),
        ),

        // Save Entry Button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ElevatedButton.icon(
              onPressed: _saveEntry,
              icon: const Icon(Icons.save, size: 20),
              label: const Text('Save Entry'),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== HISTORY SCREEN ====================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.getEntries();
    setState(() {
      _entries = entries;
      _filteredEntries = entries;
    });
  }

  void _filterEntries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEntries = _entries;
      } else {
        _filteredEntries = _entries.where((entry) {
          final symptoms = readEntrySymptoms(entry).join(' ');
          final customSymptoms = readCustomSymptoms(entry);
          final temperature = readTemperatureCelsius(entry)?.toString() ?? '';
          final text = ('${entry['body_area']} ${entry['mood']} '
                  '${entry['notes']} $symptoms $customSymptoms $temperature')
              .toLowerCase();
          return text.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Color _getPainColor(int level) {
    if (level <= 2) return const Color(0xFF4CAF50);
    if (level <= 4) return const Color(0xFFFBC02D);
    if (level <= 6) return const Color(0xFFFF9800);
    if (level <= 8) return const Color(0xFFFF5722);
    return const Color(0xFFF44336);
  }

  Future<void> _deleteEntry(int id) async {
    await DatabaseHelper.deleteEntry(id);
    _loadEntries();
  }

  Future<void> _showEntryDetails(Map<String, dynamic> entry) async {
    final theme = Theme.of(context);
    final date = DateTime.parse(entry['timestamp']);
    final painLevel = entry['pain_level'] as int;
    final painColor = _getPainColor(painLevel);
    final photoPath = entry['photo_path']?.toString();
    final photoBytes = entry['photo_bytes_base64']?.toString();
    final symptoms = readEntrySymptoms(entry);
    final customSymptoms = readCustomSymptoms(entry);
    final temperature = readTemperatureCelsius(entry);
    final temperatureUnit = _preferredTemperatureUnit(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: painColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$painLevel',
                            style: TextStyle(
                              color: painColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry['body_area']} - ${entry['mood']}',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy - HH:mm')
                                  .format(date),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    icon: Icons.monitor_heart_outlined,
                    label: 'Pain level',
                    value: '$painLevel/10',
                  ),
                  _DetailRow(
                    icon: Icons.place_outlined,
                    label: 'Body area',
                    value: entry['body_area']?.toString() ?? 'Not set',
                  ),
                  _DetailRow(
                    icon: Icons.mood_outlined,
                    label: 'Mood',
                    value: entry['mood']?.toString() ?? 'Not set',
                  ),
                  _DetailRow(
                    icon: Icons.thermostat_outlined,
                    label: 'Temperature',
                    value: formatTemperature(
                      temperature,
                      unit: temperatureUnit,
                    ),
                  ),
                  if (symptoms.isNotEmpty || customSymptoms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Symptoms',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...symptoms.map((symptom) => Chip(
                              label: Text(symptom),
                              avatar: const Icon(Icons.check_circle, size: 16),
                            )),
                        if (customSymptoms.isNotEmpty)
                          Chip(
                            label: Text(customSymptoms),
                            avatar: const Icon(Icons.add, size: 16),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text('Notes',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    (entry['notes']?.toString().isNotEmpty ?? false)
                        ? entry['notes'].toString()
                        : 'No notes added.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (photoPath != null && photoPath.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Photo',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb &&
                              photoBytes != null &&
                              photoBytes.isNotEmpty
                          ? Image.memory(
                              base64Decode(photoBytes),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : kIsWeb
                              ? Container(
                                  height: 96,
                                  color: theme.colorScheme.primaryContainer,
                                  alignment: Alignment.center,
                                  child: const Text('Photo synced remotely'),
                                )
                              : Image.file(
                                  File(photoPath),
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await _deleteEntry(entry['id'] as int);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Entry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _filterEntries,
              decoration: InputDecoration(
                hintText: 'Search entries...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterEntries('');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: _filteredEntries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No entries found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEntries.length,
              itemBuilder: (context, index) {
                final entry = _filteredEntries[index];
                final painLevel = entry['pain_level'] as int;
                final painColor = _getPainColor(painLevel);
                final date = DateTime.parse(entry['timestamp']);
                final symptoms = readEntrySymptoms(entry);
                final temperature = readTemperatureCelsius(entry);
                final temperatureUnit = _preferredTemperatureUnit(context);

                return Dismissible(
                  key: Key(entry['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteEntry(entry['id']),
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showEntryDetails(entry),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: painColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$painLevel/10',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry['body_area']} - ${entry['mood']}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const Spacer(),
                                if (entry['photo_path'] != null &&
                                    entry['photo_path'].toString().isNotEmpty)
                                  Icon(Icons.photo,
                                      size: 20,
                                      color: theme.colorScheme.primary),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(date),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (entry['notes'] != null &&
                                entry['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                entry['notes'],
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (symptoms.isNotEmpty || temperature != null) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (temperature != null)
                                    Chip(
                                      avatar: const Icon(
                                          Icons.thermostat_outlined,
                                          size: 16),
                                      label: Text(formatTemperature(
                                        temperature,
                                        unit: temperatureUnit,
                                      )),
                                    ),
                                  ...symptoms.take(3).map(
                                        (symptom) => Chip(
                                          label: Text(symptom),
                                        ),
                                      ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ==================== STATS SCREEN ====================

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.getEntries();
    setState(() => _entries = entries);
  }

  Widget _buildTrendChart() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
          Icons.bar_chart, 'No data yet', 'Add entries to see statistics');
    }

    final spots = _entries.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), (e.value['pain_level'] as int).toDouble());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pain Trend Over Time',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 30),
                      ),
                      bottomTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyOverview() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
          Icons.bar_chart, 'No data yet', 'Add entries to see statistics');
    }

    final theme = Theme.of(context);
    final stats = HealthAnalytics.weeklyStats(_entries);
    final trendIcon = switch (stats.trend) {
      'better' => Icons.trending_down,
      'worse' => Icons.trending_up,
      'same' => Icons.trending_flat,
      _ => Icons.help_outline,
    };
    final trendLabel = switch (stats.trend) {
      'better' => 'Better',
      'worse' => 'Worse',
      'same' => 'Same',
      _ => 'Unknown',
    };

    final items = [
      _StatItem(
        Icons.monitor_heart_outlined,
        'Avg pain this week',
        stats.averagePainThisWeek == null
            ? 'No logs'
            : '${stats.averagePainThisWeek!.toStringAsFixed(1)}/10',
      ),
      _StatItem(
        Icons.history_outlined,
        'Avg pain last week',
        stats.averagePainLastWeek == null
            ? 'No logs'
            : '${stats.averagePainLastWeek!.toStringAsFixed(1)}/10',
      ),
      _StatItem(
        Icons.mood_outlined,
        'Most common mood',
        stats.mostCommonMoodThisWeek ?? 'No logs',
      ),
      _StatItem(
        Icons.event_available_outlined,
        'Days logged',
        stats.daysLoggedThisWeek.toString(),
      ),
      _StatItem(trendIcon, 'Trend', trendLabel),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Overview',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'A simple comparison of this week and last week.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(item.icon,
                              color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.label,
                                style: theme.textTheme.bodyMedium),
                          ),
                          Text(
                            item.value,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
          Icons.bar_chart, 'No data yet', 'Add entries to see statistics');
    }

    final areaData = <String, List<int>>{};
    for (final entry in _entries) {
      final area = entry['body_area'] as String;
      final pain = entry['pain_level'] as int;
      areaData.putIfAbsent(area, () => []).add(pain);
    }

    final barGroups = areaData.entries.toList().asMap().entries.map((e) {
      final avg = e.value.value.reduce((a, b) => a + b) / e.value.value.length;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: avg,
            color: Theme.of(context).colorScheme.primary,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Avg Pain by Body Area',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 30),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < areaData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  areaData.keys
                                      .elementAt(index)
                                      .substring(0, 4),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    maxY: 10,
                    barGroups: barGroups,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomFrequency() {
    if (_entries.isEmpty) {
      return _buildEmptyState(
          Icons.checklist, 'No data yet', 'Add entries to see symptoms');
    }

    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final entry in _entries) {
      for (final symptom in readEntrySymptoms(entry)) {
        counts[symptom] = (counts[symptom] ?? 0) + 1;
      }
      final custom = readCustomSymptoms(entry);
      if (custom.isNotEmpty) {
        counts[custom] = (counts[custom] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) {
      return _buildEmptyState(Icons.checklist, 'No symptoms logged',
          'Select symptoms in new entries to see frequency');
    }

    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Symptom Frequency',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Most frequently selected symptoms across your entries.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ...rows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: theme.colorScheme.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child:
                              Text(row.key, style: theme.textTheme.bodyMedium),
                        ),
                        Text(
                          row.value.toString(),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_week), text: 'Week'),
            Tab(icon: Icon(Icons.show_chart), text: 'Trend'),
            Tab(icon: Icon(Icons.bar_chart), text: 'By Area'),
            Tab(icon: Icon(Icons.checklist), text: 'Symptoms'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyOverview(),
          _buildTrendChart(),
          _buildAreaChart(),
          _buildSymptomFrequency(),
        ],
      ),
    );
  }
}

// ==================== INSIGHTS SCREEN ====================

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<Map<String, dynamic>> _entries = [];
  InsightPayload? _insight;
  String _insightSource = 'Local fallback';
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper.getEntries();
    InsightPayload? payload;
    String source = 'Local fallback';

    final cached = await AppBackend.latestAiInsight();
    if (cached != null) {
      payload = _payloadFromCached(cached);
      source = 'Cached AI';
    } else {
      payload = HealthAnalytics.fallbackInsight(entries);
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _insight = payload;
      _insightSource = source;
    });
  }

  InsightPayload _payloadFromCached(Map<String, dynamic> row) {
    return InsightPayload.fromJson({
      'summary': row['summary'],
      'patterns': row['patterns'],
      'education': row['education'],
      'careGuidance': row['care_guidance'],
      'redFlags': row['red_flags'],
      'trend': row['trend'],
      'safetyStatus': row['safety_status'],
      'model': row['model'],
    });
  }

  Future<void> _generateAiInsight() async {
    if (_entries.isEmpty || _isGenerating) return;
    setState(() => _isGenerating = true);
    final payload = await AiInsightService.generate(entries: _entries);
    if (!mounted) return;
    setState(() {
      _insight = payload;
      _insightSource = payload.model == 'local-fallback'
          ? 'Local fallback'
          : 'Cloudflare AI';
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insight = _insight ?? HealthAnalytics.fallbackInsight(_entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          IconButton(
            onPressed: _loadEntries,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No data for analysis',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.psychology,
                              color: theme.colorScheme.primary, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Analysis',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '$_insightSource - based on ${_entries.length} entries',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed:
                                _isGenerating ? null : _generateAiInsight,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.auto_awesome),
                            tooltip: 'Generate AI insight',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInsightCard(
                    title: 'Weekly Summary',
                    icon: Icons.summarize_outlined,
                    children: [insight.summary],
                  ),
                  const SizedBox(height: 16),
                  _buildInsightCard(
                    title: 'Pattern Insights',
                    icon: Icons.timeline_outlined,
                    children: insight.patterns,
                  ),
                  const SizedBox(height: 16),
                  _buildInsightCard(
                    title: 'Educational Notes',
                    icon: Icons.school_outlined,
                    children: insight.education,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                insight.safetyStatus == 'urgent'
                                    ? Icons.warning_amber_outlined
                                    : Icons.health_and_safety_outlined,
                                color: insight.safetyStatus == 'urgent'
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'When to Seek Care',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...[
                            ...insight.redFlags,
                            ...insight.careGuidance,
                          ].map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('- $item',
                                  style: theme.textTheme.bodyMedium),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildQuickStats(),
                ],
              ),
            ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required IconData icon,
    required List<String> children,
  }) {
    final theme = Theme.of(context);
    final items = children.isEmpty ? ['No insight available yet.'] : children;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('- $item', style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final painLevels = _entries.map((e) => e['pain_level'] as int).toList();
    final avgPain = painLevels.reduce((a, b) => a + b) / painLevels.length;
    final maxPain = painLevels.reduce((a, b) => a > b ? a : b);

    final bodyAreas = <String, int>{};
    final moods = <String, int>{};
    final symptoms = <String, int>{};
    for (final entry in _entries) {
      bodyAreas[entry['body_area']] = (bodyAreas[entry['body_area']] ?? 0) + 1;
      moods[entry['mood']] = (moods[entry['mood']] ?? 0) + 1;
      for (final symptom in readEntrySymptoms(entry)) {
        symptoms[symptom] = (symptoms[symptom] ?? 0) + 1;
      }
      final custom = readCustomSymptoms(entry);
      if (custom.isNotEmpty) {
        symptoms[custom] = (symptoms[custom] ?? 0) + 1;
      }
    }

    final mostCommonArea =
        bodyAreas.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final mostCommonMood =
        moods.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final mostCommonSymptom = symptoms.isEmpty
        ? null
        : symptoms.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final stats = [
      _StatItem(Icons.format_list_numbered, 'Total Entries',
          _entries.length.toString()),
      _StatItem(Icons.trending_up, 'Average Pain',
          '${avgPain.toStringAsFixed(1)}/10'),
      _StatItem(Icons.warning, 'Highest Pain', '$maxPain/10'),
      _StatItem(Icons.place, 'Most Common', mostCommonArea),
      _StatItem(Icons.mood, 'Most Common', mostCommonMood),
      _StatItem(
          Icons.checklist, 'Most Common', mostCommonSymptom ?? 'No symptoms'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...stats.map((stat) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(stat.icon,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(stat.label,
                              style: Theme.of(context).textTheme.bodyMedium)),
                      Text(stat.value,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  _StatItem(this.icon, this.label, this.value);
}

// ==================== SETTINGS SCREEN ====================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await UserService.getUserName();
    setState(() => _userName = name);
  }

  Future<void> _exportCSV() async {
    final entries = await DatabaseHelper.getEntries();
    if (!mounted) return;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export')),
      );
      return;
    }

    final csvData = [
      [
        'Date',
        'Pain Level',
        'Body Area',
        'Mood',
        'Symptoms',
        'Other Symptoms',
        'Temperature (C)',
        'Notes'
      ],
      ...entries.map((e) => [
            e['timestamp'],
            e['pain_level'].toString(),
            e['body_area'],
            e['mood'],
            readEntrySymptoms(e).join('; '),
            readCustomSymptoms(e),
            readTemperatureCelsius(e)?.toStringAsFixed(1) ?? '',
            e['notes'] ?? '',
          ]),
    ];

    final csv = const ListToCsvConverter().convert(csvData);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/symptom_export.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: 'Symptom Tracker Export');
  }

  Future<void> _exportPDF() async {
    final entries = await DatabaseHelper.getEntries();
    if (!mounted) return;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to export')),
      );
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Symptom Tracker Report',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Pain',
                'Area',
                'Mood',
                'Symptoms',
                'Temp C',
                'Notes'
              ],
              data: entries
                  .map((e) => [
                        e['timestamp'].toString().substring(0, 16),
                        e['pain_level'].toString(),
                        e['body_area'].toString(),
                        e['mood'].toString(),
                        [
                          ...readEntrySymptoms(e),
                          if (readCustomSymptoms(e).isNotEmpty)
                            readCustomSymptoms(e),
                        ].join(', '),
                        readTemperatureCelsius(e)?.toStringAsFixed(1) ?? '',
                        (e['notes'] ?? '').toString(),
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/symptom_report.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Symptom Tracker Report');
  }

  Future<void> _showNameDialog() async {
    final controller = TextEditingController(text: _userName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Set Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'Enter your name', prefixIcon: Icon(Icons.person)),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await UserService.setUserName(result);
      setState(() => _userName = result);
    }
  }

  Future<void> _replayOnboarding() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OnboardingScreen(
          onComplete: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('onboardingComplete', true);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'General'),
            Tab(icon: Icon(Icons.medication), text: 'Meds'),
            Tab(icon: Icon(Icons.calendar_today), text: 'Calendar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(theme),
          const MedicationsTab(),
          const CalendarTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            title: const Text('Profile'),
            subtitle: Text(_userName ?? 'Tap to set your name'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showNameDialog,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.dark_mode,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            title: const Text('Dark Mode'),
            subtitle: const Text('Toggle between light and dark theme'),
            trailing: Switch(
              value: themeNotifier.isDark,
              onChanged: (_) => themeNotifier.toggle(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.file_download,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                title: const Text('Export to CSV'),
                subtitle: const Text('Share your data as spreadsheet'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportCSV,
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.picture_as_pdf,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                title: const Text('Export to PDF'),
                subtitle: const Text('Generate printable report'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _exportPDF,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.play_circle_outline,
                  color: theme.colorScheme.onSecondaryContainer),
            ),
            title: const Text('Replay onboarding'),
            subtitle: const Text('Review app purpose, tracking, and privacy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _replayOnboarding,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer),
            ),
            title: const Text('About'),
            subtitle: const Text('Symptom Tracker v1.0'),
          ),
        ),
      ],
    );
  }
}

// ==================== MEDICATIONS TAB ====================

class MedicationsTab extends StatefulWidget {
  const MedicationsTab({super.key});

  @override
  State<MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<MedicationsTab> {
  List<Map<String, dynamic>> _medications = [];

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    final meds = await DatabaseHelper.getMedications();
    setState(() => _medications = meds);
  }

  Future<void> _addMedication() async {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final freqController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Medication'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: dosageController,
                decoration: const InputDecoration(labelText: 'Dosage')),
            TextField(
                controller: freqController,
                decoration: const InputDecoration(labelText: 'Frequency')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (result == true) {
      await DatabaseHelper.insertMedication({
        'name': nameController.text,
        'dosage': dosageController.text,
        'frequency': freqController.text,
        'is_active': 1,
      });
      _loadMedications();
    }
  }

  Future<void> _toggleMedication(int id, bool isActive) async {
    await DatabaseHelper.updateMedication(id, {'is_active': isActive ? 1 : 0});
    _loadMedications();
  }

  Future<void> _deleteMedication(int id) async {
    await DatabaseHelper.deleteMedication(id);
    _loadMedications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _medications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medication,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No medications',
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _medications.length,
              itemBuilder: (context, index) {
                final med = _medications[index];
                final isActive = med['is_active'] == 1;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(med['name']),
                    subtitle: Text('${med['dosage']} - ${med['frequency']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: isActive,
                          onChanged: (v) => _toggleMedication(med['id'], v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteMedication(med['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedication,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==================== CALENDAR TAB ====================

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final apts = await DatabaseHelper.getAppointments();
    setState(() => _appointments = apts);
  }

  Future<void> _addAppointment() async {
    final titleController = TextEditingController();
    final doctorController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = _selectedDay ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title')),
            TextField(
                controller: doctorController,
                decoration: const InputDecoration(labelText: 'Doctor')),
            TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (result == true) {
      if (!mounted) return;
      await DatabaseHelper.insertAppointment({
        'title': titleController.text,
        'doctor': doctorController.text,
        'date': selectedDate.toIso8601String().split('T')[0],
        'time': selectedTime.format(context),
        'notes': notesController.text,
      });
      _loadAppointments();
    }
  }

  Future<void> _deleteAppointment(int id) async {
    await DatabaseHelper.deleteAppointment(id);
    _loadAppointments();
  }

  List<Map<String, dynamic>> _getAppointmentsForDay(DateTime day) {
    return _appointments.where((apt) {
      try {
        final aptDate = DateTime.parse(apt['date'].toString());
        return aptDate.year == day.year &&
            aptDate.month == day.month &&
            aptDate.day == day.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: _getAppointmentsForDay,
            calendarStyle: CalendarStyle(
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: Builder(
              builder: (BuildContext context) {
                final dayApts = _selectedDay != null
                    ? _getAppointmentsForDay(_selectedDay!)
                    : [];
                if (dayApts.isEmpty) {
                  return Center(
                    child: Text(
                      'No appointments',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayApts.length,
                  itemBuilder: (context, index) {
                    final apt = dayApts[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading:
                            Icon(Icons.event, color: theme.colorScheme.primary),
                        title: Text(apt['title']),
                        subtitle: Text('${apt['doctor']} - ${apt['time']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteAppointment(apt['id']),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAppointment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
