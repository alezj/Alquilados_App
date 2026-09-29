# Alquilados App

Aplicación móvil en Flutter para gestión de alquileres con enfoque local-first. La app trabaja sobre SQLite como fuente de verdad mientras no exista sincronización real con una API remota, y ya cubre operaciones básicas de inmuebles, inquilinos y pagos.

## Estado actual del proyecto

El proyecto está en una etapa funcional intermedia: la base técnica está consolidada, el flujo local de datos está operativo y el módulo de pagos ya soporta alta, edición, eliminación y generación de comprobante no fiscal.

La app sigue siendo una solución local/operativa para gestión inmobiliaria, no una solución fiscal o de facturación legal completa.

## Implementado

- Proyecto Flutter configurado para Android, iOS y Web.
- Arquitectura con `core/` y módulos en `features/`.
- Persistencia local SQLite con tablas para propiedades, inquilinos, pagos y `sync_log`.
- Provider de Riverpod para listado, detalle y filtros.
- Módulo de propiedades con listado, búsqueda y CRUD local.
- Módulo de inquilinos con detalle, historial de pagos y edición local.
- Módulo de pagos con:
  - listado,
  - filtro por estado y mes,
  - edición local,
  - cambio rápido de estado,
  - eliminación,
  - creación desde el botón “Nuevo pago”.
- Generación de comprobante no fiscal desde el detalle del pago.
- Vista previa en PDF con posibilidad de imprimir o compartir.
- Assets de branding y app icon actualizados en el proyecto.

## Flujo actual de pagos

La pantalla de pagos permite la gestión local completa, sin depender aún de la API real.

El flujo de creación local es:

1. Usuario pulsa el botón “Nuevo pago”.
2. Ingresa ID de inquilino, fecha, monto y estado.
3. Se guarda en SQLite.
4. La lista se actualiza automáticamente.

El detalle del pago permite:

- consultar la información del registro,
- cambiar estado (
  `pendiente`, `pagado`, `vencido`),
- editar el pago,
- eliminarlo,
- generar un comprobante no fiscal.

## Comprobante no fiscal

La app ya incluye un comprobante no fiscal que se puede generar desde el detalle de un pago usando los datos disponibles:

- nombre del inquilino,
- número del pago,
- fecha,
- estado,
- monto,
- concepto de alquiler.

No reemplaza una factura fiscal legal ni un documento con validación tributaria real.

## Validación reciente

Se validó la funcionalidad relevante con tests reales del proyecto utilizando Flutter:

```powershell
cd "C:\Archivos\Johancel\Proyectos\AlquilerMovil\Alquilados_App"; & "C:\Users\U31241\flutter\bin\flutter.bat" test
```

Resultado verificado:

- `All tests passed!`
- `LASTEXIT:0`

## Pendiente

Aún falta trabajo para llevar la app a nivel productivo completo:

- autenticación real,
- integración con backend/API de producción,
- sincronización remota confiable,
- contratos API definitivos,
- facturación fiscal/tributaria real,
- builds finales validados para distribución real,
- pruebas de integración más amplias.

## Estructura técnica relevante

- Landing y navegación base en `lib/`
- Persistencia local en `lib/features/sync/data/datasources/local_database_service.dart`
- Provider de pagos en `lib/features/pagos/presentation/providers/pagos_provider.dart`
- Pantalla principal de pagos en `lib/features/pagos/presentation/pages/pagos_page.dart`
- Detalle de pago en `lib/features/pagos/presentation/pages/pago_detalle_page.dart`
- Modelo de comprobante en `lib/features/pagos/domain/entities/comprobante_pago.dart`
- Generador PDF en `lib/features/pagos/data/services/comprobante_pago_service.dart`

## Resumen del estado

La aplicación ya está en una etapa útil de gestión local de alquileres, con flujo de pagos esencial completo y capacidad de comprobante no fiscal. La siguiente gran evolución es la integración real con API y la autenticación de negocio, no la base local ni la lógica de pagos en sí misma.

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
