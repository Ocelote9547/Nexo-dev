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

  NexoDesignTokens _effectiveTokens(BuildContext context) {
    if (tokens != null) return tokens!;
    return NexoDesignTokens(
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _effectiveTokens(context);
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

/// Teclado numérico integrado para la entrada de PIN.
class NexoPinKeypad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  final int maxLength;

  const NexoPinKeypad({
    super.key,
    required this.controller,
    required this.onChanged,
    this.maxLength = 8,
  });

  void _press(String value) {
    final current = controller.text;
    if (value == '⌫') {
      if (current.isNotEmpty) {
        controller.text = current.substring(0, current.length - 1);
      }
    } else if (value == 'C') {
      controller.clear();
    } else if (current.length < maxLength) {
      controller.text = '$current$value';
    }
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'C'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      childAspectRatio: 2.0,
      children: keys.map((key) => OutlinedButton(
        onPressed: () => _press(key),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(key, style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        )),
      )).toList(),
    );
  }
}
