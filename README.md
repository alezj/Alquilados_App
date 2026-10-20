# Alquilados App

> **Aplicación móvil Flutter para la gestión de alquileres, propiedades, inquilinos y pagos.**  
> Versión actual: `0.3.4+1` · Dart `^3.13.3` · Estrategia: **local-first con SQLite**

---

## ¿Qué es esta app?

Alquilados es una herramienta de administración inmobiliaria pensada para propietarios o gestores de inmuebles que necesitan controlar contratos de alquiler, inquilinos y cobros desde su teléfono, **sin depender de una conexión a internet**. La información vive en el dispositivo (SQLite) y existe una capa de sincronización remota configurable para cuando el backend esté disponible.

---

## Stack técnico

| Capa | Tecnología |
|---|---|
| UI / Framework | Flutter + Material 3 |
| Estado | `flutter_riverpod` |
| Navegación | `go_router` |
| Base de datos local | `sqflite` (nativo) + `sqflite_common_ffi_web` (web) |
| HTTP / Sync | `dio` |
| Backend remoto | Supabase REST API |
| PDF | `pdf` + `printing` |
| Formato / Fechas | `intl` |
| Seguridad local | `flutter_secure_storage` |

---

## Lo que ya está implementado

### 🏠 Dashboard
- Resumen visual con tarjetas de colores para: propiedades totales, ocupadas, disponibles, alquileres activos, pagos pendientes e inquilinos.
- Accesos rápidos a Alquileres y a la creación de pagos.
- Las tarjetas son adaptables al tamaño de pantalla (móvil / tablet).

### 🏘️ Propiedades
- Listado de propiedades con estado local.
- Pantalla de detalle.
- Precio mensual que se carga automáticamente al crear un alquiler.

### 👤 Inquilinos
- Creación con solo nombre obligatorio (correo, fecha de contrato y día de pago son opcionales).
- Edición y eliminación local.
- Pantalla de detalle.
- Al crear o editar un alquiler, el inquilino se actualiza automáticamente con la fecha de inicio del contrato y el día de pago acordado.

### 📋 Alquileres
- Listado con búsqueda (propiedad / inquilino / estado) y filtros por estado.
- Formulario de creación y edición:
  - Al seleccionar fechas de inicio y fin → calcula los meses automáticamente.
  - Al ingresar cantidad de meses → calcula la fecha de fin automáticamente.
  - El día de pago y la fecha de inicio se sincronizan al inquilino al guardar.
- Generación automática de pagos pendientes por cada mes del contrato al crear el alquiler.
- Pantalla de detalle con:
  - Tarjetas de métricas: meses acordados, pagos realizados, pendientes (con color de alerta si hay pendientes).
  - Información completa del contrato.
  - Tabla de pagos vinculados al alquiler.
- Eliminación de contratos.

### 💳 Pagos
- Listado con nombre del inquilino, búsqueda por nombre o ID y filtro por estado.
- Creación: selección de inquilino con carga automática del monto del alquiler activo (`montoPago`, con `importe` como respaldo).
- Edición, cambio de estado y eliminación.
- Generación de comprobante de pago no fiscal en PDF.

### ⚙️ Configuración y sistema
- Pantalla de configuración con URL de la API.
- Tema claro y oscuro (Material 3).
- Logo personalizado (reemplaza el ícono de Flutter en Android e iOS).
- Datos semilla para pruebas locales.
- Pantalla de login como punto de entrada.
- Sincronización remota configurable (pendiente de estabilizar).

---

## Arquitectura

```
lib/
├── core/
│   ├── router/          # GoRouter + rutas nombradas
│   ├── shared/widgets/  # AppCard, AppButton, AppTextField, StatusBadge, etc.
│   ├── theme/           # AppTypography, colores, tema Material 3
│   └── ...
└── features/
    ├── dashboard/       # Panel principal y provider de resumen
    ├── propiedades/     # CRUD de propiedades
    ├── inquilinos/      # CRUD de inquilinos
    ├── alquileres/      # Contratos: listado, formulario, detalle
    ├── pagos/           # Pagos: listado, formulario, comprobante PDF
    ├── sync/            # LocalDatabaseService + SyncRepository
    ├── configuracion/   # Ajustes de la app
    └── login/           # Pantalla de autenticación
```

### Base de datos local (`alquilados_local.db3`)

| Tabla | Descripción |
|---|---|
| `propiedades` | Inmuebles disponibles para alquilar |
| `inquilinos` | Personas que alquilan |
| `alquileres` | Contratos que vinculan propiedad + inquilino |
| `pagos` | Registros de cobros por mes de alquiler |
| `estados` | Catálogo de estados sincronizado desde Supabase |
| `sync_log` | Log de operaciones pendientes de sincronizar |

