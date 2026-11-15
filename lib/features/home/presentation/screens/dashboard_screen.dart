import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/design/nexo_design_system.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../providers/dashboard_providers.dart';
import '../../../contacts/presentation/screens/contact_detail_screen.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../birthdays/domain/services/birthday_service.dart';

/// Pantalla de inicio reconstruida — Agenda de contactos premium.
///
/// Nueva composición visual respecto a versiones previas:
/// identidad NEXO compacta, buscador integrado, favoritos en fila horizontal,
/// cumpleaños en formato de agenda y contactos recientes en lista unificada.
/// Adapta colores según el tema activo (claro/oscuro/sistema).
class DashboardScreen extends ConsumerWidget {
  final void Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.tokens(context);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final recentAsync = ref.watch(recentContactsProvider);
    final upcomingAsync = ref.watch(upcomingDatesProvider);
    final allContactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(tokens: tokens, onNavigate: onNavigate),
              ),
              SliverToBoxAdapter(
                child: _OverviewCard(
                  tokens: tokens,
                  totalContacts: summary.totalContacts,
                  favoriteContacts: summary.favoriteContacts,
                  totalCollections: summary.totalCollections,
                ),
              ),
              SliverToBoxAdapter(
                child: _SearchBar(
                  tokens: tokens,
                  onTap: () => onNavigate?.call(1),
                ),
              ),
              SliverToBoxAdapter(
                child: _FavoritesSection(
                  tokens: tokens,
                  contactsAsync: allContactsAsync,
                  onNavigate: onNavigate,
                ),
              ),
              SliverToBoxAdapter(
                child: _UpcomingSection(
                  tokens: tokens,
                  async: upcomingAsync,
                  onNavigate: onNavigate,
                ),
              ),
              SliverToBoxAdapter(
                child: _RecentSection(
                  tokens: tokens,
                  async: recentAsync,
                  onNavigate: onNavigate,
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: NexoDesignSpacing.xxl),
              ),
            ],
          ),
          loading: () => const NexoLoading(),
          error: (e, _) => NexoErrorState(message: 'Error al cargar el panel: $e'),
        ),
      ),
    );
  }
}

// ============================================================================
// Resumen principal — jerarquía visual de la pantalla de inicio
// ============================================================================

class _OverviewCard extends StatelessWidget {
  final NexoDesignTokens tokens;
  final int totalContacts;
  final int favoriteContacts;
  final int totalCollections;

  const _OverviewCard({
    required this.tokens,
    required this.totalContacts,
    required this.favoriteContacts,
    required this.totalCollections,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tokens.surfaceElevated, tokens.surface],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: tokens.border),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildMainInfo(includeMetrics: false)),
                          const SizedBox(width: 12),
                          _buildBrandMark(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildMetrics(),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: _buildMainInfo(includeMetrics: true)),
                      const SizedBox(width: 12),
                      _buildBrandMark(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMainInfo({required bool includeMetrics}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TU AGENDA PERSONAL',
          style: TextStyle(
            color: tokens.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$totalContacts',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 38,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          totalContacts == 1 ? 'contacto guardado' : 'contactos guardados',
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (includeMetrics) ...[
          const SizedBox(height: 16),
          _buildMetrics(),
        ],
      ],
    );
  }

  Widget _buildBrandMark() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.13),
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.accent.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(Icons.hub_rounded, color: tokens.accent, size: 30),
    );
  }

  Widget _buildMetrics() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _OverviewMetric(
          icon: Icons.star_rounded,
          value: favoriteContacts,
          label: 'Favoritos',
          tokens: tokens,
        ),
        _OverviewMetric(
          icon: Icons.folder_rounded,
          value: totalCollections,
          label: 'Colecciones',
          tokens: tokens,
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final NexoDesignTokens tokens;

  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tokens.accent, size: 15),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Encabezado NEXO — Compacto, marca reconocible
