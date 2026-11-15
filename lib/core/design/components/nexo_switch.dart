import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoSwitch — Consistent switch component for toggles in NEXO.
///
/// Uses the NEXO accent color when active and a muted color when inactive.
/// ============================================================================

class NexoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeThumbColor;
  final Color? activeTrackColor;
  final Color? inactiveThumbColor;
  final Color? inactiveTrackColor;

  const NexoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeThumbColor ?? NexoDesignColors.accent,
      activeTrackColor: activeTrackColor ?? NexoDesignColors.accent.withValues(alpha: 0.5),
      inactiveThumbColor: inactiveThumbColor ?? NexoDesignColors.textTertiary,
      inactiveTrackColor: inactiveTrackColor ?? NexoDesignColors.textTertiary.withValues(alpha: 0.3),
    );
  }
}
