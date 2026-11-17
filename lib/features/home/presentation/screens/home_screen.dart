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
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            tokens.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: tokens.background,
        extendBody: true,
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: Material(
          type: MaterialType.transparency,
          color: Colors.transparent,
          child: _NexoBottomNav(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
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

    return ColoredBox(
      color: Colors.transparent,
      child: SizedBox(
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
      ),
    );
  }
}

/// Olas translúcidas de cuerpo completo con halo circular en la pestaña activa.
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
    const radius = 27.0;
    final blue = tokens.accent;
    const cyan = Color(0xFF39C6E8);

    final haloRect = Rect.fromCircle(center: Offset(selectedX, centerY), radius: 34);
    canvas.drawCircle(
      Offset(selectedX, centerY),
      34,
      Paint()
        ..shader = RadialGradient(
          colors: [
            blue.withValues(alpha: tokens.isDark ? 0.19 : 0.12),
            cyan.withValues(alpha: tokens.isDark ? 0.13 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(haloRect),
    );

    // Cada capa es una ola rellena: cresta y valle forman una cinta de agua,
    // no una simple línea decorativa ni un panel opaco bajo los iconos.
    for (var layer = 0; layer < 3; layer++) {
      final top = Path();
      final bottom = Path();
      final baseY = 52.0 + layer * 5.0;
      final lift = 18.0 - layer * 3.0;
      final sigma = spacing * (0.72 + layer * 0.10);
      double waveY(double x) {
        final d = (x - selectedX) / sigma;
        final envelope = math.exp(-0.5 * d * d);
        final flow = math.sin(x / size.width * math.pi * 2.0 + layer * 0.82) * 2.4;
        return baseY - lift * envelope + flow;
      }

      for (var i = 0; i <= 160; i++) {
        final x = size.width * i / 160;
        final y = waveY(x);
        if (i == 0) {
          top.moveTo(x, y);
          bottom.moveTo(x, y + 7.0 + layer * 1.5);
        } else {
          top.lineTo(x, y);
          bottom.lineTo(x, y + 7.0 + layer * 1.5);
        }
      }
      final ribbon = Path()..addPath(top, Offset.zero);
      for (var i = 160; i >= 0; i--) {
        final x = size.width * i / 160;
        ribbon.lineTo(x, waveY(x) + 7.0 + layer * 1.5);
      }
      ribbon.close();

      final gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          blue.withValues(alpha: 0.0),
          blue.withValues(alpha: layer == 0 ? 0.22 : 0.12),
          cyan.withValues(alpha: layer == 0 ? 0.19 : 0.10),
          blue.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.34, 0.70, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(
        ribbon,
        Paint()
          ..shader = gradient
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      canvas.drawPath(ribbon, Paint()..shader = gradient);
    }

    canvas.drawCircle(
      Offset(selectedX, centerY),
      radius,
      Paint()
        ..color = cyan.withValues(alpha: tokens.isDark ? 0.58 : 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(selectedX, centerY),
      radius - 4,
      Paint()
        ..color = blue.withValues(alpha: tokens.isDark ? 0.30 : 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
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