La base se crea y migra automáticamente al iniciar la app. En plataformas nativas el archivo vive en el directorio de `path_provider`; en Web usa almacenamiento web con el mismo nombre lógico.
La versión móvil 6 agrega `Origen`, `usuario` y `created_at` a las tablas de
negocio, e incorpora `estados`. Se conservan las columnas internas de
sincronización y los nombres snake_case usados por la app para mantener los
datos existentes.

---

## Rutas

```
/login
/dashboard
/propiedades        /propiedades/:id
/inquilinos         /inquilinos/:id
/alquileres         /alquileres/:id
/pagos              /pagos/:id
/configuracion
```

---

## Instalación y ejecución

La sincronización usa el proyecto Supabase configurado en `AppConfig`. Para
usar otro entorno, pasa `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` con
`--dart-define` (la clave publishable es apta para cliente; nunca uses una
secret/service role key dentro de la app).

```bash
flutter run \\
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<key>
```

La migración `supabase/migrations/20261020000100_app_sync_fields.sql` añade a
las tablas existentes los campos requeridos por la sincronización local-first.
El proyecto conectado hoy permite acceso anónimo de lectura y escritura en las
tablas de alquileres; el formulario de login de esta app todavía no autentica
usuarios. Antes de guardar datos reales de varios usuarios, configura Supabase
Auth y políticas RLS por propietario.

```bash
flutter pub get
flutter run                  # dispositivo por defecto
flutter run -d chrome        # web
flutter run -d <device-id>   # dispositivo específico
```

Revisar entorno:

```bash
flutter doctor
flutter devices
flutter analyze
flutter test
```

---

## Puntos a mejorar 🛠️

### Alta prioridad
- [ ] **Autenticación real** — la pantalla de login existe pero no tiene sesión real; se necesita JWT o token persistido con `flutter_secure_storage`.
- [ ] **Sincronización bidireccional** — el `SyncRepository` existe pero el flujo de conflictos no está resuelto; faltan estrategias de merge cuando el mismo registro se edita local y remotamente.
- [ ] **Manejo de errores de red** — los errores CORS y de conectividad no tienen un flujo de reintento amigable para el usuario.

### Módulo de alquileres
- [ ] **Editar pagos generados** — al editar un alquiler (cambiar meses, fecha o monto), los pagos pendientes ya generados no se recalculan; habría que destruirlos y regenerarlos o permitir ajustes individuales.
- [ ] **Alerta de contrato por vencer** — notificación o badge cuando la fecha de fin está próxima (< 30 días).
- [ ] **Renovación de contrato** — flujo para extender un alquiler finalizado sin perder el historial.

### Módulo de pagos
- [ ] **Marcar pago desde el detalle del alquiler** — actualmente hay que ir a la pestaña de Pagos; sería mejor poder cambiar el estado directamente desde la tabla de pagos en el detalle.
- [ ] **Filtro por propiedad o alquiler** — el listado de pagos solo filtra por inquilino/estado; falta filtrar por propiedad.
- [ ] **Recibo mejorado en PDF** — el comprobante es básico; se podría enriquecer con logo, datos del propietario y desglose del período.

### UX / Diseño
- [ ] **Modo tablet / escritorio** — la grilla del dashboard ya detecta el tamaño pero el resto de pantallas no tiene layout adaptado para pantallas anchas.
- [ ] **Onboarding inicial** — cuando la base de datos está vacía, guiar al usuario para crear su primera propiedad e inquilino.
- [ ] **Validaciones en tiempo real** — los campos del formulario de alquiler solo validan al guardar; sería mejor mostrar errores inline mientras el usuario escribe.
- [ ] **Accesibilidad** — revisar etiquetas semánticas y contraste de colores en modo oscuro.

### Técnico / Deuda
- [ ] **Tests unitarios e integración** — la cobertura actual es mínima; se necesitan tests para `LocalDatabaseService`, providers de Riverpod y cálculos de meses/fechas.
- [ ] **Backend/API definitivo** — los contratos REST están definidos parcialmente; se necesita un backend estable con el que cerrar el ciclo de sincronización.
- [ ] **Facturación fiscal** — el comprobante de pago actual es **no fiscal**; para uso comercial real se requiere integración con NCF (República Dominicana) u otro sistema tributario.
- [ ] **CI/CD** — no hay pipeline de integración continua; configurar GitHub Actions para análisis estático y pruebas automáticas en cada PR.
- [ ] **Distribución** — no existe configuración de firma para Play Store ni App Store.

---

## Principios del proyecto

1. **Local-first** — la app funciona sin conexión; el backend es una mejora, no un requisito.
2. **Compatibilidad incremental** — cada cambio debe preservar los datos existentes en la BD local.
3. **Un paso a la vez** — avanzar feature por feature sin romper lo que ya funciona.
4. **Reutilizar antes de crear** — aprovechar los widgets compartidos de `core/shared/` y la lógica existente en `LocalDatabaseService`.
