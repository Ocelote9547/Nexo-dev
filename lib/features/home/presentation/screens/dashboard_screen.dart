import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/design/nexo_design_system.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../providers/dashboard_providers.dart';
import '../../../contacts/presentation/screens/contact_detail_screen.dart';
import '../../../contacts/presentation/screens/contact_form_screen.dart';
import '../../../quick_actions/presentation/providers/quick_actions_providers.dart';
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
    final recentAsync = ref.watch(recentContactsProvider);
    final upcomingAsync = ref.watch(upcomingDatesProvider);
    final allContactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      backgroundColor: tokens.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'nexo_open_dialpad',
        tooltip: 'Abrir teclado del teléfono',
        backgroundColor: tokens.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        onPressed: () async {
          await ref.read(quickActionsServiceProvider).call('');
        },
        child: const Icon(Icons.dialpad_rounded, size: 25),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(tokens: tokens),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _FavoritesSection(
                tokens: tokens,
                contactsAsync: allContactsAsync,
                onNavigate: onNavigate,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: _UpcomingSection(
                tokens: tokens,
                async: upcomingAsync,
                contactsAsync: allContactsAsync,
                onNavigate: onNavigate,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
      ),
    );
  }
}

// ============================================================================
// Encabezado NEXO — Compacto, marca reconocible
// ============================================================================

class _Header extends StatelessWidget {
  final NexoDesignTokens tokens;

  const _Header({required this.tokens});

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
          Image.asset(
            'assets/images/icon_nexo.png',
            width: 46,
            height: 46,
            fit: BoxFit.contain,
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
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tu agenda, siempre cerca.',
                  style: NexoDesignTypography.caption.copyWith(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: NexoDesignSpacing.sm),
          _NavButton(
            tokens: tokens,
            icon: Icons.person_add_alt_1_rounded,
            tooltip: 'Crear contacto',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContactFormScreen()),
            ),
            size: 42,
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: tokens.favorite,
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
                    color: tokens.favorite,
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
                height: 82,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favs.length > 5 ? 5 : favs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 10),
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
              height: 82,
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
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 83,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tokens.favorite.withValues(alpha: 0.72),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: NexoAvatar(
                      displayName: contact.displayName,
                      photoPath: contact.photoPath,
                      size: 45,
                      tokens: tokens,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: 1,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: tokens.favorite,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.surface, width: 2),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              contact.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NexoDesignTypography.contactNameMedium.copyWith(
                color: tokens.textPrimary,
                fontSize: 13,
              ),
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
  final AsyncValue<List<Contact>> contactsAsync;
  final void Function(int)? onNavigate;
  const _UpcomingSection({
    required this.tokens,
    required this.async,
    required this.contactsAsync,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: tokens.accent,
                      size: 18,
                    ),
                    const SizedBox(width: NexoDesignSpacing.sm),
                    Expanded(
                      child: Text(
                        'Próximos cumpleaños',
                        style: NexoDesignTypography.sectionTitle.copyWith(
                          color: tokens.textPrimary,
                          fontSize: 16,
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
              return SizedBox(
                height: 142,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: upcoming.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final matches = contactsAsync.asData?.value
                        .where((contact) => contact.id == upcoming[index].contactId);
                    final contact = matches == null || matches.isEmpty
                        ? null
                        : matches.first;
                    return _BirthdayRow(
                      tokens: tokens,
                      upcoming: upcoming[index],
                      contact: contact,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContactDetailScreen(
                              contactId: upcoming[index].contactId,
                            ),
                          ),
                        );
                      },
                    );
                  },
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
  final Contact? contact;
  final VoidCallback onTap;
  const _BirthdayRow({
    required this.tokens,
    required this.upcoming,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = upcoming.contactName ?? 'Contacto';
    return Material(
      color: tokens.surfaceElevated,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 115,
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tokens.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: tokens.isDark ? 0.16 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 41,
                height: 41,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.accent.withValues(alpha: 0.10),
                  border: Border.all(color: tokens.accent.withValues(alpha: 0.35)),
                ),
                child: ClipOval(
                  child: contact == null
                      ? Icon(Icons.cake_outlined, color: tokens.accent, size: 23)
                      : NexoAvatar(
                          displayName: contact!.displayName,
                          photoPath: contact!.photoPath,
                          size: 41,
                          tokens: tokens,
                        ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NexoDesignTypography.birthdayName.copyWith(
                  color: tokens.textPrimary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Faltan ${upcoming.daysUntil} ${upcoming.daysUntil == 1 ? 'día' : 'días'}',
                textAlign: TextAlign.center,
                style: NexoDesignTypography.birthdayDays.copyWith(
                  color: tokens.favorite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month, size: 15, color: tokens.favorite),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      upcoming.displayDateString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NexoDesignTypography.birthdayDate.copyWith(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: tokens.isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NexoDesignSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: tokens.accent,
                      size: 18,
                    ),
                    const SizedBox(width: NexoDesignSpacing.sm),
                    Expanded(
                      child: Text(
                        'Contactos recientes',
                        style: NexoDesignTypography.sectionTitle.copyWith(
                          color: tokens.textPrimary,
                          fontSize: 16,
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
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.vertical,
                itemCount: recent.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: NexoDesignSpacing.sm),
                itemBuilder: (context, index) => _RecentRow(
                  tokens: tokens,
                  contact: recent[index],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContactDetailScreen(
                          contactId: recent[index].id,
                        ),
                      ),
                    );
                  },
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
  final VoidCallback onTap;

  const _RecentRow({
    required this.tokens,
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 57,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: ClipOval(
                  child: NexoAvatar(
                    displayName: contact.displayName,
                    photoPath: contact.photoPath,
                    size: 37,
                    tokens: tokens,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      style: NexoDesignTypography.contactNameMedium.copyWith(
                        color: tokens.textPrimary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subtitle(contact),
                      style: NexoDesignTypography.contactCaption.copyWith(
                        color: tokens.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textTertiary,
                size: 21,
              ),
            ],
          ),
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