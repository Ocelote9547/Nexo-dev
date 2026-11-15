import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/design/nexo_design_system.dart';

/// Modo de tema disponible en NEXO.
enum NexoThemeMode {
  system,
  light,
  dark;

  /// Nombre usado para persistir la preferencia en almacenamiento seguro.
  String get storageValue {
    switch (this) {
      case NexoThemeMode.system:
        return 'system';
      case NexoThemeMode.light:
        return 'light';
      case NexoThemeMode.dark:
        return 'dark';
    }
  }

  /// Construye un [NexoThemeMode] a partir de su valor almacenado.
  static NexoThemeMode fromStorage(String? value) {
    switch (value) {
      case 'light':
        return NexoThemeMode.light;
      case 'dark':
        return NexoThemeMode.dark;
      case 'system':
      default:
        return NexoThemeMode.system;
    }
  }
}

/// Clave de almacenamiento para la preferencia de tema.
const _kThemeModeKey = 'nexo_theme_mode';

/// Almacenamiento seguro para persistir la preferencia de tema.
final _secureStorage = FlutterSecureStorage();

/// Notifier del modo de tema con persistencia.
///
/// Para instalaciones nuevas, el valor predeterminado es [NexoThemeMode.dark].
/// Cuando existe una preferencia guardada, se carga de forma asíncrona y se
/// aplica de forma reactiva sobre el valor inicial.
class NexoThemeModeNotifier extends Notifier<NexoThemeMode> {
  bool _loaded = false;

  @override
  NexoThemeMode build() {
    // Instalación nueva: modo oscuro por defecto.
    // La preferencia guardada se carga en segundo plano y se aplica al terminar.
    _load();
    return NexoThemeMode.dark;
  }

  /// Carga la preferencia guardada y la aplica si existe.
  Future<void> _load() async {
    try {
      final raw = await _secureStorage.read(key: _kThemeModeKey);
      if (raw != null && !_loaded) {
        _loaded = true;
        state = NexoThemeMode.fromStorage(raw);
      }
    } catch (_) {
      // Si falla la lectura, se mantiene el valor por defecto (oscuro).
    }
  }

  /// Guarda y aplica un nuevo modo de tema.
  Future<void> setMode(NexoThemeMode mode) async {
    state = mode;
    try {
      await _secureStorage.write(key: _kThemeModeKey, value: mode.storageValue);
    } catch (_) {
      // Si falla la escritura, se mantiene el estado en memoria.
    }
  }
}

/// Provider del modo de tema actual.
final nexoThemeModeProvider =
    NotifierProvider<NexoThemeModeNotifier, NexoThemeMode>(
  NexoThemeModeNotifier.new,
);

/// Resuelve el [ThemeMode] de Flutter a partir del [NexoThemeMode] y el
/// brillo del sistema (para el modo automático).
ThemeMode resolveThemeMode(NexoThemeMode mode, Brightness platformBrightness) {
  switch (mode) {
    case NexoThemeMode.light:
      return ThemeMode.light;
    case NexoThemeMode.dark:
      return ThemeMode.dark;
    case NexoThemeMode.system:
      return platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }
}

/// Resuelve los colores de diseño activos según el tema.
/// Devuelve [NexoDesignColors] para oscuro o [NexoDesignLightColors] para claro.
class NexoDesignTokens {
  final bool isDark;

  const NexoDesignTokens({required this.isDark});

  // Backgrounds
  Color get background => isDark ? NexoDesignColors.background : NexoDesignLightColors.background;
  Color get surfaceSecondary => isDark
      ? NexoDesignColors.surfaceSecondary
      : NexoDesignLightColors.surfaceSecondary;
  Color get surface => isDark ? NexoDesignColors.surface : NexoDesignLightColors.surface;
  Color get surfaceElevated => isDark
      ? NexoDesignColors.surfaceElevated
      : NexoDesignLightColors.surfaceElevated;
  Color get surfaceHigh => isDark ? NexoDesignColors.surfaceHigh : NexoDesignLightColors.surfaceHigh;

  // Borders & dividers
  Color get border => isDark ? NexoDesignColors.border : NexoDesignLightColors.border;
  Color get borderFocus => isDark ? NexoDesignColors.borderFocus : NexoDesignLightColors.borderFocus;
  Color get separator => isDark ? NexoDesignColors.separator : NexoDesignLightColors.separator;

  // Accent
  Color get accent => isDark ? NexoDesignColors.accent : NexoDesignLightColors.accent;
  Color get accentBright => isDark ? NexoDesignColors.accentBright : NexoDesignLightColors.accentBright;
  Color get accentSelected => isDark ? NexoDesignColors.accentSelected : NexoDesignLightColors.accentSelected;
  Color get accentSoft => isDark ? NexoDesignColors.accentSoft : NexoDesignLightColors.accentSoft;

  // Text
  Color get textPrimary => isDark ? NexoDesignColors.textPrimary : NexoDesignLightColors.textPrimary;
  Color get textSecondary => isDark ? NexoDesignColors.textSecondary : NexoDesignLightColors.textSecondary;
  Color get textTertiary => isDark ? NexoDesignColors.textTertiary : NexoDesignLightColors.textTertiary;
  Color get textDisabled => isDark ? NexoDesignColors.textDisabled : NexoDesignLightColors.textDisabled;

  // Status
  Color get success => isDark ? NexoDesignColors.success : NexoDesignLightColors.success;
  Color get warning => isDark ? NexoDesignColors.warning : NexoDesignLightColors.warning;
  Color get error => isDark ? NexoDesignColors.error : NexoDesignLightColors.error;
  Color get favorite => isDark ? NexoDesignColors.favorite : NexoDesignLightColors.favorite;
}

/// Extensión para obtener los tokens activos desde un WidgetRef.
extension NexoDesignTokensRef on WidgetRef {
  NexoDesignTokens tokens(BuildContext context) {
    final mode = watch(nexoThemeModeProvider);
    final brightness = MediaUtils.platformBrightnessOf(context);
    final isDark = mode == NexoThemeMode.dark ||
        (mode == NexoThemeMode.system && brightness == Brightness.dark);
    return NexoDesignTokens(isDark: isDark);
  }
}

/// Utilidad para leer el brillo del sistema.
class MediaUtils {
  static Brightness platformBrightnessOf(BuildContext context) {
    return MediaQuery.of(context).platformBrightness;
  }
}