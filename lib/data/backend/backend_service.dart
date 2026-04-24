import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackendService {
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY';

  static bool _isInitialized = false;

  static bool get isConfigured {
    if (!dotenv.isInitialized) {
      return false;
    }

    final url = dotenv.maybeGet(supabaseUrlKey)?.trim() ?? '';
    final anonKey = dotenv.maybeGet(supabaseAnonKey)?.trim() ?? '';
    return url.isNotEmpty && anonKey.isNotEmpty && configurationWarning == null;
  }

  static String? get configurationWarning {
    if (!dotenv.isInitialized) {
      return null;
    }

    final url = dotenv.maybeGet(supabaseUrlKey)?.trim() ?? '';
    final anonKey = dotenv.maybeGet(supabaseAnonKey)?.trim() ?? '';
    if (url.isEmpty || anonKey.isEmpty) {
      return 'SUPABASE_URL ve SUPABASE_ANON_KEY .env dosyasinda olmali.';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL gecersiz gorunuyor.';
    }
    if (uri.host == 'supabase.com' || uri.path.contains('/dashboard/')) {
      return 'SUPABASE_URL Dashboard linki degil, https://proje-ref.supabase.co formatinda olmali.';
    }
    if (!uri.host.endsWith('.supabase.co')) {
      return 'SUPABASE_URL https://proje-ref.supabase.co formatinda olmali.';
    }

    return null;
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

  static String friendlyAuthError(Object error) {
    final message = error.toString();
    if (message.contains('DOCTYPE') || message.contains('Failed to decode')) {
      return 'Supabase URL hatali gorunuyor. .env icindeki SUPABASE_URL https://proje-ref.supabase.co formatinda olmali.';
    }
    if (message.contains('Invalid login credentials')) {
      return 'E-posta veya sifre hatali.';
    }
    if (message.contains('User already registered')) {
      return 'Bu e-posta ile zaten hesap var. Giris yapmayi deneyin.';
    }
    if (message.contains('over_email_send_rate_limit') ||
        message.contains('email rate limit exceeded') ||
        message.contains('429')) {
      return 'E-posta gonderim limiti doldu. Hesap olusmus olabilir; Giris yap sekmesini deneyin veya birkac dakika sonra tekrar deneyin.';
    }
    if (message.contains('Email not confirmed')) {
      return 'E-posta onayi bekleniyor. Gelen kutusundaki Supabase onay linkine tiklayin.';
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
        url: dotenv.get(supabaseUrlKey),
        anonKey: dotenv.get(supabaseAnonKey),
      );
      _isInitialized = true;
    } catch (error, stackTrace) {
      _isInitialized = false;
      debugPrint('Supabase init skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
