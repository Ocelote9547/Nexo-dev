import 'dart:ui' show ImageFilter;

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
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            tokens.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: tokens.background,
        extendBody: false,
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: _NexoBottomNav(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

/// Barra inferior compacta con un acabado de cristal discreto.
/// El desenfoque se limita a esta superficie para mantener la lectura y el
/// rendimiento del resto de pantallas.
class _NexoBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NexoBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const List<_NavDestination> _destinations = [
    _NavDestination(Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    _NavDestination(Icons.people_outline_rounded, Icons.people_rounded, 'Contactos'),
    _NavDestination(Icons.folder_outlined, Icons.folder_rounded, 'Colecciones'),
    _NavDestination(Icons.settings_outlined, Icons.settings_rounded, 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.tokens(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: tokens.isDark
                  ? tokens.surfaceElevated.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.91),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: tokens.border.withValues(alpha: tokens.isDark ? 0.92 : 0.82),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: tokens.isDark ? 0.18 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
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
    );
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
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.accent.withValues(alpha: tokens.isDark ? 0.16 : 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: isSelected ? tokens.accent : tokens.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
