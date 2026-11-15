import 'package:flutter/material.dart';

import '../../../core/design/nexo_design_system.dart';

/// ============================================================================
/// NexoDialog — Consistent confirmation dialog component for NEXO.
///
/// Provides a unified look with:
///   - Dark surface background
///   - Title and optional description
///   - Cancel and confirm buttons (confirm styled as primary)
/// ============================================================================

class NexoDialog extends StatelessWidget {
  final String title;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  const NexoDialog({
    super.key,
    required this.title,
    this.description,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.onConfirm,
    this.onCancel,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NexoDesignColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NexoDesignRadii.lg),
      ),
      titleTextStyle: NexoDesignTypography.headlineMedium,
      contentTextStyle: NexoDesignTypography.bodyMedium,
      title: Text(title),
      content: description != null ? Text(description!) : null,
      actions: [
        TextButton(
          onPressed: () {
            onCancel?.call();
            Navigator.of(context).pop(false);
          },
          style: TextButton.styleFrom(
            foregroundColor: NexoDesignColors.textSecondary,
          ),
          child: Text(cancelLabel),
        ),
        const SizedBox(width: NexoDesignSpacing.sm),
        FilledButton(
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive ? NexoDesignColors.error : NexoDesignColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: NexoDesignSpacing.lg,
              vertical: NexoDesignSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NexoDesignRadii.md),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
    );
  }
}

/// Helper to show a NexoDialog and return the result.
Future<T?> showNexoDialog<T>(
  BuildContext context, {
  required String title,
  String? description,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool isDestructive = false,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => NexoDialog(
      title: title,
      description: description,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onConfirm: onConfirm,
      onCancel: onCancel,
      isDestructive: isDestructive,
    ),
  );
}