// ============================================================================

class _Header extends StatelessWidget {
  final NexoDesignTokens tokens;
  final void Function(int)? onNavigate;
  const _Header({required this.tokens, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NexoDesignSpacing.lg,
        NexoDesignSpacing.md,
        NexoDesignSpacing.lg,
        NexoDesignSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logotipo NEXO — círculo con fondo navy y borde fino
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tokens.accentSelected,
              borderRadius: BorderRadius.circular(NexoDesignRadii.md),
              border: Border.all(
                color: tokens.border,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.hub,
              color: tokens.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: NexoDesignSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NEXO',
                  style: NexoDesignTypography.nexoName.copyWith(
                    color: tokens.textPrimary,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: NexoDesignSpacing.xs),
                Text(
                  'Tus contactos, organizados.',
                  style: NexoDesignTypography.caption.copyWith(
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: NexoDesignSpacing.sm),
          _NavButton(
            tokens: tokens,
            icon: Icons.search,
            tooltip: 'Buscar',
            onTap: () => onNavigate?.call(1),
            size: 40,
          ),
          const SizedBox(width: NexoDesignSpacing.sm),
          _NavButton(
            tokens: tokens,
            icon: Icons.person_add_outlined,
            tooltip: 'Nuevo contacto',
            onTap: () => onNavigate?.call(1),
            size: 40,
          ),
        ],
      ),
    );
  }
}

/// Botón circular de acción en el encabezado.
class _NavButton extends StatelessWidget {
  final NexoDesignTokens tokens;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  const _NavButton({
    required this.tokens,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NexoDesignRadii.full),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tokens.surfaceElevated,
            borderRadius: BorderRadius.circular(NexoDesignRadii.full),
            border: Border.all(
              color: tokens.border,
              width: 1,
            ),
          ),
          child: Icon(icon, color: tokens.textPrimary, size: 20),
        ),
      ),
    );
  }
}

// ============================================================================
// Buscador — Campo de búsqueda real, integrado en la composición
// ============================================================================

class _SearchBar extends StatelessWidget {
  final NexoDesignTokens tokens;
  final VoidCallback onTap;

