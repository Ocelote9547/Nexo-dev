import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoButton — Consistent button component for all actions in NEXO.
///
/// Variants:
///   - [NexoButtonVariant.primary]  — Filled blue button, main action.
///   - [NexoButtonVariant.secondary] — Outlined button, secondary action.
///   - [NexoButtonVariant.text]     — Text-only button, low emphasis action.
///
/// All variants respect the NEXO design system colors, spacing, and radii.
/// ============================================================================

enum NexoButtonVariant { primary, secondary, text }

class NexoButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final NexoButtonVariant variant;
  final bool isLoading;
  final bool isSmall;
  final EdgeInsetsGeometry? padding;

  const NexoButton({
    super.key,
    required this.onPressed,
    this.variant = NexoButtonVariant.primary,
    this.isLoading = false,
    this.isSmall = false,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    switch (variant) {
      case NexoButtonVariant.primary:
        return _buildPrimary(enabled);
      case NexoButtonVariant.secondary:
        return _buildSecondary(enabled);
      case NexoButtonVariant.text:
        return _buildText(enabled);
    }
  }

  Widget _buildPrimary(bool enabled) {
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return NexoDesignColors.textDisabled;
          }
          return NexoDesignColors.accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return NexoDesignColors.textTertiary;
          }
          return Colors.white;
        }),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(padding ?? NexoDesignButtonStyle.padding),
        minimumSize: WidgetStateProperty.all(Size(
          isSmall ? NexoDesignButtonStyle.smallHeight : double.infinity,
          isSmall ? NexoDesignButtonStyle.smallHeight : NexoDesignButtonStyle.height,
        )),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
        )),
      ),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : child,
    );
  }

  Widget _buildSecondary(bool enabled) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return NexoDesignColors.textTertiary;
          }
          return NexoDesignColors.accent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: NexoDesignColors.border, width: 1);
          }
          return const BorderSide(color: NexoDesignColors.accent, width: 1.5);
        }),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(padding ?? NexoDesignButtonStyle.padding),
        minimumSize: WidgetStateProperty.all(Size(
          isSmall ? NexoDesignButtonStyle.smallHeight : double.infinity,
          isSmall ? NexoDesignButtonStyle.smallHeight : NexoDesignButtonStyle.height,
        )),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
        )),
      ),
      child: child,
    );
  }

  Widget _buildText(bool enabled) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return NexoDesignColors.textTertiary;
          }
          return NexoDesignColors.accent;
        }),
        padding: WidgetStateProperty.all(padding ?? const EdgeInsets.symmetric(horizontal: NexoDesignSpacing.md)),
        minimumSize: WidgetStateProperty.all(Size(
          isSmall ? 32 : double.infinity,
          isSmall ? NexoDesignButtonStyle.smallHeight : NexoDesignButtonStyle.height,
        )),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.sm),
        )),
      ),
      child: child,
    );
  }
}
