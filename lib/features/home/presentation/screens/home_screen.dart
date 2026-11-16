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
              child: CustomPaint(
                painter: _NexoBottomWavePainter(tokens, currentIndex, _destinations.length),
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

/// Pequeñas ondas estáticas en las pestañas inactivas.
/// La pestaña seleccionada queda limpia y visualmente despejada.
class _NexoBottomWavePainter extends CustomPainter {
  final NexoDesignTokens tokens;
  final int selectedIndex;
  final int itemCount;

  const _NexoBottomWavePainter(this.tokens, this.selectedIndex, this.itemCount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = tokens.accent.withValues(alpha: tokens.isDark ? 0.24 : 0.19)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    final horizontalInset = 12.0;
    final usableWidth = size.width - horizontalInset * 2;

    for (var index = 0; index < itemCount; index++) {
      if (index == selectedIndex) continue;

      final centerX = horizontalInset + usableWidth * (index + 0.5) / itemCount;
      for (var line = 0; line < 3; line++) {
        final y = 13.0 + line * 3.1;
        final wave = Path()
          ..moveTo(centerX - 12, y)
          ..cubicTo(centerX - 6, y - 2.4, centerX + 6, y + 2.4, centerX + 12, y);
        canvas.drawPath(wave, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NexoBottomWavePainter oldDelegate) {
    return oldDelegate.tokens != tokens ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.itemCount != itemCount;
  }
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
