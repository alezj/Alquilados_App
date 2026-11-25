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

### Diagnóstico del error de sincronización
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 14:31:57
**Fecha Fin**: 2026-11-25 14:35:14
**Comentario**: La versión instalada en el iPhone pudo leer los recursos de Producción. Una copia temporal de SQLite en modo de solo lectura confirmó dos inquilinos pendientes y un alquiler pendiente. El inquilino local 1 tiene el mismo ID que un registro remoto vinculado al inquilino local 3, por lo que el flujo omite el envío del inquilino local 1 y del alquiler que depende de él. El inquilino local 2 ya está vinculado a su registro remoto y el flujo conserva su edición pendiente. La revisión se limitó al diagnóstico.
**Verificación en pantalla**: La captura de Acciones confirma «se conservó el cambio local» para los dos inquilinos y «no se envió: faltan registros relacionados» para el alquiler. El contador incluye los tres registros evaluados y ninguno de esos tres se envió en ese intento.

### Consulta sobre exclusión de pendientes desde el móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 14:37:19
**Fecha Fin**: 2026-11-25 14:37:32
**Comentario**: La revisión local confirmó que Acciones no ofrece exclusión por registro ni reversión de ediciones pendientes. Eliminar un alquiler borra también sus pagos locales y eliminar un inquilino borra la ficha local. La sincronización manual de Producción intenta enviar los pendientes. La consulta no requirió otra sesión remota.

### Descarte de cambios locales de Producción
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 14:39:28
**Fecha Fin**: 2026-11-25 14:46:03
**Comentario**: Se descartaron el inquilino y el alquiler locales 1, y se restauró el inquilino 2 con los datos de la web. El pago local 1 se conservó como independiente. El respaldo previo conserva sus vínculos originales. Supabase se consultó en modo de solo lectura.
**Verificación**: La copia recibida desde el iPhone coincide con la instalada. SQLite devolvió integridad correcta y cero pendientes en inquilinos, alquileres y pagos. Se reabrió la app en el iPhone.

### Recuperación de la base local de Pruebas
**Estatus**: `FAILED`
**Última Actualización**: 2026-11-25 14:46:03
**Comentario**: Una transferencia de Xcode usó la carpeta Documentos como destino de un archivo y la reemplazó, incluida la base SQLite de Pruebas. Se restauró la carpeta con la base verificada de Producción. El feed remoto de Pruebas conserva cambios de propiedades, inquilinos, alquileres y pagos. No se recuperó la copia local exacta.
**Punto Detención**: La búsqueda en rutas accesibles no encontró la base local de Pruebas. macOS denegó el listado de respaldos del iPhone bajo MobileSync. Un respaldo previo del dispositivo permitiría verificar si la base puede recuperarse.

### Consulta de descarga del contrato 3
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 14:49:36
**Fecha Fin**: 2026-11-25 14:49:45
**Comentario**: La lectura autenticada de Supabase confirmó que el contrato 3 de Producción tiene origen web y queda fuera del filtro de alquileres del móvil, que exige origen móvil y usuario legado. La descarga automática de Producción solo consulta inquilinos. La versión instalada carece de una acción para descargar el contrato 3.

### Retiro de accesos administrativos en Acciones
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:52:52
**Fecha Fin**: 2026-11-25 15:54:23
**Comentario**: Se retiraron Solicitudes de acceso y Roles y permisos del menú Gestión de Acciones. La administración se realiza desde el CRM.
**Verificación**: Pruebas de interfaz confirmaron la ausencia de ambos accesos y la presencia de Propiedades e Inquilinos. Compilación firmada instalada y abierta en el iPhone.

### Vinculación del pago 1 al contrato 2
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:48:38
**Fecha Fin**: 2026-11-25 15:51:09
**Comentario**: Se respaldó SQLite y se verificó que únicamente cambiaron los dos campos locales que vinculan el pago 1 con el contrato 2. El inquilino del pago y del contrato es el mismo.
**Verificación**: Tras la sincronización manual, Supabase registró el pago 1 con el contrato 2 y el inquilino 2. La base del iPhone lo marcó sincronizado y devolvió cero pagos pendientes.

