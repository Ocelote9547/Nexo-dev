import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoSelector — Consistent dropdown/selector component for choosing from
/// a list of options in NEXO.
///
/// Provides a unified look matching NexoTextField with:
///   - Dark surface background
///   - Border with focus state (blue accent)
///   - Label, hint support
///   - Optional error text
/// ============================================================================

class NexoSelector<T> extends StatelessWidget {
  final T? initialValue;
  final String? label;
  final String? hint;
  final String? errorText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final IconData? prefixIcon;
  final FocusNode? focusNode;

  const NexoSelector({
    super.key,
    this.initialValue,
    this.label,
    this.hint,
    this.errorText,
    required this.items,
    this.onChanged,
    this.enabled = true,
    this.prefixIcon,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null && errorText!.isNotEmpty;
    final borderColor = enabled
        ? (isError
            ? NexoDesignColors.error
            : NexoDesignColors.border)
        : NexoDesignColors.textDisabled;

    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: enabled ? onChanged : null,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: TextStyle(
          color: enabled ? NexoDesignColors.textSecondary : NexoDesignColors.textDisabled,
        ),
        hintStyle: const TextStyle(
          color: NexoDesignColors.textTertiary,
        ),
        errorStyle: const TextStyle(
          color: NexoDesignColors.error,
          fontSize: 12,
          height: 1.2,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: NexoDesignColors.textTertiary)
            : null,
        filled: true,
        fillColor: enabled ? NexoDesignColors.surfaceHigh : NexoDesignColors.textDisabled.withValues(alpha: 0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          borderSide: BorderSide(
            color: isError ? NexoDesignColors.error : NexoDesignColors.accent,
            width: 1.5,
          ),
        ),
        contentPadding: NexoDesignInputDecoration.contentPadding,
      ),
      dropdownColor: NexoDesignColors.surfaceHigh,
      style: const TextStyle(
        color: NexoDesignColors.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down,
        color: NexoDesignColors.textTertiary,
        size: 20,
      ),
    );
  }
}
