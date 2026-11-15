# NEXO — Agenda de Contactos Premium

Agenda de contactos moderna, elegante y tecnológica con identidad visual propia basada en **azul noche (Night Blue)** y **azul eléctrico**. Diseñada como un producto comercial profesional, no una plantilla genérica.

---

## 📱 Pantallas

| Pantalla | Estado |
|----------|--------|
| **Inicio** | ✅ Rediseñada (BUILD 6.8.2.5) |
| **Contactos** | ⏳ Pendiente |
| **Colecciones** | ⏳ Pendiente |
| **Ajustes** | ✅ Parcial (selector de apariencia) |
| **Ficha de contacto** | ⏳ Pendiente |

---

## 🎨 Identidad Visual

### Tema Oscuro (Night Blue — predeterminado)

| Token | Valor |
|-------|-------|
| Fondo principal | `#071629` |
| Superficie | `#0B1C30` |
| Superficie elevada | `#10243C` |
| Borde discreto | `#223A56` |
| Azul eléctrico (acento) | `#438BFF` |
| Texto principal | `#F1F5F9` |
| Texto secundario | `#A8B8CC` |
| Favoritos (estrella) | `#F4B942` |

### Tema Claro

| Token | Valor |
|-------|-------|
| Fondo principal | `#F3F6FB` |
| Superficie | `#FFFFFF` |
| Superficie elevada | `#EAF0F8` |
| Borde discreto | `#DCE5F0` |
| Azul NEXO (acento) | `#286FEA` |
| Texto principal | `#14243A` |
| Texto secundario | `#52647C` |
| Favoritos (estrella) | `#D99A18` |

---

## 🚀 Características

- **Sistema de temas**: Claro, Oscuro y Automático (sigue el sistema Android), con persistencia de preferencia.
- **Pantalla de Inicio**: Encabezado NEXO, buscador integrado, favoritos con avatares, próximos cumpleaños en formato de agenda y contactos recientes en lista unificada.
- **Barra de navegación inferior**: 4 pestañas (Inicio, Contactos, Colecciones, Ajustes) físicamente separada de la navegación del sistema Android.
- **Detección de duplicados**: Importación inteligente con puntuación de confianza.
- **Fotografías**: Límite de 5MB, validación de imagen y enriquecimiento de contactos existentes.
- **Cumpleaños**: Cálculo de próximas fechas con política para 29 de febrero.
- **Importación/Exportación**: VCF, CSV y JSON con detección de duplicados durante la misma importación.

---

## 🛠️ Arquitectura

- **Framework**: Flutter
- **Gestión de estado**: Riverpod
- **Base de datos**: Drift (SQLite)
- **Arquitectura**: Por features (capas de dominio, datos y presentación)
- **ID de aplicación**: `com.nexo.nexo`

---

## 📦 Builds

| BUILD | Trabajo | Estado |
|-------|---------|--------|
| 6.8.1.7 | Integración QA → Producción | Cerrado |
| 6.8.2.0 | Rediseño Inicio + navegación inferior | Superado |
| 6.8.2.1 | Refinamiento visual | Rechazado |
| 6.8.2.2 | Reconstrucción visual | Rechazado |
| 6.8.2.3 | Diseño oficial + sistema claro/oscuro | Rechazado |
| 6.8.2.4 | Auditoría y corrección temas | Superado |
| 6.8.2.5 | Rediseño real Inicio + nav inferior | **En desarrollo** |

---

## 🔧 Comandos Útiles

```bash
# Análisis estático
flutter analyze

# Ejecutar pruebas
flutter test

# Construir APK de producción
flutter build apk --release --flavor production

# Ejecutar en modo debug
flutter run
```

---

## 📄 Notas

- No se modifica el esquema de base de datos ni se crean migraciones.
- No se borran datos de usuario.
- `applicationId` se mantiene como `com.nexo.nexo`.
- El APK de producción se firma con la clave de depuración.

---

*Desarrollado con Flutter y Riverpod. Diseño Night Blue premium.*