### Diagnóstico de la nueva incidencia de sincronización
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:45:08
**Fecha Fin**: 2026-11-25 15:46:58
**Comentario**: Producción y la copia temporal del iPhone confirmaron que los pagos 4 y 5 se sincronizaron correctamente. El único pendiente es el pago 1. Su inquilino local 2 está vinculado a Producción, pero el pago hace referencia al alquiler 1, ausente del iPhone y de la empresa en Supabase. El contrato 2 corresponde al mismo inquilino. El envío se detiene al resolver esa dependencia. No se modificaron registros locales ni remotos.
**Verificación en pantalla**: Acciones muestra que falta el alquiler 1 y que por esa dependencia no se envió el pago 1. La misma pantalla confirma que los contratos web están al día. Falta indicar si el pago 1 corresponde al contrato 2 o se manejará como independiente.

### Propiedad en el recibo PDF
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:28:16
**Fecha Fin**: 2026-11-25 15:30:34
**Comentario**: El recibo usa el nombre asociado por el contrato del pago, incluido el nombre de la propiedad descargada desde la web. La verificación local encontró tres pagos con propiedad y que el pago 5 sigue sin contrato. No se cambiaron datos de pagos.
**Verificación**: Siete pruebas de recibo y SQLite aprobadas. PDF de muestra verificó nombre de propiedad, forma y banco. Compilación instalada y abierta en el iPhone.

### Forma de pago en el recibo PDF
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:24:18
**Fecha Fin**: 2026-11-25 15:26:31
**Comentario**: El recibo usa la forma de pago y el banco registrados. Para pagos anteriores sin forma se muestra «Forma de pago sin indicar». Se eliminó la referencia ficticia. El cambio usa datos locales y no requiere token de Supabase.
**Verificación**: Tres pruebas de recibo aprobadas y PDF de ejemplo renderizado y revisado. Suite con 127 pruebas aprobadas y el fallo previo de monto del alquiler. Análisis estático del cambio sin hallazgos. Compilación firmada instalada y abierta en el iPhone.

### Inquilino, forma de pago y banco en Pagos
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 15:11:14
**Fecha Fin**: 2026-11-25 15:21:12
**Comentario**: Formulario único para alta y edición con inquilino, forma de pago y banco condicionado. Catálogos activos por empresa guardados en SQLite v11. Se aplicó en Alquilados_Test la migración 20261125191755 del RPC y se verificó por transacción revertida. Producción usa los permisos y columnas existentes.
**Verificación**: Análisis estático sin errores ni advertencias. Suite con 125 pruebas aprobadas y los dos fallos históricos de alquiler y comprobante PDF. Instalación en iPhone correcta. SQLite v11 conserva cuatro pagos de Producción. El iPhone descargó y guardó las cinco formas de pago y los cinco bancos activos de la empresa al abrir el formulario. No se guardó un pago de prueba en Producción.

### Descarga de contratos web de Producción
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-25 14:51:36
**Fecha Fin**: 2026-11-25 14:59:26
**Comentario**: Producción descarga contratos web por empresa al iniciar sesión, volver a la app o sincronizar manualmente. Las copias se guardan en SQLite con edición y eliminación bloqueadas. La descarga reutiliza los permisos de lectura existentes y conserva los registros locales con IDs en conflicto.
**Verificación**: Consulta de solo lectura con el rol autenticado confirmó acceso al contrato 3 y su propiedad. Flutter analyze sin errores ni advertencias. Suite con 122 pruebas aprobadas y dos fallos previos de alquiler y comprobante PDF. Release instalada y abierta en el iPhone, con SQLite v10 comprobada. Después de iniciar sesión en Producción, una lectura de SQLite del iPhone confirmó que el contrato remoto 3 se descargó con ID local 3 y solo lectura activada.

### Selector de tema en Acciones
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 08:18:01
**Fecha Fin**: 2026-11-23 08:22:59
**Última Actualización**: 2026-11-23 08:22:59
**Progreso**: 100%
**Comentario**: Acciones incluye cuatro colores y los modos Claro, Oscuro y Sistema. La preferencia se guarda localmente y se aplica al iniciar la app.
**Pruebas**: El análisis estático terminó sin errores ni advertencias. Aprobaron 121 pruebas, incluidas las del selector y contraste de Pagos. Continúan dos fallos previos en el importe de alquiler y el formato del comprobante PDF.
**Validación en iOS**: Compilación instalada y proceso de la app activo en el iPhone 15 Pro Max. La interacción y persistencia del selector se verificaron en pruebas automatizadas.

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

