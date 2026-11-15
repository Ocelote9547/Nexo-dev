import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoTextField — Consistent text input component for all forms in NEXO.
///
/// Provides a unified look with:
///   - Dark surface background
///   - Border with focus state (blue accent)
///   - Label, hint, and error text support
///   - Optional prefix and suffix icons
///   - Read-only and disabled states
/// ============================================================================

class NexoTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  const NexoTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final isError = errorText != null && errorText!.isNotEmpty;
    final borderColor = enabled
        ? (isError
            ? NexoDesignColors.error
            : NexoDesignColors.border)
        : NexoDesignColors.textDisabled;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      style: const TextStyle(
        color: NexoDesignColors.textPrimary,
        fontSize: 15,
        height: 1.4,
      ),
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        helperText: helperText,
        labelStyle: TextStyle(
          color: enabled ? NexoDesignColors.textSecondary : NexoDesignColors.textDisabled,
        ),
        hintStyle: TextStyle(
          color: NexoDesignColors.textTertiary,
        ),
        errorStyle: const TextStyle(
          color: NexoDesignColors.error,
          fontSize: 12,
          height: 1.2,
        ),
        helperStyle: const TextStyle(
          color: NexoDesignColors.textTertiary,
          fontSize: 12,
          height: 1.2,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: NexoDesignColors.textTertiary)
            : null,
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          borderSide: const BorderSide(color: NexoDesignColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          borderSide: const BorderSide(color: NexoDesignColors.error, width: 1.5),
        ),
        contentPadding: NexoDesignInputDecoration.contentPadding,
      ),
    );
  }
}
