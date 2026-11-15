import 'dart:io';

import '../../services/media/media_service.dart';
import 'package:flutter/material.dart';
import '../../core/design/nexo_design_system.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/design/components/nexo_button.dart';

/// ============================================================================
/// NexoEmptyState — Reusable empty state component.
/// Uses the NEXO design system for colors, spacing, and typography.
/// ============================================================================

class NexoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const NexoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NexoDesignSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: NexoDesignColors.textTertiary),
            const SizedBox(height: NexoDesignSpacing.lg),
            Text(
              title,
              style: NexoDesignTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: NexoDesignSpacing.sm),
              Text(
                subtitle!,
                style: NexoDesignTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: NexoDesignSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// NexoErrorState — Reusable error state component.
/// Uses the NEXO design system for colors, spacing, and typography.
/// ============================================================================

class NexoErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const NexoErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NexoDesignSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: NexoDesignColors.error),
            const SizedBox(height: NexoDesignSpacing.lg),
            Text(
              message,
              style: NexoDesignTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: NexoDesignSpacing.xl),
              NexoButton(
                onPressed: onRetry,
                variant: NexoButtonVariant.text,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// NexoLoading — Reusable loading indicator component.
/// Uses the NEXO accent color.
/// ============================================================================

class NexoLoading extends StatelessWidget {
  const NexoLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: NexoDesignColors.accent),
    );
  }
}

/// ============================================================================
/// NexoAvatar — Reusable avatar component showing photo or initials.
/// Usa [tokens] para adaptarse al tema activo; si no se proveen, usa colores
/// del tema oscuro por defecto (compatibilidad con otras pantallas).
class NexoAvatar extends StatelessWidget {
  final String? photoPath;
  final String displayName;
  final double size;
  final NexoDesignTokens? tokens;

  const NexoAvatar({
    super.key,
    this.photoPath,
    required this.displayName,
    this.size = 44,
    this.tokens,
  });

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  NexoDesignTokens get _effectiveTokens {
    if (tokens != null) return tokens!;
    return const NexoDesignTokens(isDark: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _effectiveTokens;
    if (photoPath == null || photoPath!.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: t.surfaceHigh,
        child: Text(
          _initials,
          style: TextStyle(
            color: t.textSecondary,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return FutureBuilder<File?>(
      future: MediaService().resolve(photoPath!),
      builder: (context, snap) {
        final file = snap.data;
        if (file != null) {
          return CircleAvatar(radius: size / 2, backgroundImage: FileImage(file));
        }
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: t.surfaceHigh,
          child: Text(
            _initials,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }
}
