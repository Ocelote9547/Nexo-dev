import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../settings/data/repositories/settings_repository_impl.dart';
import 'package:nexo/features/privacy/presentation/providers/privacy_providers.dart';

/// Pantalla de desbloqueo mostrada al abrir NEXO cuando hay PIN configurado.
class UnlockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _biometricsAvailable = false;
  bool _useBiometrics = false;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final bio = await _auth.canCheckBiometrics;
    final settings = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    final useBio = await settings.getBool('privacy_use_biometrics', defaultValue: false);
    if (mounted) {
      setState(() {
        _biometricsAvailable = bio;
        _useBiometrics = useBio && bio;
      });
    }
  }

  Future<void> _unlock() async {
    final pin = _pinController.text;
    if (pin.isEmpty) return;
    setState(() => _busy = true);
    try {
      final privacy = ref.read(privacyServiceProvider);
      final valid = await privacy.verifyPin(pin);
      if (valid) {
        widget.onUnlocked();
      } else {
        setState(() => _error = 'PIN incorrecto');
      }
    } on PinLockedException catch (e) {
      setState(() => _error = 'PIN bloqueado. Intente de nuevo en ${e.remainingMinutes} min.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlockBiometrics() async {
    try {
      final didAuth = await _auth.authenticate(
        localizedReason: 'Autentique para abrir NEXO',
        biometricOnly: false,
      );
      if (didAuth && mounted) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => _error = 'Autenticación rechazada');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error de autenticación: $e');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(NexoSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: NexoColors.accent),
              const SizedBox(height: NexoSpacing.lg),
              Text('NEXO', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: NexoSpacing.sm),
              Text('Desbloquear aplicación',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: NexoSpacing.xl),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(NexoSpacing.md),
                  decoration: BoxDecoration(
                    color: NexoColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(NexoRadii.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: NexoColors.error, size: 20),
                      const SizedBox(width: NexoSpacing.md),
                      Expanded(child: Text(_error!, style: const TextStyle(color: NexoColors.error))),
                    ],
                  ),
                ),
              if (_error != null) const SizedBox(height: NexoSpacing.md),
              TextField(
                controller: _pinController,
                readOnly: true,
                obscureText: true,
                maxLength: 8,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: NexoSpacing.sm),
              NexoPinKeypad(
                controller: _pinController,
                onChanged: () => setState(() => _error = null),
              ),
              const SizedBox(height: NexoSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _unlock,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Desbloquear'),
                    ),
                  ),
                ],
              ),
              if (_biometricsAvailable && _useBiometrics) ...[
                const SizedBox(height: NexoSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _unlockBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Usar biometría'),
                ),
              ],
              const SizedBox(height: NexoSpacing.lg),
              const Text(
                'Ingrese su PIN para acceder a NEXO.',
                style: TextStyle(color: NexoColors.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinLockedException implements Exception {
  final int remainingMinutes;
  PinLockedException(this.remainingMinutes);
}
