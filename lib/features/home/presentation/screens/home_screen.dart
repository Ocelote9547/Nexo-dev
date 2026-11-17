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

/// Ondas transparentes con un halo circular que envuelve la pestaña activa.
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
    final selectedX = inset + spacing * (selectedPosition + 0.5);
    const centerY = 38.0;
    const radius = 25.0;
    final blue = tokens.accent;
    const cyan = Color(0xFF39C6E8);

    // Halo circular suave: el centro permanece transparente, sin banda ni tarjeta.
    final haloRect = Rect.fromCircle(
      center: Offset(selectedX, centerY),
      radius: radius,
    );
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          blue.withValues(alpha: tokens.isDark ? 0.13 : 0.085),
          cyan.withValues(alpha: tokens.isDark ? 0.09 : 0.055),
          blue.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.68, 1.0],
      ).createShader(haloRect);
    canvas.drawCircle(Offset(selectedX, centerY), radius, haloPaint);

    // Ondas continuas: se elevan y se curvan alrededor del halo seleccionado.
    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final baseY = 58.0 + layer * 5.0;
      final lift = 17.0 - layer * 2.5;
      final sigma = spacing * (0.62 + layer * 0.08);

      for (var step = 0; step <= 180; step++) {
        final x = size.width * step / 180;
        final distance = (x - selectedX) / sigma;
        final envelope = math.exp(-0.5 * distance * distance);
        final gentleFlow = math.sin((x / size.width * math.pi * 2.0) + layer * 0.72) * 1.7;
        final y = baseY - lift * envelope + gentleFlow;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final linePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            blue.withValues(alpha: 0.0),
            blue.withValues(alpha: layer == 0 ? 0.62 : 0.34),
            cyan.withValues(alpha: layer == 0 ? 0.58 : 0.30),
            blue.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.34, 0.70, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = layer == 0 ? 1.7 : 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, linePaint);
    }

    final ringPaint = Paint()
      ..color = cyan.withValues(alpha: tokens.isDark ? 0.46 : 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    canvas.drawCircle(Offset(selectedX, centerY), radius - 1.0, ringPaint);

    final innerRingPaint = Paint()
      ..color = blue.withValues(alpha: tokens.isDark ? 0.26 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(selectedX, centerY), radius - 4.0, innerRingPaint);
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.045)
                        : Colors.transparent,
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
