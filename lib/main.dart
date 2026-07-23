import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'core/config.dart';
import 'core/localization.dart';
import 'core/theme/design_tokens.dart';
import 'widgets/clarify_glass.dart';
import 'widgets/clarify_surface.dart';
import 'widgets/clarify_toast.dart';
import 'screens/desktop_planner_screen.dart';
import 'screens/onboarding_flow.dart';
// Вставь это где-то среди других импортов
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ------------------------------------------------
// 1. ПРИНИМАЕМ АРГУМЕНТЫ КОМАНДНОЙ СТРОКИ ДЛЯ SILENT BOOT
// --- ЗАМЕНИТЬ ФУНКЦИЮ main ПОЛНОСТЬЮ НА ЭТОТ КОД ---
Future<void> main(List<String> args) async {
  // 1. Обязательная инициализация Flutter ДО любых асинхронных вызовов
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Загружаем секреты из файла-сейфа
  await dotenv.load(fileName: ".env");

  // Дальше идет твой оригинальный код настройки
  final dir = await getApplicationDocumentsDirectory();
  Hive.init(dir.path);

  // --- НАСТРОЙКА WINDOWS УВЕДОМЛЕНИЙ ---
  await localNotifier.setup(
    appName: 'Clarify',
    shortcutPolicy: ShortcutPolicy.requireCreate, // Обязательно для Windows!
  );

  // Инициализация автозапуска
  launchAtStartup.setup(
    appName: 'Clarify', // <-- ЖЕСТКО ЗАДАЕМ ИМЯ БЕЗ ПРОБЕЛОВ
    appPath: Platform.resolvedExecutable,
    args: ['--autostart'], 
  );

  bool isAutostart = args.contains('--autostart');

  await Hive.initFlutter();
  await Hive.openBox('tasks_cache');
  await Hive.openBox('settings');
  await Hive.openBox('pending_ops');

  await hotKeyManager.unregisterAll();

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.scheme == 'clarify') {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    }
  });

  // 3. Подключаемся к базе, используя безопасные переменные окружения
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const SmartPlannerApp());

  doWhenWindowReady(() {
    const initialSize = Size(1000, 700);
    // Ниже 700 по ширине включается мобильная раскладка (см. DesktopPlannerScreen.build) —
    // минимум снижен, чтобы её можно было реально достичь сужением окна, а не только на вебе/телефоне.
    appWindow.minSize = const Size(360, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "Clarify";
    
    // 2. ЕСЛИ ЗАПУСТИЛАСЬ ВМЕСТЕ С WINDOWS - ПРЯЧЕМ ОКНО
    if (isAutostart) {
      appWindow.hide();
    } else {
      appWindow.show();
    }
  });
}
// --- КОНЕЦ ЗАМЕНЫ ---
class NoScrollbarBehavior extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class SmartPlannerApp extends StatefulWidget {
  const SmartPlannerApp({super.key});

  @override
  State<SmartPlannerApp> createState() => _SmartPlannerAppState();
}

class _SmartPlannerAppState extends State<SmartPlannerApp> with TrayListener {
  bool isDark = false;
  String currentLang = 'ru'; 
  
  StreamSubscription<AuthState>? _authSubscription;
  bool _isAuthenticated = false;
  bool _hasName = false;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _initTray();

    _hasSeenOnboarding = Hive.box('settings').get('has_seen_onboarding', defaultValue: false) as bool;

    final user = Supabase.instance.client.auth.currentUser;
    _isAuthenticated = user != null;
    _hasName = user?.userMetadata?['full_name'] != null && user!.userMetadata!['full_name'].toString().trim().isNotEmpty;
    if (user != null && user.userMetadata?['app_language'] != null) {
      currentLang = user.userMetadata!['app_language'];
    }
    if (user != null) _ensureProfile();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final currentUser = data.session?.user;
      if (mounted) {
        setState(() {
          _isAuthenticated = currentUser != null;
          _hasName = currentUser?.userMetadata?['full_name'] != null && currentUser!.userMetadata!['full_name'].toString().trim().isNotEmpty;
          if (currentUser != null && currentUser.userMetadata?['app_language'] != null) {
            currentLang = currentUser.userMetadata!['app_language'];
          }
        });
        if (currentUser != null) _ensureProfile();
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _authSubscription?.cancel();
    super.dispose();
  }

