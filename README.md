# NEXO 1.2 — Agenda de Contactos Premium

NEXO es una agenda de contactos para Android con diseño Night Blue, gestión local de información y herramientas para organizar contactos, favoritos, cumpleaños y colecciones.

**Versión actual:** 1.2.0  
**Build:** 12  
**Plataforma:** Android  
**Application ID (producción):** `com.nexo.nexo`

---

## Características

- **Contactos:** creación, edición, fichas de contacto y fotografías.
- **Favoritos y cumpleaños:** acceso rápido y vista de próximas fechas.
- **Colecciones y etiquetas:** organización de contactos.
- **Importación y exportación:** formatos VCF, CSV y JSON.
- **Privacidad:** protección mediante PIN y opción de autenticación biométrica en dispositivos compatibles.
- **Apariencia:** temas claro, oscuro y automático con identidad visual Night Blue.
- **Navegación:** Inicio, Contactos, Colecciones y Ajustes.

## Diseño

La identidad visual combina azul noche, superficies elevadas y acentos azules. Los favoritos y cumpleaños utilizan acentos dorados.

## Arquitectura y tecnología

- Flutter y Dart.
- Riverpod para gestión de estado.
- Drift sobre SQLite para almacenamiento local.
- Arquitectura organizada por funcionalidades.
- Identificadores UUID.
- Almacenamiento privado de fotografías y archivos de respaldo.

NEXO está planteada como una aplicación local: los datos de contactos se gestionan en el dispositivo. La única función que consulta Internet es el autocompletado opcional de direcciones mediante Photon (OpenStreetMap); solo se envía el texto de la dirección que se está buscando. La dirección también puede introducirse manualmente.

## Compilación

Requisitos: Flutter instalado y SDK de Android configurado.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --flavor production
```

El APK de producción utiliza el identificador `com.nexo.nexo`. El flavor QA utiliza `com.nexo.nexo.qa`.

## Versión 1.2

Esta versión reúne el refinamiento visual de las pantallas principales y de gestión de contactos, ajustes, privacidad, importación/exportación y navegación. También incorpora mejoras en la presentación del PIN y la navegación animada inferior.

## Búsqueda de direcciones

El autocompletado utiliza el servicio público Photon de Komoot, basado en datos de OpenStreetMap. El servicio puede limitar peticiones o no estar disponible; por eso la introducción manual sigue funcionando. Se muestran resultados con atribución a OpenStreetMap.

## Notas de seguridad y datos

- No se debe borrar ni reinicializar la base de datos para actualizar la aplicación.
- Mantener el mismo `applicationId` permite actualizar la instalación existente.
- La autenticación biométrica debe validarse en un dispositivo Android real compatible.
- La versión de la aplicación se define en `pubspec.yaml`; Flutter traslada esos valores a `versionName` y `versionCode` de Android.

---

*Desarrollado con Flutter. NEXO — tu agenda, organizada.*
