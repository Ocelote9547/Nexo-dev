import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio de protección de acceso mediante PIN y biometría.
///
/// El PIN nunca se almacena en texto plano. Se guarda un verificador
/// derivado (PBKDF2-like mediante iteraciones de SHA-256) con una sal
/// aleatoria única por instalación, en almacenamiento seguro
/// (flutter_secure_storage).
class PrivacyService {
  static const _storageKeyPinHash = 'privacy_pin_hash';
  static const _storageKeyPinSalt = 'privacy_pin_salt';
  static const _storageKeyPinAttempts = 'privacy_pin_attempts';
  static const _storageKeyPinLockedUntil = 'privacy_pin_locked_until';

  static const _iterations = 10000;
  static const _maxAttempts = 5;
  static const _lockoutMinutes = 15;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// ¿Existe un PIN configurado?
  Future<bool> hasPin() async {
    final salt = await _storage.read(key: _storageKeyPinSalt);
    return salt != null && salt.isNotEmpty;
  }

  /// Configura un nuevo PIN. Devuelve false si el PIN es inválido.
  Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) return false;
    final salt = _generateSalt();
    final hash = _derive(pin, salt);
    await _storage.write(key: _storageKeyPinSalt, value: salt);
    await _storage.write(key: _storageKeyPinHash, value: hash);
    await _storage.delete(key: _storageKeyPinAttempts);
    await _storage.delete(key: _storageKeyPinLockedUntil);
    return true;
  }

  /// Verifica un PIN. Lanza [PinLockedException] si hay bloqueo activo.
  /// Devuelve true si el PIN es correcto.
  Future<bool> verifyPin(String pin) async {
    if (!_isValidPin(pin)) return false;

    final lockedUntilStr = await _storage.read(key: _storageKeyPinLockedUntil);
    if (lockedUntilStr != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilStr) ?? DateTime.now();
      if (DateTime.now().isBefore(lockedUntil)) {
        throw PinLockedException(lockedUntil);
      }
      // Bloqueo expirado: limpiar.
      await _storage.delete(key: _storageKeyPinLockedUntil);
      await _storage.delete(key: _storageKeyPinAttempts);
    }

    final storedHash = await _storage.read(key: _storageKeyPinHash);
    final salt = await _storage.read(key: _storageKeyPinSalt);
    if (storedHash == null || salt == null) return false;

    final inputHash = _derive(pin, salt);
    if (_constantTimeEquals(storedHash, inputHash)) {
      await _storage.delete(key: _storageKeyPinAttempts);
      return true;
    }

    // Fallo: incrementar intentos y posiblemente bloquear.
    final attemptsStr = await _storage.read(key: _storageKeyPinAttempts);
    final attempts = (int.tryParse(attemptsStr ?? '') ?? 0) + 1;
    await _storage.write(key: _storageKeyPinAttempts, value: attempts.toString());
    if (attempts >= _maxAttempts) {
      final until = DateTime.now().add(Duration(minutes: _lockoutMinutes));
      await _storage.write(key: _storageKeyPinLockedUntil, value: until.toIso8601String());
      throw PinLockedException(until);
    }
    return false;
  }

  /// Elimina el PIN (desactiva protección).
  Future<void> removePin() async {
    await _storage.delete(key: _storageKeyPinHash);
    await _storage.delete(key: _storageKeyPinSalt);
    await _storage.delete(key: _storageKeyPinAttempts);
    await _storage.delete(key: _storageKeyPinLockedUntil);
  }

  bool _isValidPin(String pin) {
    return pin.isNotEmpty && pin.length >= 4 && pin.length <= 16 &&
        RegExp(r'^[0-9]+$').hasMatch(pin);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _derive(String pin, String salt) {
    List<int> result = utf8.encode('$pin$salt');
    for (var i = 0; i < _iterations; i++) {
      result = sha256.convert(result).bytes;
    }
    return base64Url.encode(result);
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// Excepción lanzada cuando el PIN está bloqueado por intentos fallidos.
class PinLockedException implements Exception {
  final DateTime lockedUntil;
  PinLockedException(this.lockedUntil);

  int get remainingMinutes =>
      lockedUntil.difference(DateTime.now()).inMinutes.clamp(0, 999);
}