  const _SearchBar({required this.tokens, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: tokens.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: tokens.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Buscar entre tus contactos',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    color: tokens.textTertiary, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Sección Favoritos — Fila horizontal de agenda, sin tarjetas
// ============================================================================

class _FavoritesSection extends StatelessWidget {
  final NexoDesignTokens tokens;
  final AsyncValue<List<Contact>> contactsAsync;
  final void Function(int)? onNavigate;
  const _FavoritesSection({
    required this.tokens,
    required this.contactsAsync,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: tokens.accent,
                      size: 18,
                    ),
                    const SizedBox(width: NexoDesignSpacing.sm),
                    Expanded(
                      child: Text(
                        'Favoritos',
                        style: NexoDesignTypography.sectionTitle.copyWith(
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigate?.call(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexoDesignSpacing.md,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    color: tokens.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoDesignSpacing.md),
          contactsAsync.when(
            data: (contacts) {
              final favs = contacts.where((c) => c.isFavorite).toList();
              if (favs.isEmpty) {
                return _EmptySection(
                  tokens: tokens,
                  icon: Icons.star_border,
                  title: 'Aún no tienes favoritos',
                  subtitle:
                      'Marca contactos como favoritos para verlos aquí.',
                );
              }
              return SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favs.length > 5 ? 5 : favs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: NexoDesignSpacing.md),
                  itemBuilder: (context, index) {
                    final c = favs[index];
                    return _FavoriteItem(
                      tokens: tokens,
                      contact: c,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ContactDetailScreen(contactId: c.id),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox(
              height: 92,
              child: NexoLoading(),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: NexoDesignTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Favorito individual: avatar circular + nombre centrado debajo.
class _FavoriteItem extends StatelessWidget {
  final NexoDesignTokens tokens;
  final Contact contact;
  final VoidCallback onTap;
  const _FavoriteItem({
    required this.tokens,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NexoDesignRadii.lg),
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tokens.surfaceHigh,
                    borderRadius: BorderRadius.circular(NexoDesignRadii.full),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(NexoDesignRadii.full),
                    child: NexoAvatar(
                      displayName: contact.displayName,
                      photoPath: contact.photoPath,
                      size: 52,
                      tokens: tokens,
                    ),
                  ),
                ),
                if (contact.isFavorite)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: tokens.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: NexoDesignSpacing.xs),
            Text(
              contact.displayName,
              style: NexoDesignTypography.contactCaption.copyWith(
                color: tokens.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Sección Próximos cumpleaños — Lista de agenda profesional
// ============================================================================

class _UpcomingSection extends StatelessWidget {
  final NexoDesignTokens tokens;
  final AsyncValue<List<UpcomingDate>> async;
  final void Function(int)? onNavigate;
  const _UpcomingSection({
    required this.tokens,
    required this.async,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: tokens.accentSoft,
                      size: 18,
                    ),
                    const SizedBox(width: NexoDesignSpacing.sm),
                    Expanded(
                      child: Text(
                        'Próximos cumpleaños',
                        style: NexoDesignTypography.sectionTitle.copyWith(
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigate?.call(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexoDesignSpacing.md,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    color: tokens.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoDesignSpacing.md),
          async.when(
            data: (list) {
              final upcoming = list.take(3).toList();
              if (upcoming.isEmpty) {
                return _EmptySection(
                  tokens: tokens,
                  icon: Icons.calendar_today_outlined,
                  title: 'No hay cumpleaños próximos',
                  subtitle: 'Los cumpleaños próximos aparecerán aquí.',
                );
              }
              return Column(
                children: List.generate(
                  upcoming.length,
                  (index) => _BirthdayRow(
                    tokens: tokens,
                    upcoming: upcoming[index],
                    isLast: index == upcoming.length - 1,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ContactDetailScreen(contactId: upcoming[index].contactId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const NexoLoading(),
            error: (e, _) => Text(
              'Error: $e',
              style: NexoDesignTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de cumpleaños integrada — fecha como elemento tipográfico, no botón.
class _BirthdayRow extends StatelessWidget {
  final NexoDesignTokens tokens;
  final UpcomingDate upcoming;
  final bool isLast;
  final VoidCallback onTap;
  const _BirthdayRow({
    required this.tokens,
    required this.upcoming,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = upcoming.contactName ?? 'Contacto';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 74,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: tokens.separator,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            // Columna de fecha integrada (día + mes)
            Container(
              width: 48,
              height: 54,
              decoration: BoxDecoration(
                color: tokens.surfaceElevated,
                borderRadius: BorderRadius.circular(NexoDesignRadii.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${upcoming.date.day}',
                    style: TextStyle(
                      color: tokens.accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: NexoDesignSpacing.xs),
                  Text(
                    _mesCorto(upcoming.date.month),
                    style: TextStyle(
                      color: tokens.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NexoDesignSpacing.md),
            // Centro: nombre y fecha completa
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: NexoDesignTypography.birthdayName.copyWith(
                      color: tokens.textPrimary,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: NexoDesignSpacing.xs),
                  Text(
                    upcoming.displayDateString,
                    style: NexoDesignTypography.birthdayDate.copyWith(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Derecha: días restantes (discreto, en píldora)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NexoDesignSpacing.md,
                vertical: NexoDesignSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: tokens.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(NexoDesignRadii.full),
                border: Border.all(
                  color: tokens.accent.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Text(
                '${upcoming.daysUntil} ${upcoming.daysUntil == 1 ? 'día' : 'días'}',
                style: NexoDesignTypography.birthdayDays.copyWith(
                  color: tokens.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: NexoDesignSpacing.sm),
          ],
        ),
      ),
    );
  }

  String _mesCorto(int month) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return meses[month - 1];
  }
}

// ============================================================================
// Sección Contactos recientes — Lista de agenda unificada
// ============================================================================

class _RecentSection extends StatelessWidget {
  final NexoDesignTokens tokens;
  final AsyncValue<List<Contact>> async;
  final void Function(int)? onNavigate;
  const _RecentSection({
    required this.tokens,
    required this.async,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: tokens.accentSoft,
                      size: 18,
                    ),
                    const SizedBox(width: NexoDesignSpacing.sm),
                    Expanded(
                      child: Text(
                        'Contactos recientes',
                        style: NexoDesignTypography.sectionTitle.copyWith(
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onNavigate?.call(1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NexoDesignSpacing.md,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    color: tokens.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NexoDesignSpacing.md),
          async.when(
            data: (list) {
              final recent = list.take(3).toList();
              if (recent.isEmpty) {
                return _EmptySection(
                  tokens: tokens,
                  icon: Icons.access_time_outlined,
                  title: 'Sin contactos recientes',
                  subtitle: 'Tus contactos más recientes aparecerán aquí.',
                );
              }
              return Column(
                children: List.generate(
                  recent.length,
                  (index) => _RecentRow(
                    tokens: tokens,
                    contact: recent[index],
                    isLast: index == recent.length - 1,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ContactDetailScreen(contactId: recent[index].id),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            loading: () => const NexoLoading(),
            error: (e, _) => Text(
              'Error: $e',
              style: NexoDesignTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de contacto reciente — lista de agenda profesional.
class _RecentRow extends StatelessWidget {
  final NexoDesignTokens tokens;
  final Contact contact;
  final bool isLast;
  final VoidCallback onTap;
  const _RecentRow({
    required this.tokens,
    required this.contact,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: tokens.separator,
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            // Avatar circular
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tokens.surfaceHigh,
                borderRadius: BorderRadius.circular(NexoDesignRadii.full),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NexoDesignRadii.full),
                child: NexoAvatar(
                  displayName: contact.displayName,
                  photoPath: contact.photoPath,
                  size: 44,
                  tokens: tokens,
                ),
              ),
            ),
            const SizedBox(width: NexoDesignSpacing.md),
            // Nombre e información secundaria
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: NexoDesignTypography.contactNameMedium.copyWith(
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: NexoDesignSpacing.xs),
                  Text(
                    _subtitle(contact),
                    style: NexoDesignTypography.contactCaption.copyWith(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Indicador de navegación pequeño
            Icon(
              Icons.chevron_right,
              color: tokens.textTertiary,
              size: 18,
            ),
            const SizedBox(width: NexoDesignSpacing.sm),
          ],
        ),
      ),
    );
  }

  String _subtitle(Contact c) {
    if (c.nickname != null && c.nickname!.trim().isNotEmpty) {
      return c.nickname!;
    }
    return 'Contacto';
  }
}

// ============================================================================
// Estado vacío minimalista
// ============================================================================

class _EmptySection extends StatelessWidget {
  final NexoDesignTokens tokens;
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptySection({
    required this.tokens,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(NexoDesignRadii.lg),
        border: Border.all(
          color: tokens.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: NexoDesignSpacing.md),
          Icon(icon, color: tokens.textTertiary, size: 20),
          const SizedBox(width: NexoDesignSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NexoDesignTypography.contactName.copyWith(
                    color: tokens.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: NexoDesignSpacing.xs),
                Text(
                  subtitle,
                  style: NexoDesignTypography.contactCaption.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: NexoDesignSpacing.md),
        ],
      ),
    );
  }
}

// Extensión para obtener la cadena de fecha de display desde UpcomingDate.
extension _UpcomingDateDisplay on UpcomingDate {
  String get displayDateString {
    if (yearUnknown) {
      return '${date.day}/${date.month}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}