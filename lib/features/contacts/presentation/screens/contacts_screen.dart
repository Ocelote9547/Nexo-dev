import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../../../core/design/components/nexo_button.dart';
import '../../../../core/design/components/nexo_card.dart';
import '../../../../core/design/components/nexo_search_bar.dart';
import '../../../../core/design/nexo_design_system.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../../domain/entities/contact.dart';
import '../providers/contact_providers.dart';
import '../providers/search_providers.dart';
import '../screens/contact_detail_screen.dart';
import 'contact_form_screen.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  String _query = '';
  Timer? _searchDebounce;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _query = v.trim());
      }
    });
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ñ', 'n~');
  }

  String _initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '#';
    final first = _normalize(trimmed)[0];
    if (RegExp(r'[a-z]').hasMatch(first)) {
      return first.toUpperCase();
    }
    if (first == 'n' && trimmed.toLowerCase().startsWith('ñ')) {
      return 'Ñ';
    }
    return '#';
  }

  int _letterRank(String letter) {
    if (letter == '#') return 1000;
    if (letter == 'Ñ') return 15; // after N (14)
    final code = letter.codeUnitAt(0);
    if (code >= 65 && code <= 90) return code - 64;
    return 999;
  }

  List<_Section> _buildSections(List<Contact> contacts) {
    // Separar favoritos para la sección superior "★"
    final favorites = <Contact>[];
    for (final c in contacts) {
      if (c.isFavorite) {
        favorites.add(c);
      }
    }
    favorites.sort((a, b) => _normalize(a.displayName).compareTo(_normalize(b.displayName)));

    final sections = <_Section>[];
    if (favorites.isNotEmpty) {
      sections.add(_Section(letter: '★', contacts: favorites, isFavorites: true));
    }

    // Todos los contactos (incluidos favoritos) en sus posiciones alfabéticas
    final grouped = <String, List<Contact>>{};
    for (final c in contacts) {
      final letter = _initialOf(c.displayName);
      grouped.putIfAbsent(letter, () => []).add(c);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => _normalize(a.displayName).compareTo(_normalize(b.displayName)));
    }
    final letters = grouped.keys.toList()..sort((a, b) => _letterRank(a).compareTo(_letterRank(b)));
    sections.addAll(letters.map((l) => _Section(letter: l, contacts: grouped[l]!)));
    return sections;
  }

  void _scrollToLetter(String letter) {
    final key = _sectionKeys[letter];
    final context = key?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final allAsync = ref.watch(contactsListProvider);
    final searchService = ref.read(contactSearchServiceProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 66,
        title: Text(
          'Contactos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          NexoButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContactFormScreen()),
              );
            },
            variant: NexoButtonVariant.text,
            isSmall: true,
            child: const Text('Nuevo'),
          ),
          const SizedBox(width: NexoDesignSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NexoDesignSpacing.lg,
              NexoDesignSpacing.md,
              NexoDesignSpacing.lg,
              NexoDesignSpacing.sm,
            ),
            child: NexoSearchBar(
              hint: 'Buscar contactos...',
              onChanged: _onSearchChanged,
            ),
          ),
          // Contador de contactos mostrados
          _CounterDisplay(query: query),
          Expanded(
            child: allAsync.when(
              data: (all) {
                if (query.trim().isEmpty) {
                  final sections = _buildSections(all);
                  if (sections.isEmpty) {
                    return const NexoEmptyState(
                      icon: Icons.people_outline,
                      title: 'Sin contactos',
                      subtitle: 'Añade tu primer contacto para empezar.',
                    );
                  }
                  final availableLetters = sections
                      .where((s) => s.letter != '★')
                      .map((s) => s.letter)
                      .toList();
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: NexoDesignSpacing.lg,
                          vertical: NexoDesignSpacing.sm,
                        ),
                        itemCount: sections.fold<int>(0, (sum, s) => sum + 1 + s.contacts.length),
                        itemBuilder: (context, index) {
                          var cursor = 0;
                          for (final section in sections) {
                            if (index == cursor) {
                              _sectionKeys[section.letter] ??= GlobalKey();
                              return _SectionHeader(key: _sectionKeys[section.letter], letter: section.letter, isFavorites: section.isFavorites);
                            }
                            cursor++;
                            if (index < cursor + section.contacts.length) {
                              final c = section.contacts[index - cursor];
                              return _ContactTile(contact: c);
                            }
                            cursor += section.contacts.length;
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (availableLetters.length > 1)
                        Positioned(
                          right: NexoDesignSpacing.xs,
                          top: 0,
                          bottom: 0,
                          child: _AlphabetIndex(
                            letters: availableLetters,
                            onLetterTap: _scrollToLetter,
                          ),
                        ),
                    ],
                  );
                }
                return FutureBuilder<List<String>>(
                  future: searchService.searchIds(query.trim()),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const NexoLoading();
                    }
                    if (snapshot.hasError) {
                      return NexoErrorState(message: 'Error en la búsqueda: ${snapshot.error}');
                    }
                    final ids = snapshot.data ?? [];
                    final idSet = ids.toSet();
                    final filtered = all.where((c) => idSet.contains(c.id)).toList()
                      ..sort((a, b) {
                        // Favoritos primero, luego orden alfabético
                        if (a.isFavorite != b.isFavorite) {
                          return a.isFavorite ? -1 : 1;
                        }
                        return _normalize(a.displayName).compareTo(_normalize(b.displayName));
                      });
                    if (filtered.isEmpty) {
                      return const NexoEmptyState(
                        icon: Icons.search_off,
                        title: 'Sin resultados',
                        subtitle: 'No se encontraron contactos.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(NexoDesignSpacing.lg, NexoDesignSpacing.sm, NexoDesignSpacing.lg + 18, NexoDesignSpacing.lg),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        return _ContactTile(contact: c);
                      },
                    );
                  },
                );
              },
              loading: () => const NexoLoading(),
              error: (e, _) => NexoErrorState(message: 'Error al cargar contactos: $e'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra el número de contactos que se están visualizando.
///
/// Cuando no hay búsqueda activa, muestra el total de contactos.
/// Cuando hay búsqueda activa, muestra el número de resultados.
///
/// Los favoritos aparecen en la sección "★" y también en su posición
/// alfabética, pero son un único registro en SQLite, por tanto se cuentan
/// solo una vez.
class _CounterDisplay extends ConsumerWidget {
  final String query;
  const _CounterDisplay({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(contactDisplayCountProvider(query));

    String label;
    if (count == 0) {
      label = '0 contactos';
    } else if (count == 1) {
      label = '1 contacto';
    } else {
      label = '$count contactos';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NexoDesignSpacing.lg,
        0,
        NexoDesignSpacing.lg,
        NexoDesignSpacing.lg,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Section {
  final String letter;
  final List<Contact> contacts;
  final bool isFavorites;
  _Section({required this.letter, required this.contacts, this.isFavorites = false});
}

class _SectionHeader extends StatelessWidget {
  final String letter;
  final bool isFavorites;
  const _SectionHeader({super.key, required this.letter, this.isFavorites = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: NexoDesignSpacing.md, bottom: NexoDesignSpacing.xs),
      child: Text(
        isFavorites ? 'Favoritos' : letter,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  const _ContactTile({required this.contact});

  String? _secondaryInfo() {
    // Mostrar el primer apodo disponible como información secundaria
    if (contact.nickname != null && contact.nickname!.isNotEmpty) {
      return contact.nickname;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoDesignSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ContactDetailScreen(contactId: contact.id)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: contact.isFavorite
                    ? NexoDesignColors.favorite.withValues(alpha: 0.72)
                    : colors.outlineVariant.withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                NexoAvatar(
                  displayName: contact.displayName,
                  photoPath: contact.photoPath,
                  size: 52,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                        ),
                      ),
                      if (_secondaryInfo() != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _secondaryInfo()!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 3),
                        Text(
                          'Contacto',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (contact.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 7),
                    child: Icon(Icons.star_rounded, color: NexoDesignColors.favorite, size: 19),
                  ),
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant, size: 23),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlphabetIndex extends StatelessWidget {
  final List<String> letters;
  final void Function(String) onLetterTap;
  const _AlphabetIndex({required this.letters, required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          final itemHeight = box.size.height / letters.length;
          final index = (local.dy / itemHeight).floor().clamp(0, letters.length - 1);
          onLetterTap(letters[index]);
        },
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          final itemHeight = box.size.height / letters.length;
          final index = (local.dy / itemHeight).floor().clamp(0, letters.length - 1);
          onLetterTap(letters[index]);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: letters.map((l) {
            return GestureDetector(
              onTap: () => onLetterTap(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
