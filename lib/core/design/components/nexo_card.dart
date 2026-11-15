import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoCard — Consistent card component used across all screens.
///
/// Provides a unified surface with:
///   - Dark elevated surface background
///   - Border with subtle color
///   - Rounded corners
///   - Optional elevation and padding
/// ============================================================================

class NexoCard extends StatelessWidget {
  final Widget child;
  final double elevation;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const NexoCard({
    super.key,
    required this.child,
    this.elevation = NexoDesignElevation.low,
    this.margin,
    this.padding,
    this.color,
    this.borderRadius,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Material(
      color: color ?? NexoDesignColors.surfaceElevated,
      borderRadius: borderRadius ?? BorderRadius.circular(NexoDesignRadii.md),
      child: child,
    );

    final decorated = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(NexoDesignRadii.md),
        border: border,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation * 2),
                ),
              ]
            : null,
      ),
      child: cardContent,
    );

    if (onTap == null) return decorated;

    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius ?? BorderRadius.circular(NexoDesignRadii.md),
      child: decorated,
    );
  }
}