### Diagnóstico de pantalla de aprobación en ejecución local
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-13 07:30:05
**Fecha Fin**: 2026-11-13 07:31:00
**Progreso**: 100%
**Comentario**: Pantalla exacta localizada en Angular1/src/app/auth/access-pending.ts, correspondiente al servidor Node activo en localhost:4200, fuera de este repositorio Flutter. authGuard redirige sesiones autenticadas cuando isAuthorized es falso y usa pending como estado por defecto si no obtiene membresía. Requiere perfil activo, aprobación y empresa activa (excepto sysAdmin). environment.development.ts apunta al proyecto Supabase de producción; environment.test.ts al de pruebas. La pantalla también puede aparecer por falta de datos/permisos de consulta, sin que exista una solicitud realmente pendiente. Revisión de solo lectura de la aplicación; no se consultaron ni modificaron cuentas remotas. Conectividad HTTP local no verificable desde esta ejecución; token no aplicable a inspección de código.

### Ejecución local de Angular contra Alquilados_Test
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-13
**Fecha Fin**: 2026-11-13 07:35
**Progreso**: 100%
**Comentario**: Reiniciado Angular1 en localhost:4200 con el comando existente npm run start:test. Verificación HTTP 200 y JavaScript servido con URL jhhujnqmjtdnhkkijafs.supabase.co, sin URL de producción. git status --short de Angular1 vacío antes y después: no se modificaron archivos ni configuración Git. Compilación exitosa con advertencias existentes de tamaños y Leaflet. Para próximos inicios usar npm run start:test; npm start conserva su comportamiento anterior. No se requiere token de usuario para iniciar el servidor; no se realizaron operaciones de datos remotas.

### Diagnóstico de pantalla blanca al abrir en iPhone
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 16:43:20
**Fecha Fin**: 2026-11-19 16:46:55
**Comentario**: El iPhone reprodujo el error SQLite 14 al abrir `Downloads/alquilados_local.db3` antes del primer cuadro. El contenedor carecía de `Downloads`. En iOS las bases nuevas se abren en la ruta de SQLite (`Documents`), y las bases existentes en `Downloads` conservan esa ruta. La comprobación inicial de conectividad desde el entorno aislado no resolvió DNS. El diagnóstico y la verificación fueron locales y no requirieron token de Supabase.
**Verificación**: Versión release instalada sobre la existente en el iPhone físico. Se verificó que apareció el formulario de inicio de sesión tanto al instalar como al cerrar y volver a abrir sin depurador, y que SQLite creó el archivo en `Documents`. Las 3 pruebas de inicio de sesión y base local pasaron. El análisis de Flutter finalizó sin errores ni advertencias.

### Etiquetas de los accesos rápidos en iPhone
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 16:49:13
**Fecha Fin**: 2026-11-19 16:53:42
**Comentario**: La captura inicial mostró las etiquetas partidas. Los accesos rápidos de Alquileres y Pagos colocan ambos títulos debajo de sus íconos cuando el ancho de las tarjetas y la escala tipográfica impiden que quepan al lado. La comprobación de conectividad desde el entorno aislado no resolvió DNS. Token de Supabase no aplicable al ajuste.
**Verificación**: Cuatro pruebas de widget aprobadas en anchos compactos y amplios, con escala normal y ampliada. Análisis de los archivos modificados sin errores ni advertencias. Compilación release instalada y abierta en el iPhone. La captura final mostró la pantalla apagada, por lo que quedó pendiente ver el Dashboard actualizado en el teléfono después de iniciar sesión.

### Revisión de sincronización del CRM web al móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 16:57:15
**Fecha Fin**: 2026-11-19 16:58:00
**Comentario**: Revisión de código local y documentación pública. La prueba de red desde el entorno aislado no resolvió DNS. Token de usuario no aplicable a la revisión local.
**Hallazgos**: Angular1 y el móvil tienen configurados los mismos proyectos Supabase. El CRM escribe en Supabase. La sincronización manual móvil sí descarga registros, pero los endpoints limitan la lectura a `Origen=movil` y al usuario cero. El móvil conserva cambios pendientes por ID local; las bajas físicas en el CRM no se reciben con el flujo actual. Se propone validar la identidad compartida y RLS por empresa, incorporar descarga incremental y bajas, sincronizar al volver al primer plano y usar Realtime para avisos con la app abierta. Revisión sin cambios funcionales ni consultas a datos remotos.

