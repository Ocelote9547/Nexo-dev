import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoSearchBar — Consistent search input component for all search screens
/// in NEXO.
///
/// Provides:
///   - Dark surface background
///   - Search icon prefix
///   - Clear (×) suffix when text is present
///   - Hint text support
///   - Focus handling via focus node
/// ============================================================================

class NexoSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final bool autofocus;

  const NexoSearchBar({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onClear,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<NexoSearchBar> createState() => _NexoSearchBarState();
}

class _NexoSearchBarState extends State<NexoSearchBar> {
  late TextEditingController _internalController;
  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
  }

  @override
  void dispose() {
    _internalController.dispose();
    super.dispose();
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onClear?.call();
    if (widget.onChanged != null) {
      widget.onChanged!('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _effectiveController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: NexoDesignColors.surfaceHigh,
        borderRadius: BorderRadius.circular(NexoDesignRadii.md),
        border: Border.all(color: NexoDesignColors.border, width: 1),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        style: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: widget.hint ?? 'Buscar...',
          hintStyle: const TextStyle(
            color: NexoDesignColors.textTertiary,
            fontSize: 15,
          ),
          prefixIcon: const Icon(Icons.search, size: 20, color: NexoDesignColors.textTertiary),
          suffixIcon: hasText
              ? GestureDetector(
                  onTap: _handleClear,
                  child: const Icon(Icons.close, size: 20, color: NexoDesignColors.textTertiary),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NexoDesignRadii.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NexoDesignRadii.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(NexoDesignRadii.md),
            borderSide: const BorderSide(color: NexoDesignColors.accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: NexoDesignSpacing.md,
            vertical: NexoDesignSpacing.sm,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