  // Создаёт/синхронизирует строку в Supabase `profiles` (код друга + имя/аватар) —
  // SOCIAL_PLAN.md §4.1. Fire-and-forget: ошибка (например, SQL из
  // profile_friend_code.sql ещё не применён вручную в Supabase) не должна
  // мешать входу в приложение.
  Future<void> _ensureProfile() async {
    try {
      await Supabase.instance.client.rpc('ensure_profile');
    } catch (e) {
      debugPrint('Не удалось синхронизировать профиль (код друга): $e');
    }
  }

  Future<void> _initTray() async {
    // Точный путь к файлу, который теперь 100% включен в сборку
    final String iconPath = Platform.isWindows ? 'assets/images/app_icon2.ico' : 'assets/images/tray_icon2.ico';
    await trayManager.setIcon(iconPath);

    await trayManager.setToolTip('Clarify');

    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_app', label: 'Развернуть / Restore'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Выход / Quit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() { appWindow.show(); appWindow.restore(); }
  @override
  void onTrayIconRightMouseDown() { trayManager.popUpContextMenu(); }
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_app') { 
      appWindow.show(); 
      appWindow.restore(); 
    } else if (menuItem.key == 'exit_app') { 
      exit(0); 
    }
  }

  void toggleTheme() { setState(() => isDark = !isDark); }

  void changeLang(String lang) async {
    setState(() => currentLang = lang);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'app_language': lang}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clarify',
      debugShowCheckedModeBanner: false,
      
      // === 🚀 МАГИЯ АБСОЛЮТНЫХ ПРОПОРЦИЙ ===
      // Жестко фиксируем масштаб шрифтов на 1.0. 
      // Теперь Windows не сможет раздуть текст на ноутбуках!
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), 
          ),
          child: child!,
        );
      },
      // ===========================================

      scrollBehavior: NoScrollbarBehavior(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Golos Text',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        extensions: const [ClarifyTokens.light],
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        fontFamily: 'Golos Text',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        extensions: const [ClarifyTokens.dark],
        useMaterial3: true,
      ),
      home: !_isAuthenticated
          ? (_hasSeenOnboarding
              ? AuthScreen(isDark: isDark, toggleTheme: toggleTheme, currentLang: currentLang, changeLang: changeLang)
              : OnboardingFlow(isDark: isDark, toggleTheme: toggleTheme, currentLang: currentLang, changeLang: changeLang))
          : (_hasName
              ? DesktopPlannerScreen(isDark: isDark, toggleTheme: toggleTheme, currentLang: currentLang, changeLang: changeLang)
              : SetupProfileScreen(isDark: isDark, toggleTheme: toggleTheme, currentLang: currentLang, changeLang: changeLang)),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final String currentLang;
  final Function(String) changeLang;
  final AuthMode initialMode;

  const AuthScreen({super.key, required this.isDark, required this.toggleTheme, required this.currentLang, required this.changeLang, this.initialMode = AuthMode.login});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, register }

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isOtpMode = false;
  // Настоящий шаг регистрации (REDESIGN_V3_PLAN.md §3.9/5.9) — «Войти» и
  // «Создать аккаунт» больше не одна и та же безмолвная форма: у регистрации
  // есть поле имени, которое уходит в профиль сразу после подтверждения кода.
  AuthMode _mode = AuthMode.login;

  bool get isDark => widget.isDark;
  
  String get bgImagePath => isDark 
    ? 'assets/images/bg_dark.jpg' 
    : 'assets/images/bg_light.jpg';

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      print('🔥 Поймали ссылку из браузера: $uri');
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.email,
        token: code,
        email: _emailController.text.trim(),
      );
      // Имя уходит в профиль сразу после подтверждения — SetupProfileScreen
      // для этой ветки не покажется (main.dart: _hasName сразу true).
      final name = _nameController.text.trim();
      if (_mode == AuthMode.register && name.isNotEmpty) {
        await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'full_name': name}));
      }
    } catch (e) {
      print('Ошибка верификации: $e'); 
      if (mounted) {
        ClarifyToast.show(context, 'Неверный код!'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final textMuted = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage(bgImagePath), fit: BoxFit.cover)),
        child: Center(
          child: SizedBox(
            width: 420,
            child: ClarifyGlass(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(40),
              child: _isOtpMode ? _buildOtpForm(textColor, textMuted) : _buildAuthForm(textColor, textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpForm(Color textColor, Color textMuted) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.mailOpen, size: 48, color: t.accent),
        const SizedBox(height: 16),
        Text("Подтверждение".tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        Text("Мы отправили 6-значный код на:\n${_emailController.text}".tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: textMuted, height: 1.5)),
        const SizedBox(height: 32),
        TextField(
          controller: _otpController, style: TextStyle(color: textColor, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold), 
          textAlign: TextAlign.center, maxLength: 8, keyboardType: TextInputType.number,
          decoration: InputDecoration(counterText: "", hintText: "00000000", hintStyle: TextStyle(color: textMuted.withOpacity(0.3)), filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8),
          onPressed: _isLoading ? null : _verifyOtp,
          child: _isLoading ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2)) : Text("Подтвердить".tr(widget.currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() { _isOtpMode = false; _otpController.clear(); }),
          child: Text("Вернуться назад".tr(widget.currentLang), style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  bool _isAuthInProgress = false;
  // Статус на весь путь входа через Яндекс (REDESIGN_V3_PLAN.md §3.10/5.10) —
  // кнопка блокируется и текст меняется по фазам, а не висит молча до 30 секунд.
  String? _yandexPhase;

  String? get _yandexStatusText {
    switch (_yandexPhase) {
      case 'waiting_browser':
        return 'Ждём подтверждения в браузере…'.tr(widget.currentLang);
      case 'verifying_backend':
        return 'Проверяем на сервере…'.tr(widget.currentLang);
      default:
        return null;
    }
  }

  Future<void> _loginWithYandex() async {
    if (_isAuthInProgress) return;

    setState(() { _isAuthInProgress = true; _yandexPhase = 'waiting_browser'; });
    debugPrint('!!! КНОПКА НАЖАТА, ЗАПУСКАЕМ СЕРВЕР !!!');

    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, AppConfig.yandexOAuthCallbackPort);
      debugPrint('Локальный сервер запущен на порту ${AppConfig.yandexOAuthCallbackPort}');

      final authUrl = Uri.https('oauth.yandex.ru', '/authorize', {
        'response_type': 'code',
        'client_id': AppConfig.yandexClientId,
        'redirect_uri': 'https://laghxzqqgxhspwcbbcml.supabase.co/functions/v1/vk-auth',
      });
      
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      await for (var request in server) {
        debugPrint('Получен запрос на путь: ${request.uri.path}'); 
        if (request.uri.path == '/') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''
              <html><body>
                <script>
                  const hash = window.location.hash.substring(1);
                  if (hash) {
                    window.location.href = '/token?' + hash;
                  } else {
                    document.body.innerHTML = '<h2>Ошибка: токен не найден</h2>';
                  }
                </script>
              </body></html>
            ''');
          await request.response.close();
        } else if (request.uri.path == '/token') {
          final code = request.uri.queryParameters['code'];
          
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html><body style="background:#1e1e1e; color:white; font-family:sans-serif; text-align:center; padding-top:50px;">
                <h2>Код успешно передан!</h2>
                <p>Можете закрыть эту вкладку и вернуться в приложение Clarify.</p>
                <script>setTimeout(() => window.close(), 1500);</script>
              </body></html>
            ''');
          await request.response.close();
          await server.close();

          if (code != null) {
            debugPrint('✅ КОД УСПЕШНО ПОЙМАН ВО FLUTTER: $code');
            if (mounted) setState(() => _yandexPhase = 'verifying_backend');
            await _sendCodeToFastAPI(code);
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('!!! ОШИБКА АВТОРИЗАЦИИ: $e');
      if (mounted) ClarifyToast.show(context, 'Ошибка авторизации. Попробуйте еще раз.'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
    } finally {
      if (mounted) setState(() { _isAuthInProgress = false; _yandexPhase = null; });
    }
  }

  Future<void> _sendCodeToFastAPI(String code) async {
    final backendUrl = Uri.parse('${AppConfig.backendBaseUrl}/auth/yandex');
    
    try {
      debugPrint('Отправляем код Яндекса на бэкенд...');
      
      final response = await http.post(
        backendUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Сервер Render слишком долго не отвечает.'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String yandexEmail = data["email"];
        final String yandexId = data["yandex_user_id"].toString();
        
        debugPrint('✅ Бэкенд подтвердил вход! Яндекс Email: $yandexEmail');

        final shadowPassword = "Yndx_${yandexId}_SecretPass123!";

        try {
          debugPrint('🔄 Синхронизируем Яндекса с Supabase...');
          await Supabase.instance.client.auth.signInWithPassword(
            email: yandexEmail,
            password: shadowPassword,
          );
          debugPrint('✅ Успешный вход в Supabase!');
        } on AuthException catch (e) {
          if (e.message.contains('Invalid login credentials')) {
            debugPrint('🆕 Создаем теневой аккаунт в Supabase...');
            await Supabase.instance.client.auth.signUp(
              email: yandexEmail,
              password: shadowPassword,
            );
            debugPrint('✅ Аккаунт создан и выполнен вход!');
          } else {
            throw Exception(e.message);
          }
        }

        // _isAuthInProgress/_yandexPhase сбрасываются в finally у _loginWithYandex,
        // который дожидается завершения этого метода — не дублируем здесь.
      } else {
        debugPrint('❌ Ошибка бэкенда: ${response.body}');
        if (mounted) ClarifyToast.show(context, 'Ошибка авторизации. Попробуйте еще раз.'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
      }
    } catch (e) {
      debugPrint('❌ Ошибка сети: $e');
      if (mounted) ClarifyToast.show(context, 'Ошибка сети. Проверьте интернет-соединение.'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
    }
  }

  Widget _buildAuthForm(Color textColor, Color textMuted) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Clarify", style: TextStyle(fontFamily: 'Unbounded', fontSize: 26, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.01)),
            IconButton(icon: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, color: textMuted), onPressed: widget.toggleTheme),
          ],
        ),
        const SizedBox(height: 8),
        Text("Войдите в систему или создайте аккаунт".tr(widget.currentLang), style: TextStyle(fontSize: 16, color: textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(child: AuthModeTab(label: "Войти".tr(widget.currentLang), active: _mode == AuthMode.login, textColor: textColor, accent: t.accent, onAccent: t.onAccent, onTap: () => setState(() => _mode = AuthMode.login))),
              Expanded(child: AuthModeTab(label: "Создать аккаунт".tr(widget.currentLang), active: _mode == AuthMode.register, textColor: textColor, accent: t.accent, onAccent: t.onAccent, onTap: () => setState(() => _mode = AuthMode.register))),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isAuthInProgress ? null : _loginWithYandex,
                  icon: _isAuthInProgress
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.logIn, size: 18),
                  label: Text(_yandexStatusText ?? 'Яндекс', overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black26)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("ИЛИ ПО EMAIL".tr(widget.currentLang), style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 12))),
            Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black26)),
          ],
        ),
        const SizedBox(height: 24),

        if (_mode == AuthMode.register) ...[
          TextField(
            controller: _nameController, style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: "Как вас зовут?".tr(widget.currentLang),
              labelStyle: TextStyle(color: textMuted),
              filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: Icon(LucideIcons.user, color: textMuted),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: _emailController, style: TextStyle(color: textColor), keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Ваш Email".tr(widget.currentLang),
            labelStyle: TextStyle(color: textMuted),
            filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            prefixIcon: Icon(LucideIcons.mail, color: textMuted),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.onAccent,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8
          ),
          onPressed: _isLoading ? null : () async {
            final email = _emailController.text.trim();
            if (email.isEmpty) {
              ClarifyToast.show(context, 'Введите Email!'.tr(widget.currentLang), variant: ClarifyToastVariant.warning);
              return;
            }
            if (_mode == AuthMode.register && _nameController.text.trim().isEmpty) {
              ClarifyToast.show(context, 'Как к вам обращаться?'.tr(widget.currentLang), variant: ClarifyToastVariant.warning);
              return;
            }
            setState(() => _isLoading = true);
            try {
              await Supabase.instance.client.auth.signInWithOtp(
                email: email,
                data: _mode == AuthMode.register ? {'full_name': _nameController.text.trim()} : null,
              );
              if (context.mounted) {
                ClarifyToast.show(context, 'Код отправлен на почту!'.tr(widget.currentLang), variant: ClarifyToastVariant.success);
                setState(() => _isOtpMode = true);
              }
            } catch (e) {
              if (context.mounted) ClarifyToast.show(context, 'Ошибка: $e'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
            } finally {
              if (context.mounted) setState(() => _isLoading = false);
            }
          },
          child: _isLoading
            ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
            : Text(
                (_mode == AuthMode.register ? "Создать аккаунт" : "Получить ссылку для входа").tr(widget.currentLang),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
        ),
      ],
    );
  }
}

class AuthModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color textColor;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;

  const AuthModeTab({super.key, required this.label, required this.active, required this.textColor, required this.accent, required this.onAccent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: ClarifyMotion.base,
        curve: ClarifyMotion.standard,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? accent : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: active ? onAccent : textColor, fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

class SetupProfileScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final String currentLang;          
  final Function(String) changeLang; 

  const SetupProfileScreen({super.key, required this.isDark, required this.toggleTheme, required this.currentLang, required this.changeLang});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _avatarUrl;
  Uint8List? _avatarBytes; 

  bool get isDark => widget.isDark;
  String get bgImagePath => isDark ? 'assets/images/bg_dark.jpg' : 'assets/images/bg_light.jpg';

  Future<void> _pickAndUploadAvatar() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, 
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _avatarBytes = result.files.single.bytes;
          _isLoading = true;
        });

        final fileBytes = result.files.single.bytes!;
        final fileExt = result.files.single.extension ?? 'png';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_avatar.$fileExt';

        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(fileName, fileBytes);

        final publicUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(fileName);

        setState(() => _avatarUrl = publicUrl);
      }
    } catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка загрузки: $e'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ClarifyToast.show(context, 'Как к вам обращаться?'.tr(widget.currentLang), variant: ClarifyToastVariant.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': name,
            if (_avatarUrl != null) 'avatar_url': _avatarUrl,
          },
        ),
      );

    } catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка: $e'.tr(widget.currentLang), variant: ClarifyToastVariant.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAvatar() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'avatar_url': null}, 
        ),
      );

      setState(() {
        _avatarUrl = null;
        _avatarBytes = null;
      });

      if (mounted) {
        ClarifyToast.show(context, "Аватарка успешно удалена".tr(widget.currentLang), variant: ClarifyToastVariant.success);
      }
    } catch (e) {
      if (mounted) {
        ClarifyToast.show(context, "Ошибка при удалении: $e".tr(widget.currentLang), variant: ClarifyToastVariant.danger);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAvatarMenu() {
    bool hasAvatar = _avatarBytes != null || _avatarUrl != null;
    final t = context.tokens;
    final textColor = t.text;

    showClarifySurface(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: t.surface2,
          title: Text(
            "Фото профиля".tr(widget.currentLang),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(LucideIcons.upload, color: t.accent),
                title: Text("Загрузить новое".tr(widget.currentLang), style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar();
                },
              ),

              if (hasAvatar) ...[
                const Divider(),
                ListTile(
                  leading: Icon(LucideIcons.trash2, color: t.danger),
                  title: Text(
                    "Удалить текущее".tr(widget.currentLang),
                    style: TextStyle(color: t.danger, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context); 
                    _deleteAvatar(); 
                  },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textMuted = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(image: DecorationImage(image: AssetImage(bgImagePath), fit: BoxFit.cover)),
        child: Center(
          child: SizedBox(
            width: 450,
            child: ClarifyGlass(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(40),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Добро пожаловать в".tr(widget.currentLang), style: TextStyle(fontSize: 16, color: textMuted, fontWeight: FontWeight.bold)),
                    Text("Clarify", style: TextStyle(fontFamily: 'Unbounded', fontSize: 30, fontWeight: FontWeight.w700, color: textColor, letterSpacing: -0.01)),
                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _isLoading ? null : _showAvatarMenu,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: t.surfaceSunken,
                            backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                            child: _avatarBytes == null
                                ? Icon(LucideIcons.user, size: 50, color: textMuted.withOpacity(0.5))
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.black87 : Colors.white, width: 2)),
                            child: Icon(LucideIcons.camera, size: 16, color: t.onAccent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "Ваше имя или никнейм".tr(widget.currentLang),
                        hintStyle: TextStyle(color: textMuted.withOpacity(0.5), fontWeight: FontWeight.normal),
                        filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                          ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                          : Text("Начать планирование".tr(widget.currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}


