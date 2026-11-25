# Decisión de producto: gestor de contactos de NEXO

**Estado:** decidido para una fase futura; no iniciar todavía la implementación.

## Camino elegido

**Camino 2: agenda propia de NEXO con funciones ampliadas de gestor de contactos.**

NEXO conservará su propia base de datos local como fuente principal. La integración con los contactos de Android será opcional y explícita, mediante importación y exportación con vista previa y confirmación.

## Alcance previsto

- Mantener y consolidar la agenda actual.
- Añadir progresivamente notas, campos personalizados, etiquetas y grupos avanzados, filtros, recordatorios e historial de interacciones propio de NEXO.
- Mejorar la detección y revisión manual de posibles duplicados.
- Permitir importar y exportar contactos de Android sin sincronización automática ni sobrescrituras silenciosas.
- Mantener las acciones de llamada como delegación a Android/la aplicación telefónica instalada.

## Fuera del alcance inicial

NEXO no sustituirá inicialmente a la aplicación Teléfono de Android. No se implementarán por ahora un servicio propio de llamadas entrantes/en curso, el rol de marcador predeterminado ni la gestión del registro telefónico del sistema.

## Orden y condiciones

Esta decisión queda aparcada hasta estabilizar y probar la versión actual de NEXO, especialmente persistencia, fotografías, direcciones, formularios, detalle y copias de seguridad.

La futura implementación debe respetar la arquitectura y los datos existentes. No se debe introducir sincronización automática ni modificar/eliminar datos existentes sin una acción explícita del usuario.
