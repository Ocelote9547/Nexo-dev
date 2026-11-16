import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../../core/theme/nexo_theme.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../../../settings/data/repositories/settings_repository_impl.dart';
import 'package:nexo/features/privacy/presentation/providers/privacy_providers.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _hasPin = false;
  bool _lockOnResume = false;
  bool _useBiometrics = false;
  bool _biometricsAvailable = false;
  bool _loading = true;

  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final privacy = ref.read(privacyServiceProvider);
    final settings = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    final hasPin = await privacy.hasPin();
    final lock = await settings.getBool('privacy_lock_on_resume', defaultValue: false);
    final bio = await _auth.canCheckBiometrics;
    final useBio = await settings.getBool('privacy_use_biometrics', defaultValue: false);
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _lockOnResume = lock;
        _biometricsAvailable = bio;
        _useBiometrics = useBio && bio;
        _loading = false;
      });
    }
  }

  Future<void> _setLockOnResume(bool v) async {
    final settings = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    await settings.setBool('privacy_lock_on_resume', v);
    setState(() => _lockOnResume = v);
  }

  Future<void> _setUseBiometrics(bool v) async {
    if (v && !_biometricsAvailable) return;
    final settings = SettingsRepositoryImpl(ref.read(appDatabaseProvider));
    await settings.setBool('privacy_use_biometrics', v);
    setState(() => _useBiometrics = v);
  }

  Future<void> _createPin() async {
    final controller = TextEditingController();
    final confirm = TextEditingController();
    var activeController = controller;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear PIN'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                readOnly: true,
                obscureText: true,
                onTap: () => setDialogState(() => activeController = controller),
                decoration: InputDecoration(
                  labelText: 'PIN (4-8 dígitos)',
                  suffixIcon: activeController == controller
                      ? const Icon(Icons.edit, size: 18)
                      : null,
                ),
                maxLength: 8,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirm,
                readOnly: true,
                obscureText: true,
                onTap: () => setDialogState(() => activeController = confirm),
                decoration: InputDecoration(
                  labelText: 'Confirmar PIN',
                  suffixIcon: activeController == confirm
                      ? const Icon(Icons.edit, size: 18)
                      : null,
                ),
                maxLength: 8,
              ),
              const SizedBox(height: 12),
              NexoPinKeypad(
                controller: activeController,
                onChanged: () => setDialogState(() {}),
              ),
              const SizedBox(height: 4),
              Text(
                activeController == controller
                    ? 'Introduce el PIN y después selecciona Confirmar PIN.'
                    : 'Repite el mismo PIN para confirmarlo.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
        ],
      ),
    );
    if (ok != true) return;
    if (controller.text != confirm.text) {
      _showMessage('Los PIN no coinciden');
      return;
    }
    final privacy = ref.read(privacyServiceProvider);
    final success = await privacy.setPin(controller.text);
    if (success) {
      setState(() => _hasPin = true);
      _showMessage('PIN configurado');
    } else {
      _showMessage('PIN inválido');
    }
  }

  Future<void> _changePin() async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var activeController = oldController;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar PIN'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                readOnly: true,
                obscureText: true,
                onTap: () => setDialogState(() => activeController = oldController),
                decoration: const InputDecoration(labelText: 'PIN actual'),
                maxLength: 16,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                readOnly: true,
                obscureText: true,
                onTap: () => setDialogState(() => activeController = newController),
                decoration: const InputDecoration(labelText: 'Nuevo PIN (4-8 dígitos)'),
                maxLength: 8,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                readOnly: true,
                obscureText: true,
                onTap: () => setDialogState(() => activeController = confirmController),
                decoration: const InputDecoration(labelText: 'Confirmar nuevo PIN'),
                maxLength: 8,
              ),
              const SizedBox(height: 10),
              NexoPinKeypad(
                controller: activeController,
                maxLength: activeController == oldController ? 16 : 8,
                onChanged: () => setDialogState(() {}),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar')),
        ],
      ),
    );
    if (ok != true) return;
    final privacy = ref.read(privacyServiceProvider);
    if (!(await privacy.verifyPin(oldController.text))) {
      _showMessage('PIN actual incorrecto');
      return;
    }
    if (newController.text != confirmController.text) {
      _showMessage('Los PIN no coinciden');
      return;
    }
    final success = await privacy.setPin(newController.text);
    if (success) {
      _showMessage('PIN actualizado');
    } else {
      _showMessage('PIN inválido');
    }
  }

  Future<void> _removePin() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar protección'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta operación eliminará el PIN y la protección de acceso.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              readOnly: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN actual'),
              maxLength: 16,
            ),
            const SizedBox(height: 10),
            NexoPinKeypad(
              controller: controller,
              maxLength: 16,
              onChanged: () {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
        ],
      ),
    );
    if (ok != true) return;
    final privacy = ref.read(privacyServiceProvider);
    if (!(await privacy.verifyPin(controller.text))) {
      _showMessage('PIN actual incorrecto');
      return;
    }
    await privacy.removePin();
    setState(() => _hasPin = false);
    _showMessage('Protección desactivada');
  }

  Future<void> _unlockNow() async {
    final privacy = ref.read(privacyServiceProvider);
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desbloquear'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              readOnly: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN'),
              maxLength: 16,
            ),
            const SizedBox(height: 10),
            NexoPinKeypad(
              controller: controller,
              maxLength: 16,
              onChanged: () {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desbloquear')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final valid = await privacy.verifyPin(controller.text);
      if (!valid) {
        _showMessage('PIN incorrecto');
      }
    } catch (e) {
      _showMessage('Error al verificar el PIN.');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: NexoLoading());
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(Icons.security_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 27),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tu privacidad, protegida',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Controla el acceso a tus contactos y datos guardados en NEXO.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Text('PROTECCIÓN DE ACCESO',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0)),
          const SizedBox(height: NexoSpacing.sm),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Bloquear al volver a abrir'),
                  subtitle: const Text(
                    'Solicitar autenticación al abrir NEXO tras salir de la app.',
                  ),
                  value: _lockOnResume,
                  onChanged: _hasPin ? _setLockOnResume : null,
                ),
                if (_hasPin) ...[
                  const SizedBox(height: NexoSpacing.md),
                  if (_biometricsAvailable)
                    SwitchListTile(
                      title: const Text('Desbloqueo biométrico'),
                      subtitle: const Text('Usar huella dactilar o reconocimiento facial.'),
                      value: _useBiometrics,
                      onChanged: _setUseBiometrics,
                    ),
                  const SizedBox(height: NexoSpacing.md),
                  ListTile(
                    title: const Text('Cambiar PIN'),
                    trailing: const Icon(Icons.edit),
                    onTap: _changePin,
                  ),
                  const SizedBox(height: NexoSpacing.md),
                  ListTile(
                    title: const Text('Desactivar protección'),
                    trailing: const Icon(Icons.lock_open),
                    onTap: _removePin,
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Probar desbloqueo ahora'),
                    trailing: const Icon(Icons.lock),
                    onTap: _unlockNow,
                  ),
                ],
                if (!_hasPin)
                  ListTile(
                    title: const Text('Crear PIN'),
                    trailing: const Icon(Icons.add),
                    onTap: _createPin,
                  ),
              ],
            ),
          ),
          const SizedBox(height: NexoSpacing.xl),
          Text('BIOMETRÍA',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0)),
          const SizedBox(height: NexoSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Disponible en este dispositivo'),
                  trailing: Text(
                    _biometricsAvailable ? 'Sí' : 'No',
                    style: TextStyle(
                      color: _biometricsAvailable
                          ? NexoColors.accent
                          : NexoColors.textTertiary,
                    ),
                  ),
                ),
                if (!_biometricsAvailable)
                  const ListTile(
                    title: Text('No hay biometría'),
                    subtitle: Text('Use el PIN para desbloquear.'),
                    enabled: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PinLockedException implements Exception {
  final String message;
  PinLockedException(this.message);
}
