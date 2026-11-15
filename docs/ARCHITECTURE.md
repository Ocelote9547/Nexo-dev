# NEXO — Arquitectura (BUILD 1)

## Capas

- **Core**: providers (Riverpod), constantes, errores, utilidades.
- **Database**: Drift tables, DAOs, migraciones, AppDatabase.
- **Domain**: entidades y casos de uso (pendiente de implementar en fases siguientes).
- **Data**: implementaciones de repositorios.
- **Repositories**: interfaces de acceso a datos.
- **Services**: MediaService (archivos privados), import/export (futuro).
- **Features**: UI y controladores por funcionalidad (futuro).
- **Shared**: widgets y utilidades comunes.

## Persistencia

- Drift sobre SQLite.
- UUID v4 como identificadores.
- FK con ON DELETE CASCADE.
- Relaciones N:M con PK compuesta.
- PRAGMA foreign_keys = ON.
- FTS5 disponible (ENABLE_FTS5=1).

## Multimedia

- Archivos en directorio privado `media/contacts/<id>/`.
- BD almacena rutas relativas + sha256.
- No blobs en tablas principales.

## Migraciones

- schemaVersion = 1.
- onCreate: createAll.
- onUpgrade: placeholder para futuras migraciones.
- beforeOpen: activa FK.

## Providers

- appDatabaseProvider: AppDatabase (NativeDatabase).
- fts5AvailableProvider: FutureProvider<bool>.
- mediaServiceProvider: MediaService.
