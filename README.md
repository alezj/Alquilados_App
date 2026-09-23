# Alquilados App

Aplicación móvil en Flutter para Android e iOS, concebida como cliente de la API REST existente de **Alquilados** (ASP.NET Core / C#). La app no crea un backend propio ni accede directamente a SQL Server.

```text
Flutter Mobile ── HTTPS / REST / JSON ──> ASP.NET Core API ──> SQL Server
```

## Estado del desarrollo

El proyecto está en una etapa temprana de cimentación técnica. Las fases iniciales de plataforma, dependencias, sistema visual e infraestructura base están completadas; el MVP funcional todavía no ha comenzado.

Estado validado actualmente:

- `flutter analyze`: sin incidencias.
- `flutter test`: 22 pruebas pasan.
- Hay cambios locales sin confirmar correspondientes a esta memoria y al cierre técnico de la Fase 5.

## Implementado

- Proyecto Flutter configurado para Android, iOS y Web.
- Material 3, tema claro/oscuro, colores y tipografías centralizadas.
- Componentes reutilizables: `AppButton`, `AppCard`, `AppTextField`, `AppLoading`, `AppError`, `AppEmpty` y `StatusBadge`.
- Pantalla temporal de demostración del sistema visual (`/design-system`).
- Riverpod instalado y `ProviderScope` configurado en la raíz.
- Configuración por ambiente con `--dart-define`: `APP_ENV`, `API_BASE_URL`, `ENABLE_LOGS` y timeouts HTTP.
- Cliente HTTP centralizado con Dio: headers JSON, métodos HTTP, interceptor JWT, logging y mapeo de errores a excepciones tipadas.
- Servicio de almacenamiento seguro para access token, refresh token y datos de usuario.
- Providers iniciales para `SecureStorageService` y `ApiClient`.
- Módulo `features/propiedades` con separación `Data / Domain / Presentation`:
  - contrato real `{ success, data }` y modelo de propiedad;
  - consulta a `GET /api/Backend/propiedades`;
  - repositorio y provider de Riverpod;
  - listado, búsqueda local, actualización por gesto, y estados loading/error/empty.
- Módulo `features/inquilinos` conectado a `GET /api/Backend/inquilinos`, con listado, búsqueda local y estados de interfaz.
- Módulo `features/pagos` conectado a `GET /api/Backend/pagos`, con listado, actualización por gesto y estados de interfaz.
- Rutas declaradas con GoRouter:
  - `/login`
  - `/dashboard`
  - `/propiedades` y `/propiedades/:id`
  - `/inquilinos` y `/inquilinos/:id`
  - `/pagos`
  - `/configuracion`
- Pruebas iniciales de extensiones, errores, cliente HTTP y almacenamiento seguro.
- `.gitignore` preparado para Flutter, artefactos de compilación y secretos.

## Aún pendiente

- Estructura modular `features/` y capas `Data / Domain / Presentation` por funcionalidad.
- DTOs, entidades, repositorios, casos de uso y fuentes remotas.
- Splash, login, recuperación de sesión, refresh token y logout reales.
- Guardias de rutas, redirecciones y rutas protegidas.
- Dashboard, propiedades, inquilinos, pagos, perfil y configuración funcionales.
- Búsqueda, filtros, paginación, caché, offline e integraciones futuras.
- Integración y builds validados para Android e iOS.
- Pruebas de integración.

## Persistencia local SQLite y sincronización manual

Para la siguiente etapa del desarrollo, la aplicación no dependerá de autenticación ni de sesiones reales. Se añadirá una capa local de persistencia con SQLite para que la app pueda trabajar con datos cacheados y permitir sincronización manual desde una acción explícita del usuario.

### Objetivo

- Mantener la app operativa aunque la API no esté disponible o responda lentamente.
- Guardar los datos más relevantes del negocio en una base local en formato SQLite `.db3`.
- Permitir sincronizar la información local con la API REST cuando el usuario lo decida.
- Preparar la arquitectura para un futuro offline más robusto, sin necesidad de reescribir la aplicación.

### Archivo de base local

- Nombre sugerido: `alquilados_local.db3`
- Ubicación: directorio de la aplicación del sistema operativo, gestionado por Flutter (`getDatabasesPath` o equivalente).
- Motor: SQLite nativo, usando `sqflite` o una capa de acceso local con abstracción para cambiar el driver si es necesario.

### Tablas mínimas requeridas

```sql
CREATE TABLE propiedades (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  direccion TEXT,
  estado INTEGER,
  precio_mensual REAL,
  notas TEXT,
  updated_at TEXT DEFAULT (datetime('now')),
  synced_at TEXT,
  sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
);

CREATE TABLE inquilinos (
  id INTEGER PRIMARY KEY,
  nombre_apellido TEXT NOT NULL,
  correo TEXT,
  fecha_inicio_contrato TEXT,
  fecha_pagos INTEGER,
  updated_at TEXT DEFAULT (datetime('now')),
  synced_at TEXT,
  sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
);

CREATE TABLE pagos (
  id INTEGER PRIMARY KEY,
  id_inquilino TEXT,
  fecha_pago TEXT,
  monto REAL,
  estado TEXT,
  updated_at TEXT DEFAULT (datetime('now')),
  synced_at TEXT,
  sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
);

CREATE TABLE sync_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_name TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  message TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);
```

### Regla de negocio local

- La caché local será la fuente de verdad mientras no exista sincronización.
- Los registros que se hayan modificado se marcan con `sync_state = 'pending'`.
- Cuando el usuario pulsa el botón de sincronización, la app:
  1. lee la cola de pendientes;
  2. envía los cambios a la API REST;
  3. marca el registro como `synced` si responde correctamente;
  4. registra un evento en `sync_log`;
  5. muestra feedback visual en UI.

### Botón de sincronización

La interfaz incluirá un botón de acción en la pantalla principal o en la app bar del módulo de datos, por ejemplo:

- `Sincronizar`
- `Actualizar datos`
- `Sincronizar ahora`

Comportamiento esperado:

- Si hay conexión disponible y hay registros pendientes, se ejecuta la sincronización.
- Si no hay registros pendientes, la app muestra un estado de `Todo actualizado` o equivalente.
- Si falla la sincronización, se conserva el registro local con `sync_state = 'error'` y se registra el error.
- La UI debe mostrar `loading`, `success`, `error` y `empty` según el estado.

### Capa de persistencia propuesta

```text
UI
  ↓
State / Provider
  ↓
Repository
  ↓
Local SQLite Data Source
  ↓
SQLite .db3
```

Y en el flujo de sincronización:

```text
UI
  ↓
Sync Use Case
  ↓
Repository
  ↓
Local pending rows
  ↓
API REST
  ↓
Local update status / sync_log
```

### Reglas para esta etapa

- Se ignora por ahora la autenticación JWT y la protección por sesión.
- La sincronización será manual y accionada por el usuario.
- La API es la última fuente de verdad cuando exista conexión.
- La app no debe bloquear la UX si la red falla; debe guardar los cambios y reintentar luego.

### Siguiente implementación recomendada

1. Crear la base `alquilados_local.db3` con las tablas anteriores.
2. Implementar un `LocalDatabaseService` con `sqflite`.
3. Añadir un `SyncRepository` y `SyncProvider`.
4. Crear una acción de usuario en la UI con el botón `Sincronizar`.
5. Registrar resultados en `sync_log` y marcar `sync_state`.
6. Preparar la app para cache, reintento y evolución a modo offline.

## Fases del plan

| Fase | Estado |
| --- | --- |
| 1. Crear proyecto | Completada |
| 2. Arquitectura | Parcial: existe `core/`, falta `features/` y las capas por dominio |
| 3. Dependencias | Completada en configuración |
| 4. Theme y componentes | Mayormente completada |
| 5. API Client | Completada técnicamente: infraestructura creada y validada; integración real pendiente de contrato API |
| 6. Autenticación | Pospuesta como deuda técnica para la etapa inicial |
| 7. Routing | Parcial: rutas base creadas, faltan guards y sesión |
| 8. Dashboard | Pendiente: no existe endpoint específico |
| 9. Propiedades | Parcial: listado y búsqueda implementados; detalle y edición pendientes |
| 10. Inquilinos | Parcial: listado y búsqueda implementados; detalle y edición pendientes |
| 11. Pagos | Parcial: listado implementado; detalle, estados y edición pendientes |
| 12. SQLite local + sincronización manual | En preparación |
| 13–14. Pruebas ampliadas y builds | Pendientes |

## Validación y dependencia pendiente

La compilación ya está saneada: se corrigieron los callbacks de red, se adaptó `flutter_secure_storage` a la versión instalada y se eliminaron los avisos del analizador.

El único bloqueo para iniciar autenticación real es disponer del contrato de la API.

## Deuda técnica: autenticación

Por decisión de la etapa inicial, la aplicación continuará **sin autenticación real**. La Fase 6 queda pospuesta para permitir avanzar con los módulos funcionales que el backend ya expone.

Implicaciones aceptadas en esta etapa:

- No habrá login, logout, recuperación de sesión, perfil ni refresh token.
- Las rutas no estarán protegidas por sesión o roles.
- El interceptor JWT y el almacenamiento seguro permanecen como infraestructura preparada, pero no estarán conectados a un flujo real.
- La aplicación solo debe usarse en un entorno de desarrollo controlado mientras los endpoints no requieran autorización.

Antes de una prueba pública, distribución a usuarios o paso a producción se deberá cerrar esta deuda mediante un diseño de autenticación en el backend y la implementación del módulo `auth` en Flutter.

## API: fuente de verdad

Se revisó el backend ASP.NET Core en `backend/Controllers/BackendController.cs`. Los endpoints disponibles están centralizados en `lib/core/constants/api_endpoints.dart`; la base URL local es `http://localhost:5129/api`.

Endpoints de consulta disponibles:

- `GET /api/Backend/status`
- `GET /api/Backend/inquilinos`, `/estados`, `/pagos`, `/propiedades`, `/mantenimientos` y `/alquileres`

El backend permite crear, actualizar y eliminar propiedades mediante `/api/Backend/propiedades` y operaciones genéricas para inquilinos, pagos, mantenimientos, alquileres y estados.

No existen actualmente endpoints para autenticación, detalle individual, dashboard, perfil, configuración o refresh token. Tampoco se observó configuración JWT ni middleware de autenticación/autorización. La autenticación se ha registrado como deuda técnica para la etapa inicial.

Antes de implementar una integración se debe proporcionar y usar como fuente de verdad uno de estos recursos:

- Swagger / OpenAPI;
- controllers de ASP.NET Core;
- DTOs;
- ejemplos JSON reales;
- documentación de endpoints y códigos HTTP.

No se deben inventar endpoints, propiedades JSON, tipos de datos ni respuestas de la API.

> Seguridad: la configuración actual del backend contiene credenciales SMTP en texto plano. Deben rotarse y migrarse a secretos de entorno antes de publicar o compartir el repositorio.

## Próximo hito

1. Iniciar el siguiente módulo funcional disponible en el backend: propiedades, inquilinos, pagos o alquileres.
2. Implementar posteriormente la Fase 6 como deuda técnica: contrato de autenticación en backend y módulo `auth` con sesión, logout y guards de GoRouter.

## MVP objetivo

El MVP incluirá splash, login, dashboard, propiedades y su detalle, inquilinos y su detalle, pagos, perfil/configuración y logout; todo conectado a la API REST existente.

## Principios de trabajo

- Una única base Flutter para Android e iOS.
- Flutter es cliente: `Flutter → API REST → ASP.NET Core → SQL Server`.
- Mantener separación de responsabilidades, pruebas, seguridad y configuración por ambiente.
- No guardar secretos, contraseñas ni tokens en Git.
- Avanzar por fases y no continuar una fase mientras existan errores en ella.
