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
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primary.withValues(alpha: 0.20),
                          colors.primary.withValues(alpha: 0.07),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(Icons.hub_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXO',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'TU AGENDA, SIEMPRE CERCA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
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
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Row(
                children: List.generate(
                  _steps.length,
                  (index) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 5,
                      margin: EdgeInsets.only(
                        right: index == _steps.length - 1 ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: index <= _step
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colors.primary.withValues(alpha: 0.16),
                              colors.surface,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: colors.primary.withValues(alpha: 0.20),
                                    ),
                                  ),
                                  child: Icon(
                                    step.icon,
                                    size: 29,
                                    color: colors.primary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: colors.onSurface.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Text(
                                    'PASO ${_step + 1} / ${_steps.length}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurface.withValues(alpha: 0.70),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Text(
                              step.eyebrow,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              step.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                                letterSpacing: -0.7,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.description,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.76),
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_step == 1) ...[
                        const SizedBox(height: 18),
                        Material(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: _openImport,
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.file_upload_outlined,
                                    color: colors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Importar ahora',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Abrir importación de archivos',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: colors.onSurface.withValues(alpha: 0.55),
                                  ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    OutlinedButton(
                      onPressed: _finishing
                          ? null
                          : () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(104, 52),
                        side: BorderSide(
                          color: colors.primary.withValues(alpha: 0.38),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Atrás'),
                    ),
                    const SizedBox(width: 12),
                  ],
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(isLast ? 'Entrar en NEXO' : 'Continuar'),
                                const SizedBox(width: 8),
                                Icon(
                                  isLast
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
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
