import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY';
  static const String _definedSupabaseUrl = String.fromEnvironment(
    supabaseUrlKey,
  );
  static const String _definedSupabaseAnonKey = String.fromEnvironment(
    supabaseAnonKey,
  );

  static bool _isInitialized = false;

  static bool get isConfigured {
    final url = _configValue(supabaseUrlKey);
    final anonKey = _configValue(supabaseAnonKey);
    return url.isNotEmpty && anonKey.isNotEmpty && configurationWarning == null;
  }

  static String? get configurationWarning {
    final url = _configValue(supabaseUrlKey);
    final anonKey = _configValue(supabaseAnonKey);
    if (url.isEmpty || anonKey.isEmpty) {
      return 'Hesap ve yedekleme servisi su an hazir degil.';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Hesap ve yedekleme servisi ayari gecersiz gorunuyor.';
    }
    if (uri.host == 'supabase.com' || uri.path.contains('/dashboard/')) {
      return 'Hesap ve yedekleme servisi ayari gecersiz gorunuyor.';
    }
    if (!uri.host.endsWith('.supabase.co')) {
      return 'Hesap ve yedekleme servisi ayari gecersiz gorunuyor.';
    }

    return null;
  }

  static String _configValue(String key) {
    final definedValue = switch (key) {
      supabaseUrlKey => _definedSupabaseUrl,
      supabaseAnonKey => _definedSupabaseAnonKey,
      _ => '',
    };
    if (definedValue.trim().isNotEmpty) {
      return definedValue.trim();
    }

    if (!dotenv.isInitialized) {
      return '';
    }

    return dotenv.maybeGet(key)?.trim() ?? '';
  }

  static bool get isInitialized => _isInitialized;

  static SupabaseClient? get client {
    if (!_isInitialized) {
      return null;
    }
    return Supabase.instance.client;
  }

  static User? get currentUser => client?.auth.currentUser;

  static Stream<AuthState>? get authStateChanges =>
      client?.auth.onAuthStateChange;

  static String? validateEmailAndPassword({
    required String email,
    required String password,
  }) {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return 'E-posta adresini yazmalisin.';
    }

    if (password.length < 6) {
      return 'Sifre en az 6 karakter olmali.';
    }

    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmedEmail)) {
      return 'E-posta adresi hatali gorunuyor. Ornek: adiniz@gmail.com';
    }

    final domain = trimmedEmail.split('@').last.toLowerCase();
    const suggestions = <String, String>{
      'gmai.com': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmail.con': 'gmail.com',
      'hotmial.com': 'hotmail.com',
      'hotmai.com': 'hotmail.com',
      'outlok.com': 'outlook.com',
    };
    final suggestion = suggestions[domain];
    if (suggestion != null) {
      return 'E-posta adresini kontrol et: "$suggestion" mu demek istedin?';
    }

    return null;
  }

  static String friendlyAuthError(Object error) {
    final message = error.toString();
    if (message.contains('DOCTYPE') || message.contains('Failed to decode')) {
      return 'Hesap servisi su an yanit vermiyor. Lutfen daha sonra tekrar deneyin.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya sifre hatali.';
    }
    if (message.contains('invalid_email') ||
        message.contains('Unable to validate email address') ||
        message.contains('Email address') && message.contains('invalid')) {
      return 'E-posta adresi gecersiz gorunuyor. Adresi kontrol edip tekrar dene.';
    }
    if (message.contains('User already registered')) {
      return 'Bu e-posta ile zaten hesap var. Giris yapmayi deneyin.';
    }
    if (message.contains('Email signups are disabled') ||
        message.contains('email_provider_disabled')) {
      return 'E-posta ile hesap olusturma su an kapali. Lutfen daha sonra tekrar deneyin.';
    }
    if (message.contains('over_email_send_rate_limit') ||
        message.contains('email rate limit exceeded') ||
        message.contains('429')) {
      return 'E-posta gonderim limiti doldu. Hesap olusmus olabilir; Giris yap sekmesini deneyin veya birkac dakika sonra tekrar deneyin.';
    }
    if (message.contains('Email not confirmed')) {
      return 'E-posta onayi bekleniyor. Gelen kutusundaki onay linkine tiklayin.';
    }

    return message.replaceFirst(RegExp(r'^[^:]+Exception:?\s*'), '');
  }

  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final supabase = client;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    return supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    final supabase = client;
    if (supabase == null) {
      return;
    }

    await supabase.auth.signOut();
  }

  static Future<void> init() async {
    if (_isInitialized || !isConfigured) {
      return;
    }

    try {
      await Supabase.initialize(
        url: _configValue(supabaseUrlKey),
        anonKey: _configValue(supabaseAnonKey),
      );
      _isInitialized = true;
    } on Object catch (error, stackTrace) {
      _isInitialized = false;
      debugPrint('Supabase init skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