### Piloto de sincronización CRM web → móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 17:00:08
**Fecha Fin**: 2026-11-19 17:13:16
**Comentario**: Alquilados_Test descarga propiedades, inquilinos, alquileres y pagos del feed privado autorizado solo a la cuenta piloto y su empresa. Consulta al iniciar sesión, activar la app, cada 45 s en primer plano o manualmente desde Acciones. SQLite v8 persiste el cursor, las bajas y las asociaciones de IDs, protege ediciones pendientes y conserva las bajas con referencias locales. El piloto es de descarga y no envía cambios móviles. Las políticas existentes del CRM y el servidor de producción no se modificaron.
**Verificación**: Migración `20261119210326_mobile_crm_pilot_feed.sql` instalada únicamente en Alquilados_Test. SQL comprobó en transacción revertida el cobro, la baja, la lectura por la cuenta piloto, el bloqueo de otro usuario y los permisos para anónimos y clientes. Los advisors no señalaron problemas nuevos en el feed. Flutter release instalada en el iPhone. Se creó un pago temporal de prueba y se reprodujo en Supabase la actualización que realiza el CRM. El iPhone descargó Pendiente y luego Pagado automáticamente, y el contador bajó de 2 a 1. Se eliminó el pago temporal y se confirmó su baja en SQLite y el contador final de 1 en el Dashboard. La suite de Flutter obtuvo 105 pruebas aprobadas y los dos fallos históricos de entidad Alquiler y comprobante PDF. Análisis sin errores ni advertencias y código de sincronización sin observaciones.

### Revisión de pago móvil pendiente de envío
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 17:18:40
**Fecha Fin**: 2026-11-19 17:19:08
**Comentario**: El pago más reciente sigue guardado en SQLite de Alquilados_Test con `sync_state=pending`. El CRM de pruebas aún tiene cero pagos. En este ambiente el piloto automático y el botón manual llaman a la descarga del CRM. El envío de pagos móviles constituye la fase inversa y requiere autorización para habilitarla. Se hizo una revisión de solo lectura sin copiar datos a Supabase.

### Evaluación de sincronización bidireccional CRM y móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 17:20:14
**Fecha Fin**: 2026-11-19 17:20:32
**Comentario**: Comparativa de arquitectura basada en el piloto y la documentación pública. La consulta de red desde el entorno aislado no resolvió DNS. No se requiere un token para esta evaluación.
**Conclusión**: Completar la sincronización propia por etapas con Supabase como fuente compartida, SQLite y cola duradera en el móvil, comandos validados por empresa e idempotencia para cobros. Probar primero pagos en Alquilados_Test, incluyendo reintentos, desconexión y ediciones concurrentes. PowerSync es una alternativa si crecen el volumen y la complejidad. La evaluación no cambió la app ni el servidor.

### Pagos en línea compartidos entre CRM y móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-19 17:23:49
**Fecha Fin**: 2026-11-19 17:36:58
**Comentario**: Primera fase de la opción en línea, activada para Pagos en Alquilados_Test. Las altas, ediciones, cambios de estado y bajas del móvil esperan la confirmación de Supabase. El CRM Angular de pruebas consulta pagos directamente y refresca la pantalla cada 30 segundos mientras está visible. SQLite v9 conserva lecturas y la identidad de reintentos manuales inciertos. La operación autenticada y su clave de idempotencia se pueden reutilizar desde una futura cola offline. Los registros anteriores en SQLite no se enviaron automáticamente. Producción conserva su configuración.
**Verificación**: Migraciones `20261119212555_online_payment_operations.sql` y `20261119213009_qualify_online_payment_result.sql` aplicadas en Alquilados_Test. Transacción SQL revertida verificó alta, reintento con un único ID, actualización concurrente rechazada, cobro, edición, baja y rechazo de otra cuenta. Advisors sin hallazgos sobre las funciones nuevas. Compilación Angular de pruebas correcta con advertencias existentes de tamaño y Leaflet. Se comprobó que localhost:4200 sirve el código actualizado y el ambiente de pruebas. Release instalada y abierta en el iPhone con sesión de pruebas restaurada. Suite Flutter: 107 aprobadas y dos fallos históricos de alquiler y comprobante PDF. Pendiente validación manual de un alta desde la pantalla física y visualización simultánea en el navegador. No se creó un pago de prueba persistente.

### Propuesta visual para el Dashboard
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 07:27:58
**Fecha Fin**: 2026-11-23 07:29:40
**Comentario**: Preparadas dos opciones de diseño con datos de ejemplo, Cobros primero y Agenda primero. Se recomienda priorizar el estado de los cobros, el acceso a Registrar pago y los vencimientos próximos. Consulta DNS desde el entorno aislado sin respuesta. La propuesta visual se generó localmente y no requirió token de Supabase. El código de la aplicación no se modificó.

