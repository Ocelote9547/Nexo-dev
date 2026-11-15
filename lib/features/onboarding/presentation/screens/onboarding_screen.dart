import 'package:flutter/material.dart';

import '../../../import_export/presentation/screens/import_export_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _finishing = false;

  static const _steps = <_OnboardingStep>[
    _OnboardingStep(
      eyebrow: 'BIENVENIDO A NEXO',
      title: 'Tu agenda, siempre cerca.',
      description:
          'Un espacio privado para tener cerca a las personas importantes y mantener su información organizada.',
      icon: Icons.hub_rounded,
    ),
    _OnboardingStep(
      eyebrow: 'TUS CONTACTOS',
      title: 'Trae tus contactos a NEXO.',
      description:
          'Puedes importar una agenda desde archivos vCard, CSV o JSON. La importación se inicia solo cuando tú lo decidas.',
      icon: Icons.import_contacts_rounded,
    ),
    _OnboardingStep(
      eyebrow: 'ORGANIZA A TU MANERA',
      title: 'Todo en su sitio.',
      description:
          'Marca personas como favoritas y crea colecciones y etiquetas para encontrar cada contacto fácilmente. Puedes configurarlo cuando quieras.',
      icon: Icons.dashboard_customize_rounded,
    ),
    _OnboardingStep(
      eyebrow: 'PRIVACIDAD Y PROTECCIÓN',
      title: 'Tus datos, bajo tu control.',
      description:
          'NEXO guarda tu agenda en el dispositivo. Puedes crear copias de seguridad y configurar las opciones de privacidad desde Ajustes.',
      icon: Icons.shield_outlined,
    ),
    _OnboardingStep(
      eyebrow: 'LISTO PARA EMPEZAR',
      title: 'Tu espacio ya está preparado.',
      description:
          'Cuando quieras, podrás importar más contactos, organizar tu agenda y ajustar NEXO a tu forma de trabajar.',
      icon: Icons.check_circle_outline_rounded,
    ),
  ];

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await widget.onCompleted();
    } catch (_) {
      if (mounted) setState(() => _finishing = false);
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ImportExportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(Icons.hub_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 11),
                  Text(
                    'NEXO',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('Omitir'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: Row(
                children: List.generate(
                  _steps.length,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 4,
                      margin: EdgeInsets.only(
                        right: index == _steps.length - 1 ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 390),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.primary.withValues(alpha: 0.20),
                                colors.secondary.withValues(alpha: 0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Icon(step.icon, size: 36, color: colors.primary),
                        ),
                        const SizedBox(height: 34),
                        Text(
                          step.eyebrow,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          step.title,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.72),
                            height: 1.55,
                          ),
                        ),
                        if (_step == 1) ...[
                          const SizedBox(height: 26),
                          Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: _openImport,
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(17),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: colors.primary.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.file_upload_outlined,
                                        color: colors.primary, size: 25),
                                    const SizedBox(width: 13),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Importar ahora',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Abrir importación de archivos',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded,
                                        color: colors.onSurface.withValues(alpha: 0.55)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: _finishing
                          ? null
                          : () => setState(() => _step--),
                      child: const Text('Atrás'),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _finishing
                          ? null
                          : isLast
                              ? _finish
                              : () => setState(() => _step++),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _finishing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isLast ? 'Entrar en NEXO' : 'Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  const _OnboardingStep({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });
}
