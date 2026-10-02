# Alquilados App

Aplicación Flutter para la gestión local de alquileres, propiedades, inquilinos y pagos. El proyecto sigue un enfoque local-first con SQLite como fuente de verdad, y está estructurado con `Flutter + Riverpod + GoRouter + SQLite`.

## Estado actual

La app ya incluye la base técnica operativa para gestión inmobiliaria y el módulo de alquileres quedó integrado de manera compatible con el resto del sistema. El proyecto funciona como una herramienta local de administración de inmuebles, con datos persistidos en dispositivo y flujo de navegación basado en pestañas y rutas de detalle.

## Funcionalidades implementadas

- Proyecto Flutter con soporte para Android, iOS y Web.
- Arquitectura por capas con `core/` y `features/`.
- Persistencia local con SQLite en `LocalDatabaseService`.
- Módulo de propiedades con listado, detalle y estado local.
- Módulo de inquilinos con edición y consulta local.
- Módulo de pagos con:
  - listado,
  - filtro por estado,
  - edición local,
  - cambio de estado,
  - eliminación,
  - comprobante no fiscal.
- Módulo de alquileres con:
  - listado,
  - búsqueda por propiedad/inquilino/estado,
  - filtros por estado,
  - creación y edición de contratos,
  - monto acordado con el inquilino,
  - cantidad de depósitos y día mensual de pago,
  - validación del día de pago entre 1 y 31,
  - eliminación,
  - detalle del alquiler,
  - vinculación con propiedad, inquilino y pagos,
  - estado del alquiler y resumen financiero básico.
- Navegación principal con bottom navigation y rutas de detalle.
- Dashboard con resumen visual de propiedades, inquilinos y alquileres.
- Generación de PDF de comprobante de pago.
- Soporte de datos semilla para pruebas locales.

## Arquitectura actual

La estructura principal del proyecto es la siguiente:

- `lib/core/` — configuración, rutas, tema, widgets compartidos y utilidades base.
- `lib/features/` — módulos funcionales: `dashboard`, `propiedades`, `inquilinos`, `pagos`, `alquileres`, `sync`, `configuracion`.
- `lib/features/sync/data/datasources/local_database_service.dart` — almacenamiento local y migraciones.
- `lib/features/alquileres/` — entidad, provider, listado y detalle del módulo de alquileres.

## Base de datos local

La app guarda la información en SQLite con tablas como:

- `propiedades`
- `inquilinos`
- `pagos`
- `alquileres`
- `sync_log`

La capa de base de datos incluye creación automática, migración incremental y esquema compatible con versiones previas del proyecto. También se mantiene el flujo local de sincronización para la app.

En plataformas no web, el archivo se llama `alquilados_local.db3` y se guarda en el directorio que devuelve `getDownloadsDirectory()` de `path_provider`. En Web se abre con el nombre `alquilados_local.db3` a través del almacenamiento web; no corresponde a un archivo normal dentro de la carpeta del proyecto.

La tabla `alquileres` incluye, entre otros, estos campos:

- `propiedad_id` e `inquilino_id`: relaciones con la propiedad y el inquilino.
- `fecha_inicio` y `fecha_fin`: vigencia del alquiler.
- `importe`: importe base del alquiler.
- `montoPago`: monto acordado a pagar por el inquilino.
- `cantidadDepositos`: cantidad de depósitos.
- `diaPago`: día del mes previsto para el pago (entre 1 y 31 en el formulario).
- `estado`: estado del alquiler.

## Módulo de alquileres

El módulo de alquileres ya integra la relación con:

- propiedad asociada,
- inquilino asociado,
- estado del contrato,
- importe mensual o total del alquiler,
- historial de pagos relacionados.

La pantalla de detalle muestra:

- propiedad,
- inquilino,
- fechas del alquiler,
- monto acordado,
- cantidad de depósitos y día de pago,
- estado,
- pagos vinculados.

## Estado de validación

Se validó el proyecto con análisis estático de Flutter:

```powershell
cd "C:\Archivos\Johancel\Proyectos\AlquilerMovil\Alquilados_App"; flutter analyze
```

Resultado verificado:

- `No issues found!`
- `Exit code: 0`

También se validó la ejecución real con:

```powershell
cd "C:\Archivos\Johancel\Proyectos\AlquilerMovil\Alquilados_App"; flutter run
```

Resultado verificado:

- arranque correcto en modo debug,
- la app queda en ejecución sin bloqueos de compilación.

## Pendiente y deuda técnica

Lo siguiente sigue siendo parte del trabajo pendiente para una versión más productiva:

- autenticación real,
- backend/API remota definitiva,
- sincronización real con servidor,
- contratos REST más formales,
- validaciones de negocio avanzadas,
- facturación fiscal/tributaria legal,
- distribución final y despliegue.

## Principios del proyecto

- Prioridad a la gestión local y funcional sin depender de una API aún no estabilizada.
- Mantener compatibilidad con las pantallas ya existentes.
- Reusar la misma estructura por features y lógica local estable.
- Avanzar por pasos sin romper funcionalidad anterior.

## Uso local

Para trabajar en local:

```powershell
cd "C:\Archivos\Johancel\Proyectos\AlquilerMovil\Alquilados_App"
flutter pub get
flutter run
```

## Objetivo del MVP actual

El objetivo inmediato del proyecto es cubrir la gestión operativa local de alquileres con una base sólida para futuras integraciones de backend y sincronización. La app ya está preparada para evolucionar desde un flujo local validado hacia una solución con API y automatización real.