### Dashboard Cobros primero en Flutter
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 07:32:18
**Fecha Fin**: 2026-11-23 07:38:36
**Comentario**: Inicio usa el diseño Cobros primero con importes de SQLite, avance del período programado, Registrar pago, Alquileres, alertas navegables y ocupación. El filtro de vencidos y el de próximos siete días usan los mismos criterios que los contadores. La comprobación DNS del entorno aislado no respondió. El trabajo local no requirió token de Supabase.
**Verificación**: Release instalada en el iPhone físico. Tras iniciar sesión, se comprobó visualmente el resumen con los datos de la cuenta. Pasaron seis pruebas específicas, incluida pantalla estrecha con texto ampliado, filtros y apertura de Registrar pago. La suite completa registró 109 aprobadas y los mismos dos fallos históricos de alquiler y comprobante PDF. Análisis sin errores ni advertencias.

### Consulta de descarga de inquilinos al móvil
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 07:41:26
**Fecha Fin**: 2026-11-23 07:41:35
**Comentario**: Acceso de lectura a Alquilados_Test verificado con el conector. Un inquilino existente figura en el feed de la cuenta piloto. Confirmado el acceso desde Acciones, la sincronización periódica y el filtro legado de Producción. No se cambiaron datos o configuración.

### Descarga de inquilinos de Producción
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 07:44:12
**Fecha Fin**: 2026-11-23 07:53:37
**Comentario**: RLS y permisos de lectura por empresa ya existían en Producción. No se aplicaron cambios de esquema, políticas ni datos remotos. El móvil consulta inquilinos con la sesión y el identificador de la empresa activa, sin filtrar por origen, al iniciar sesión, volver a la app y cada 45 segundos mientras está visible. La descarga conserva registros y ediciones locales y traduce los identificadores relacionados en la sincronización manual. El flujo incorpora altas y cambios de inquilinos; la ausencia de un registro remoto no se interpreta como baja.
**Verificación**: SQL de solo lectura confirmó dos filas accesibles en la empresa activa, una de origen web, cero con una cuenta externa y ausencia de lectura anónima. Release instalada en iPhone; SQLite confirmó dos inquilinos vinculados de Producción, uno del CRM web. Doce pruebas específicas aprobadas. Suite completa con 110 aprobadas y los dos fallos históricos de alquiler y comprobante PDF. Análisis sin errores ni advertencias y git diff --check correcto.

### Renovación visual de las pantallas de la app
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 07:55:12
**Fecha Fin**: 2026-11-23 08:06:24
**Comentario**: Renovados acceso, listas, detalles, formularios, Acciones, solicitudes, roles y políticas. Los pagos y alquileres agrupan edición y eliminación en un menú. Se corrigió la navegación de las políticas públicas desde el acceso; la lógica de aceptación se conservó. Dashboard y navegación inferior conservaron su diseño. El cambio no requirió token de Supabase.
**Verificación**: Release final instalada en iPhone y acceso verificado visualmente. Pruebas de las cuatro listas en modo oscuro, ancho de 320 y letra ampliada; pruebas de botones en ambos temas, navegación a políticas y Dashboard aprobadas. Suite completa con 117 aprobadas y los dos fallos históricos de alquiler y comprobante PDF. Análisis sin errores ni advertencias y git diff --check correcto.

### Corrección de contraste en Pagos
**Estatus**: `COMPLETED`
**Fecha Inicio**: 2026-11-23 08:10:36
**Fecha Fin**: 2026-11-23 08:14:20
**Comentario**: Se asignaron colores contrastantes a los títulos de barra, encabezados, selector de mes y etiquetas de filtros y estados seleccionados y sin seleccionar. El ajuste es local y no requirió token de Supabase.
**Verificación**: Pasaron las pruebas de contraste de lista, selector de mes y detalle de Pagos en claro y oscuro, con relación mínima de 4.5:1 en los textos evaluados. Suite completa con 119 aprobadas y los dos fallos históricos de alquiler y comprobante PDF. Análisis sin errores ni advertencias. Release instalada y abierta en el iPhone; el dispositivo quedó en inicio de sesión y luego se apagó la pantalla, por lo que quedó pendiente la verificación visual dentro de Pagos en el teléfono.

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
