import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/build_config.dart';

/// Secure credential management service
/// Handles loading credentials from environment variables and secure storage
class CredentialService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static bool _isInitialized = false;
  static String? _supabaseUrl;
  static String? _supabaseAnonKey;
  static String? _pdfshiftApiKey;

  /// Initialize credential service
  /// Loads credentials from build-time config, environment variables, and secure storage
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Priority 1: Build-time configuration (most secure)
      _supabaseUrl = BuildConfig.supabaseUrl;
      _supabaseAnonKey = BuildConfig.supabaseAnonKey;
      _pdfshiftApiKey = BuildConfig.pdfshiftApiKey;

      // Priority 2: Environment variables from .env file
      if (_supabaseUrl == null || _supabaseAnonKey == null) {
        try {
          await dotenv.load(fileName: ".env");
          _supabaseUrl ??= dotenv.env['SUPABASE_URL'];
          _supabaseAnonKey ??= dotenv.env['SUPABASE_ANON_KEY'];
          _pdfshiftApiKey ??= dotenv.env['PDFSHIFT_API_KEY'];
        } catch (e) {
          // .env file not found or invalid - this is normal for first setup
          print('Info: .env file not found. Please create one with your Supabase credentials.');
        }
      }

      // Priority 3: Secure storage (for runtime updates)
      if (_supabaseUrl == null || _supabaseAnonKey == null) {
        try {
          _supabaseUrl ??= await _secureStorage.read(key: 'supabase_url');
          _supabaseAnonKey ??= await _secureStorage.read(key: 'supabase_anon_key');
        } catch (e) {
          // Secure storage not available - this is normal in some environments
          print('Info: Secure storage not available. Using environment variables only.');
        }
      }

      if (_pdfshiftApiKey == null) {
        try {
          _pdfshiftApiKey = await _secureStorage.read(key: 'pdfshift_api_key');
        } catch (e) {
          // Secure storage not available - continue without PDFShift key
        }
      }

      _isInitialized = true;
    } catch (e) {
      print('Error initializing credential service: $e');
      // Continue with null values - will be handled by validation
    }
  }

  /// Get Supabase URL
  static String? get supabaseUrl => _supabaseUrl;

  /// Get Supabase anonymous key
  static String? get supabaseAnonKey => _supabaseAnonKey;

  /// Get PDFShift API key
  static String? get pdfshiftApiKey => _pdfshiftApiKey;

  /// Validate that all required credentials are present
  static bool validateCredentials() {
    return _supabaseUrl != null && 
           _supabaseUrl!.isNotEmpty &&
           _supabaseAnonKey != null && 
           _supabaseAnonKey!.isNotEmpty;
  }

  /// Get validation error message
  static String getValidationError() {
    if (_supabaseUrl == null || _supabaseUrl!.isEmpty) {
      return '''Supabase URL is not configured.

To fix this:
1. Create a .env file in your project root
2. Add: SUPABASE_URL=https://your-project-id.supabase.co
3. Get your URL from: https://supabase.com/dashboard → Settings → API

Or use build-time configuration:
flutter run --dart-define=SUPABASE_URL=https://your-project-id.supabase.co''';
    }
    if (_supabaseAnonKey == null || _supabaseAnonKey!.isEmpty) {
      return '''Supabase anonymous key is not configured.

To fix this:
1. Create a .env file in your project root
2. Add: SUPABASE_ANON_KEY=your-anon-key-here
3. Get your key from: https://supabase.com/dashboard → Settings → API

Or use build-time configuration:
flutter run --dart-define=SUPABASE_ANON_KEY=your-anon-key-here''';
    }
    return 'Unknown credential validation error.';
  }

  /// Store credentials securely (for runtime updates)
  static Future<void> storeCredentials({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? pdfshiftApiKey,
  }) async {
    if (supabaseUrl != null) {
      await _secureStorage.write(key: 'supabase_url', value: supabaseUrl);
      _supabaseUrl = supabaseUrl;
    }
    if (supabaseAnonKey != null) {
      await _secureStorage.write(key: 'supabase_anon_key', value: supabaseAnonKey);
      _supabaseAnonKey = supabaseAnonKey;
    }
    if (pdfshiftApiKey != null) {
      await _secureStorage.write(key: 'pdfshift_api_key', value: pdfshiftApiKey);
      _pdfshiftApiKey = pdfshiftApiKey;
    }
  }

  /// Clear all stored credentials
  static Future<void> clearCredentials() async {
    await _secureStorage.deleteAll();
    _supabaseUrl = null;
    _supabaseAnonKey = null;
    _pdfshiftApiKey = null;
    _isInitialized = false;
  }

  /// Get app environment info for debugging
  static Future<Map<String, String>> getEnvironmentInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    
    return {
      'appName': packageInfo.appName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'packageName': packageInfo.packageName,
      'hasSupabaseUrl': (_supabaseUrl != null && _supabaseUrl!.isNotEmpty).toString(),
      'hasSupabaseKey': (_supabaseAnonKey != null && _supabaseAnonKey!.isNotEmpty).toString(),
      'hasPdfshiftKey': (_pdfshiftApiKey != null && _pdfshiftApiKey!.isNotEmpty).toString(),
    };
  }

  /// Check if running in debug mode
  static bool get isDebugMode {
    try {
      return dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Get app environment (development, staging, production)
  static String get appEnvironment {
    try {
      return dotenv.env['APP_ENV'] ?? 'development';
    } catch (e) {
      return 'development';
    }
  }
}
