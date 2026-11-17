import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/presentation/screens/contacts_screen.dart';
import '../../../collections/presentation/screens/collections_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import 'dashboard_screen.dart';
import '../../../../core/providers/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = ref.tokens(context);
    final screens = [
      DashboardScreen(onNavigate: (i) => setState(() => _index = i)),
      const ContactsScreen(),
      const CollectionsScreen(),
      const SettingsScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: tokens.background,
        systemNavigationBarDividerColor: tokens.background,
        systemNavigationBarIconBrightness:
            tokens.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: tokens.background,
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: _NexoBottomNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _NexoBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NexoBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavDestination> _destinations = [
    _NavDestination(Icons.home_outlined, Icons.home, 'Inicio'),
    _NavDestination(Icons.people_outline, Icons.people, 'Contactos'),
    _NavDestination(Icons.folder_outlined, Icons.folder, 'Colecciones'),
    _NavDestination(Icons.settings_outlined, Icons.settings, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.tokens(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: 72 + bottomInset + 18,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: currentIndex.toDouble()),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, selectedPosition, _) => RepaintBoundary(
                  child: CustomPaint(
                  painter: _NexoBottomWavePainter(
                    tokens,
                    selectedPosition,
                    _destinations.length,
                  ),
                ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: bottomInset + 8,
            child: Container(
              height: 68,
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  children: List.generate(
                    _destinations.length,
                    (index) => Expanded(
                      child: _NavItem(
                        tokens: tokens,
                        destination: _destinations[index],
                        isSelected: currentIndex == index,
                        onTap: () => onTap(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onda continua con una cresta elevada y capas de color que siguen la pestaña activa.
class _NexoBottomWavePainter extends CustomPainter {
  final NexoDesignTokens tokens;
  final double selectedPosition;
  final int itemCount;

  const _NexoBottomWavePainter(this.tokens, this.selectedPosition, this.itemCount);

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount < 2 || size.width <= 0 || size.height <= 0) return;

    const inset = 12.0;
    final usableWidth = size.width - inset * 2;
    final spacing = usableWidth / itemCount;
    final peakX = inset + spacing * (selectedPosition + 0.5);
    const baseY = 67.0;
    const amplitude = 39.0;
    final sigma = spacing * 0.92;
    final cyan = const Color(0xFF39C6E8);
    final blue = tokens.accent;

    // La curva crea una elevación ancha que abraza el destino activo,
    // en lugar de una pequeña cresta aislada sobre una línea horizontal.
    double waveY(double x, double offset) {
      final distance = (x - peakX) / sigma;
      final shoulder = math.exp(-0.5 * distance * distance);
      final broadShoulder = math.exp(-0.5 * math.pow(distance / 1.65, 2));
      final crest = amplitude * shoulder * 0.78 + amplitude * broadShoulder * 0.22;
      return baseY + offset - crest;
    }

    final area = Path();
    for (var step = 0; step <= 120; step++) {
      final x = size.width * step / 120;
      final y = waveY(x, 0);
      if (step == 0) {
        area.moveTo(x, y);
      } else {
        area.lineTo(x, y);
      }
    }
    area
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          blue.withValues(alpha: tokens.isDark ? 0.17 : 0.12),
          cyan.withValues(alpha: tokens.isDark ? 0.075 : 0.055),
          blue.withValues(alpha: 0.015),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(area, fill);

    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final offset = layer * 4.0;
      for (var step = 0; step <= 120; step++) {
        final x = size.width * step / 120;
        final y = waveY(x, offset);
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final line = Paint()
        ..shader = LinearGradient(
          colors: [
            blue.withValues(alpha: 0.0),
            blue.withValues(alpha: layer == 0 ? 0.76 : 0.42),
            cyan.withValues(alpha: layer == 0 ? 0.72 : 0.38),
            blue.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.36, 0.72, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer == 0 ? 1.65 : 1.05
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _NexoBottomWavePainter oldDelegate) =>
      oldDelegate.tokens != tokens ||
      oldDelegate.selectedPosition != selectedPosition ||
      oldDelegate.itemCount != itemCount;
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination(this.icon, this.selectedIcon, this.label);
}

class _NavItem extends StatelessWidget {
  final NexoDesignTokens tokens;
  final _NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tokens,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = tokens.accent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 58,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    isSelected ? destination.selectedIcon : destination.icon,
                    size: 24,
                    color: isSelected ? activeColor : tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : tokens.textSecondary,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
