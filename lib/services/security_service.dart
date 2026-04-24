import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';

class SecuritySnapshot {
  const SecuritySnapshot({
    required this.hasPin,
    required this.biometricsEnabled,
    required this.biometricsAvailable,
    required this.lockOnResume,
  });

  final bool hasPin;
  final bool biometricsEnabled;
  final bool biometricsAvailable;
  final bool lockOnResume;

  bool get appLockConfigured => hasPin;
}

class SecurityService {
  static const _encryptionKeyKey = 'security.hive.encryption_key.v1';
  static const _storageMigratedKey = 'security.hive.migrated.v1';
  static const _pinSaltKey = 'security.pin.salt.v1';
  static const _pinHashKey = 'security.pin.hash.v1';
  static const _biometricsEnabledKey = 'security.biometrics.enabled.v1';
  static const _lockOnResumeKey = 'security.lock_on_resume.v1';

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static bool _useInMemoryFallback = false;
  static final Map<String, String> _memoryStore = <String, String>{};

  static Future<void> init() async {
    await getOrCreateEncryptionKey();
  }

  static void enableInMemoryFallbackForTests() {
    _useInMemoryFallback = true;
    _memoryStore.clear();
  }

  static void resetTestState() {
    _memoryStore.clear();
    _useInMemoryFallback = false;
  }

  static Future<List<int>> getOrCreateEncryptionKey() async {
    final existingKey = await _read(_encryptionKeyKey);
    if (existingKey != null && existingKey.isNotEmpty) {
      return base64Decode(existingKey);
    }

    final newKey = Hive.generateSecureKey();
    await _write(_encryptionKeyKey, base64Encode(newKey));
    return newKey;
  }

  static Future<bool> needsStorageMigration() async {
    final migrated = await _read(_storageMigratedKey);
    return migrated != 'true';
  }

  static Future<void> markStorageMigrationComplete() async {
    await _write(_storageMigratedKey, 'true');
  }

  static Future<void> setPin(String pin) async {
    final normalizedPin = pin.trim();
    final salt = _generateSalt();
    final hash = _hashPin(normalizedPin, salt);

    await _write(_pinSaltKey, salt);
    await _write(_pinHashKey, hash);
  }

  static Future<void> removePin() async {
    await _delete(_pinSaltKey);
    await _delete(_pinHashKey);
    await setBiometricsEnabled(false);
    await setLockOnResume(false);
  }

  static Future<bool> hasPin() async {
    final hash = await _read(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  static Future<bool> verifyPin(String pin) async {
    final salt = await _read(_pinSaltKey);
    final expectedHash = await _read(_pinHashKey);
    if (salt == null || expectedHash == null) {
      return false;
    }

    return _hashPin(pin.trim(), salt) == expectedHash;
  }

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        return false;
      }

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics({
    String reason = 'Uygulamanın kilidini açmak için kimliğinizi doğrulayın',
  }) async {
    try {
      if (!await canUseBiometrics()) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBiometricsEnabled() async {
    final value = await _read(_biometricsEnabledKey);
    return value == 'true';
  }

  static Future<void> setBiometricsEnabled(bool enabled) async {
    await _write(_biometricsEnabledKey, enabled ? 'true' : 'false');
  }

  static Future<bool> shouldLockOnResume() async {
    final value = await _read(_lockOnResumeKey);
    if (value == null) {
      return true;
    }

    return value == 'true';
  }

  static Future<void> setLockOnResume(bool enabled) async {
    await _write(_lockOnResumeKey, enabled ? 'true' : 'false');
  }

  static Future<SecuritySnapshot> getSnapshot() async {
    final hasPinValue = await hasPin();
    final biometricsAvailableValue = await canUseBiometrics();
    final biometricsEnabledValue = hasPinValue && await isBiometricsEnabled();
    final lockOnResumeValue = hasPinValue && await shouldLockOnResume();

    return SecuritySnapshot(
      hasPin: hasPinValue,
      biometricsEnabled: biometricsEnabledValue,
      biometricsAvailable: biometricsAvailableValue,
      lockOnResume: lockOnResumeValue,
    );
  }

  static String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  static String _generateSalt() {
    final bytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    return base64Encode(bytes);
  }

  static Future<String?> _read(String key) async {
    if (_useInMemoryFallback) {
      return _memoryStore[key];
    }

    try {
      return await _storage.read(key: key);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> _write(String key, String value) async {
    if (_useInMemoryFallback) {
      _memoryStore[key] = value;
      return;
    }

    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      rethrow;
    }
  }

  static Future<void> _delete(String key) async {
    if (_useInMemoryFallback) {
      _memoryStore.remove(key);
      return;
    }

    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      rethrow;
    }
  }
}
