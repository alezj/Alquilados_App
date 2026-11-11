# ESTATUS.md - Seguimiento de Estatus de Procesos y Solicitudes

## Propósito
Este documento registra el estatus actual de todos los procesos y solicitudes en curso dentro de la aplicación Alquilados App. Está diseñado para garantizar la continuidad del trabajo en caso de pérdida de conexión, expiración de tokens o interrupciones inesperadas.

## Filosofía de Rastreo
- **Local-first**: El estatus se guarda localmente antes de cualquier operación remota
- **Atomicidad**: Cada proceso marca su estatus antes y después de ejecutarse
- **Recuperación**: En caso de fallo, la aplicación puede reanudar desde el último estatus conocido

## Estatus Globales del Sistema

### Sincronización (Sync)
| Estatus | Descripción | Acción Recomendada |
|---------|-------------|-------------------|
| `PENDING` | Esperando sincronización | Ejecutar sync manual o esperar conexión |
| `IN_PROGRESS` | Sincronización en curso | Esperar completar o cancelar |
| `COMPLETED` | Sincronización exitosa | Ninguna |
| `FAILED` | Sincronización fallida | Reintentar o revisar logs |
| `CANCELLED` | Sincronización cancelada | Revisar qué operaciones no se completaron |

### Autenticación (Auth)
| Estatus | Descripción | Acción Recomendada |
|---------|-------------|-------------------|
| `NOT_STARTED` | No se ha intentado autenticación | Iniciar flujo de login |
| `IN_PROGRESS` | Flujo de auth en curso | Esperar completar |
| `TOKEN_VALID` | Token válido y activo | Proceed with operations |
| `TOKEN_EXPIRED` | Token expirado | Renovar token |
| `AUTH_FAILED` | Fallo en autenticación | Reingresar credenciales |
| `OFFLINE_MODE` | Modo offline activado | Funcionalidad limitada |

### Inicio de sesión con `usuarioSesion` y ambientes
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-11
**Fecha Fin**: 2026-11-11 08:42:08
**Última Actualización**: 2026-11-11 08:42:08
**Progreso**: 100%
**Comentario**: Login integrado con get_email_by_username(p_username) y validación de contraseña, perfil activo/aprobado y empresa. Johancel inicia en Alquilados_Test por defecto y puede elegir producción; otros usuarios usan producción sin selector. Configuración muestra Cambiar ambiente únicamente a Johancel y solicita autenticarse nuevamente. Registro envía usuarioSesion. SQLite de pruebas usa prefijo test_ y producción conserva los archivos existentes; contexto de ambiente/empresa se conserva en almacenamiento seguro y se restauran las conexiones al reiniciar. Los proveedores se invalidan después del login para actualizar datos y sincronización.
**Verificación remota**: Ambos proyectos activos, RPC accesible mediante sus publishable keys (HTTP 200), perfil Johancel activo/aprobado con empresa aprobada en ambos. No se modificaron esquemas ni datos remotos.
**Pruebas**: 85 aprobadas y 2 fallos en módulos sin cambios: alquiler_entity_test (6000 esperado frente a 28000) y comprobante_pago_service_test (guion largo esperado frente a guion simple). Las 7 pruebas nuevas de autenticación, 2 de persistencia de contexto y el widget de login aprobaron. flutter analyze --no-fatal-infos finaliza sin errores ni advertencias; mantiene 33 observaciones informativas existentes. git diff --check correcto.
**Validación manual**: El usuario confirmó el funcionamiento del inicio de sesión y cambio de ambientes el 2026-11-11.

