# NEXO — Historial de Builds

| BUILD | Trabajo | Estado |
|-------|---------|--------|
| BUILDs anteriores | Trabajo y correcciones anteriores | CERRADOS |
| BUILD 6.8.1.7 | Integración QA → PRODUCCIÓN | CERRADO |
| BUILD 6.8.2.0 | Rediseño Inicio + navegación inferior | SUPERADO |
| BUILD 6.8.2.1 | Refinamiento visual de Inicio y navegación inferior | RECHAZADO VISUALMENTE |
| BUILD 6.8.2.2 | Reconstrucción visual de Inicio y navegación inferior | RECHAZADO VISUALMENTE |
| BUILD 6.8.2.3 | Implementación diseño oficial Inicio + navegación inferior + sistema claro/oscuro | RECHAZADO (no validado) |
| BUILD 6.8.2.4 | Auditoría y corrección del sistema de temas + selector de apariencia en Ajustes | SUPERADO |
| BUILD 6.8.2.5 | Rediseño real de Inicio + corrección definitiva navegación inferior | PENDIENTE DE VALIDACIÓN |

## Notas

- BUILD 6.8.2.5 incluye: pantalla de Inicio con composición completamente nueva, barra de navegación inferior con separación física de navegación Android, sistema de temas claro/oscuro/sistema con persistencia, selector de apariencia en Ajustes.
- Cambios principales respecto a 6.8.2.4: composición editorial de Inicio (menos espacio vacío, secciones más integradas), barra inferior con altura de contenido 74dp + insets de Android (sin SafeArea dentro del contenedor fijo), iconos 18dp, etiquetas 10dp, mejor separación de navegación Android.
- No se modifican: Contactos, Colecciones, ContactDetail, ni ningún otro módulo.
- No se modifica el `applicationId`: `com.nexo.nexo`.
- No se modifica el esquema de base de datos.
- No se borran datos de usuario.
- Pendiente de validación visual manual por el usuario en modo claro y oscuro.