### Notificaciones de pagos y vencimiento de prórroga
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-11
**Fecha Fin**: 2026-11-11 09:24:22
**Última Actualización**: 2026-11-11 09:24:22
**Progreso**: 100%
**Comentario**: El usuario eligió avisos al propietario y botón de WhatsApp con mensaje listo para el inquilino. Implementados permiso al iniciar sesión, interruptor en Acciones, días de prórroga por contrato (0–365), teléfono con código de país y botón Recordar por WhatsApp en detalle de pagos pendientes/vencidos. El usuario confirma el envío en WhatsApp; no se enviaron mensajes durante las pruebas.
**Reglas de avisos**: Android/iOS, alrededor de las 9:00 a. m. del teléfono; día de vencimiento del pago y día siguiente al último día de prórroga. Contratos existentes usan 0 días hasta editarlos. Solo deudas pendientes/vencidas de contratos activos; pagos pagados o eliminados y contratos finalizados/cancelados quedan excluidos. Los avisos se reprograman al cambiar datos, sincronizar o reanudar la app. Cierre de sesión/cambio de ambiente cancela los avisos anteriores. Agrupación diaria por tipo, máximo 60 avisos futuros para respetar iOS; recuperación de atrasos al abrir, máximo una vez por día y tipo mediante historial local.
**Datos y sincronización**: Migración SQLite v6 → v7 probada preservando registros existentes. Campos diasProrroga y telefono añadidos y verificados en ambos proyectos Supabase mediante migración aditiva 20261111131511_payment_reminder_fields.sql. No se modificaron políticas ni funciones remotas. Dependencias nuevas fijadas y pubspec.lock incluido para reproducibilidad.
**Verificación**: Android debug APK y iOS debug para simulador compilan. Las 15 pruebas nuevas de fechas (cambios de mes/año y bisiestos), mensajes WhatsApp, migración SQLite, agrupación, permisos, persistencia y cancelación aprobaron. Suite completa: 100 aprobadas y los mismos 2 fallos previos en alquiler_entity_test y comprobante_pago_service_test. flutter analyze --no-pub --no-fatal-infos sin errores ni advertencias; 38 observaciones informativas. git diff --check correcto.
**Validación manual**: Pendiente comprobar entrega real en el teléfono con permisos habilitados y apertura del borrador en WhatsApp. Es necesario reiniciar/recompilar la app por las nuevas dependencias nativas. La programación del sistema se implementó para Android/iOS; el botón WhatsApp funciona también en web.
**Límites documentados**: Los avisos usan la fecha guardada del pago; editar el día del contrato no recalcula pagos anteriores (limitación existente). Al abrir la app se renuevan las próximas 60 agrupaciones. Se encontró además que el esquema previo de alquileres en Alquilados_Test carece de varios campos de negocio existentes en producción (por ejemplo estado, montoPago y diaPago), lo que requiere estabilizar su sincronización por separado; los avisos locales no necesitan conexión.
**Revisión Supabase**: Los advisors señalan funciones existentes SECURITY DEFINER expuestas, search_path mutable en handle_new_user y protección de contraseñas filtradas desactivada. No son cambios de esta migración. Referencias: [funciones expuestas](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [search_path](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable), [contraseñas](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

### Procesos Individuales
Cada proceso debe registrar su estatus en el siguiente formato:

```markdown
## [Tipo de Recurso] - [ID]
**Estatus**: `PENDING` / `IN_PROGRESS` / `COMPLETED` / `FAILED` / `CANCELLED`
**Fecha Inicio**: YYYY-MM-DD HH:MM:SS
**Fecha Fin**: YYYY-MM-DD HH:MM:SS (opcional)
**Ultima Actualización**: YYYY-MM-DD HH:MM:SS
**Comentario**: Descripción opcional del estado actual
**Progreso**: % (0-100) - solo para procesos largos
**Punto Detención**: Ubicación exacta donde se detuvo (línea, operación, API endpoint)
**Token Última Operación**: Hash del token usado (para debugging)
```

## Registro de Procesos por Recurso

### Propiedades (Propiedades)
- [ ] Crear nueva propiedad - `PENDING`
- [ ] Editar propiedad - `PENDING`
- [ ] Eliminar propiedad - `PENDING`
- [ ] Cargar lista de propiedades - `PENDING`
- [ ] Sincronizar propiedades con Supabase - `PENDING`

### Inquilinos (Inquilinos)
- [ ] Crear nuevo inquilino - `PENDING`
- [ ] Editar inquilino - `PENDING`
- [ ] Eliminar inquilino - `PENDING`
- [ ] Cargar lista de inquilinos - `PENDING`
- [ ] Sincronizar inquilinos con Supabase - `PENDING`

### Alquileres (Alquileres)
- [ ] Crear nuevo alquiler - `PENDING`
- [ ] Editar alquiler - `PENDING`
- [ ] Eliminar alquiler - `PENDING`
- [ ] Cargar lista de alquileres - `PENDING`
- [ ] Generar pagos automáticos - `PENDING`
- [ ] Sincronizar alquileres con Supabase - `PENDING`

### Pagos (Pagos)
- [ ] Crear nuevo pago - `PENDING`
- [ ] Actualizar status pago - `PENDING`
- [ ] Generar comprobante PDF - `PENDING`
- [ ] Filtrar pagos - `PENDING`
- [ ] Sincronizar pagos con Supabase - `PENDING`

### Configuración (Configuración)
- [ ] Configurar URL Supabase - `PENDING`
- [ ] Actualizar logo de la empresa - `PENDING`
- [ ] Cambiar tema (claro/oscuro) - `PENDING`
- [ ] Gestionar permisos de empresa - `PENDING`

## Indicador de Punto de Detención

Cuando un proceso se detiene inesperadamente (pérdida de conexión, expiración de token, error de red), el sistema debe registrar:

### Formato de Punto de Detención
```
PUNTO_DETENCION: {
  "recurso": "tipo_recurso",        // ej: "alquiler", "propiedad", "pago"
  "id_registro": "identificador",   // ej: "123", "new"
  "operacion": "nombre_operacion",  // ej: "guardar", "actualizar", "sincronizar"
  "endpoint_ultima_peticion": "URL", // ej: "https://supabase.co/rest/v1/alquileres"
  "parametros": {                   // ej: {"id": "123", "nombre": "propiedad1"}
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "token_vigente": "hash_token",    // hash del token usado
  "estado_salida": "PENDING/FAILED/COMPLETED"
}
```

### Recuperación después de Pérdida de Conexión
1. Al iniciar la aplicación, verificar si hay procesos con `PUNTO_DETENCION` registrado
2. Mostrar al usuario un indicador visual de "Procesos pendientes de reanudar"
3. Permitir al usuario elegir reanudar desde el punto de detención
4. Verificar validez del token actual antes de reanudar
5. Reintentar operación desde el punto registrado

## Flujo de Trabajo Recomendado

### Antes de Cada Operación
1. Verificar conectividad de red
2. Verificar validez del token de acceso
3. Registrar estatus `IN_PROGRESS` con `PUNTO_DETENCION` vacío o en blanco
4. Ejecutar operación
5. Si exitosa: actualizar estatus a `COMPLETED`, limpiar `PUNTO_DETENCION`
6. Si fallida: actualizar estatus a `FAILED`, registrar `PUNTO_DETENCION` con detalles

### Después de Reinicio de Aplicación
1. Cargar todos los estatus guardados localmente
2. Identificar procesos con `PUNTO_DETENCION` definido
3. Mostrar resumen al usuario
4. Ofrecer opciones:
   - Reanudar procesos detenidos
   - Descartar y empezar nuevo
   - Revisar logs detallados

## Ejemplo de Registro

```markdown
## Alquiler #45 - Sincronización con Supabase
**Estatus**: `FAILED`
**Fecha Inicio**: 2026-10-23 14:30:00
**Ultima Actualización**: 2026-10-23 14:32:45
**Comentario**: Fallo de red después de 2 minutos
**Progreso**: 75%
**Punto Detención**: {
  "recurso": "alquiler",
  "id_registro": "45",
  "operacion": "sincronizar",
  "endpoint_ultima_peticion": "https://supabase-project.supabase.co/rest/v1/alquileres? id=eq.45",
  "parametros": {"id": "45"},
  "timestamp": "2026-10-23T14:32:45Z",
  "token_vigente": "a1b2c3d4e5f6...",
  "estado_salida": "FAILED"
}
```

## Herramientas de Soporte

### Scripts de Recuperación
- `scripts/recovery/analyze_stalled_processes.dart` - Analiza procesos detenidos
- `scripts/recovery/resume_processes.dart` - Reanuda procesos desde puntos de detención
- `scripts/recovery/cleanup_completed.dart` - Limpia estatus completados

### Interfaz de Usuario
- Indicador visual en la pantalla principal del estado de sincronización
- Lista desplegable de "Procesos pendientes de reanudar"
- Botón "Reintentar fallidos" en cada sección relevante
- Configuración para "Reanudar automáticamente al iniciar"