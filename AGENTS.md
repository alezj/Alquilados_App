# AGENTS.md

## Application Overview

**Alquilados App** (`alquilados_app`, v0.3.4+1) is a Flutter-based mobile application for property management and rental administration. The app is designed for property owners and managers to track and manage:

- **Properties** (inmuebles) - Available rental units
- **Tenants** (inquilinos) - Individuals renting properties  
- **Rentals** (alquileres) - Active lease contracts
- **Payments** (pagos) - Monthly rent collection
- **Dashboard** - Analytics and quick access to key metrics

### Core Philosophy
- **Local-first architecture**: The app works offline with SQLite as primary storage
- **Configurable sync**: Optional remote synchronization with Supabase when internet is available
- **Progressive enhancement**: Backend is an improvement, not a requirement
- **Data preservation**: Every change maintains existing data integrity

## Technical Architecture

### Framework & Stack
- **UI Framework**: Flutter + Material 3 Design System
- **State Management**: Riverpod (v3.4.3) with ProviderScope
- **Navigation**: GoRouter (v18.0.1) with named routes
- **Local Database**: SQLite (sqflite) + sqflite_common_ffi_web (for web)
- **HTTP Client**: Dio (v5.8.0)
- **Backend**: Supabase REST API (configurable)
- **Security**: flutter_secure_storage (v11.1.1)
- **PDF Generation**: pdf + printing packages
- **Icons**: flutter_launcher_icons with custom app_icon.png

### Directory Structure
```
lib/
├── core/                    # Shared core functionality
│   ├── router/             # GoRouter configuration
│   ├── shared/widgets/     # Reusable UI components
│   ├── theme/              # Material 3 theme system
│   ├── ...
│
└── features/               # Domain-separated modules
    ├── dashboard/          # Main analytics dashboard
    ├── propiedades/        # Property management
    ├── inquilinos/         # Tenant management
    ├── alquileres/         # Rental contract management
    ├── pagos/              # Payment processing
    ├── sync/               # Local/remote synchronization
    ├── configuracion/      # App settings
    └── login/              # Authentication
```

## Key Features

### 🏠 Dashboard
- Visual summary with color-coded cards for:
  - Total properties (available/occupied)
  - Active rentals
  - Pending payments
  - Registered tenants
- Quick access buttons for rentals and payment creation
- Responsive layout for mobile/tablet

### 🏘️ Properties Management
- CRUD operations for rental properties
- Local state management with automatic price loading
- Detail view with comprehensive information

### 👤 Tenants Management
- Simplified tenant creation (name required, other fields optional)
- Automatic synchronization of payment day and contract start date
- Local editing and deletion capabilities

### 📋 Rentals Management
- Advanced search and filtering by property, tenant, and status
- Smart date calculations:
  - Start date + months = end date
  - Months + end date = start date
- Automatic pending payment generation for each contract month
- Detailed view with metrics and payment tables

### 💳 Payments Management
- Payment creation with automatic tenant and amount loading
- PDF generation for non-fiscal receipts
- Status-based filtering and management
- Edit, update status, and delete capabilities

### ⚙️ Configuration & System
- API URL configuration for Supabase
- Light/dark theme support (Material 3)
- Custom logo replacement
- Local seed data for testing
- Login screen (currently basic, needs real auth)
- Configurable remote sync (pending stabilization)

## Data Models & Database Structure

### Local SQLite Database (`alquilados_local.db3`)

| Table | Description |
|-------|-------------|
| `propiedades` | Rental properties available for rent |
| `inquilinos` | Tenant individuals |
| `alquileres` | Active lease contracts (property + tenant) |
| `pagos` | Monthly rent payment records |
| `estados` | Synchronized status catalog from Supabase |
| `sync_log` | Log of operations pending synchronization |

### Key Relationships
- **Properties** → **Tenants** (via alquileres)
- **Properties** → **Rentals** (direct foreign key)
- **Tenants** → **Rentals** (direct foreign key)
- **Rentals** → **Payments** (one-to-many, one payment per month)

## Supabase Configuration

### Environment Variables
```bash
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_<key>
```

### Current Setup
- **Access**: Anonymous read/write access to alquileres table
- **Migration**: `supabase/migrations/20261020000100_app_sync_fields.sql`
- **Purpose**: Adds local-first sync fields to existing tables
- **Security Note**: Need to configure Supabase Auth and RLS policies before production use

### API Usage
- REST API calls via Dio client
- Authentication handled through secure storage (to be implemented)
- Conflict resolution strategy needed for bidirectional sync

## Development Guidelines

### Principles
1. **Local-first**: App must function completely offline
2. **Incremental compatibility**: Preserve existing local data on every change
3. **Single responsibility**: One feature per iteration without breaking existing functionality
4. **Reuse**: Leverage existing widgets and LocalDatabaseService logic

### Code Quality
- Follow Material 3 design guidelines
- Use Riverpod for state management
- Implement proper error handling and user feedback
- Write comprehensive tests (current coverage is minimal)
- Follow Flutter best practices and linting rules

### Testing Strategy
- Unit tests for core business logic
- Widget tests for UI components
- Integration tests for database operations
- Test coverage target: >80% (currently minimal)

## Current Limitations & Areas for Improvement

### High Priority
1. **Real Authentication**: Implement JWT/token-based auth with flutter_secure_storage
2. **Bidirectional Sync**: Resolve conflict resolution for local/remote edits
3. **Network Error Handling**: Implement retry mechanisms and user-friendly error flows

### Rental Module
1. **Payment Recalculation**: Update generated payments when editing rentals
2. **Contract Expiration Alerts**: Notifications for contracts nearing end
3. **Contract Renewal**: Flow for extending existing contracts

### Payment Module
1. **Inline Payment Status**: Update payment status from rental detail view
2. **Property/Alquiler Filtering**: Filter payments by property or rental
3. **Enhanced PDF Receipts**: Include logo, owner data, and detailed breakdowns

### UX & Design
1. **Tablet/Desktop Support**: Adapt layouts for larger screens
2. **Initial Onboarding**: Guide users through first property setup
3. **Real-time Validation**: Inline form validation during data entry
4. **Accessibility**: Review semantic labels and color contrast

### Technical Debt
1. **Comprehensive Testing**: Add tests for LocalDatabaseService, Riverpod providers
2. **Backend Stability**: Define complete REST API contracts
3. **Fiscal Compliance**: Integrate with NCF system for Dominican Republic
4. **CI/CD Pipeline**: Configure GitHub Actions for automated testing
5. **Distribution**: Set up Play Store and App Store distribution

## Environment Setup

### Prerequisites
- Flutter SDK (compatible with Dart ^3.13.3)
- Android Studio / VS Code with Flutter plugin
- Xcode (for iOS development)

### Installation
```bash
flutter pub get
```

### Running the App
```bash
# Default device
flutter run

# Web version
flutter run -d chrome

# Specific device
flutter run -d <device-id>

# With Supabase configuration
flutter run \\
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<key>
```

### Development Commands
```bash
flutter doctor           # Check environment
flutter devices          # List available devices
flutter analyze          # Static analysis
flutter test             # Run tests
```

## Project Configuration

### App Configuration (`app_config.dart`)
- Manages Supabase URL and publishable key
- Handles environment-specific settings
- Supports multiple deployment environments

### Database Migration
- Automatic schema creation and migration
- Version 6 adds: `Origen`, `usuario`, `created_at` to business tables
- Maintains backward compatibility with existing data

### Localization
- Spanish language support (primary)
- Date and number formatting via `intl` package
- Material 3 typography system

## Security Considerations

1. **Never commit** secret keys or service role tokens to version control
2. **Use publishable keys** for client-side Supabase access
3. **Implement proper authentication** before production deployment
4. **Secure local storage** with flutter_secure_storage
5. **Validate all user inputs** before processing

## Future Roadmap

### Phase 1 (Current)
- ✅ Core CRUD operations for all entities
- ✅ Local-first architecture with SQLite
- ✅ Basic UI with Material 3
- ⚠️ Real authentication (in progress)

### Phase 2 (Next)
- 🔄 Bidirectional sync with conflict resolution
- 🔄 Enhanced payment management
- 🔄 Contract renewal system
- 🔄 Advanced reporting

### Phase 3 (Long-term)
- 🔄 Fiscal compliance (NCF integration)
- 🔄 Multi-tenant support
- 🔄 Advanced analytics
- 🔄 Web dashboard

## Support & Maintenance

### Troubleshooting
- **Database issues**: Delete `alquilados_local.db3` to reset local data
- **Sync problems**: Check Supabase URL and publishable key configuration
- **UI issues**: Run `flutter analyze` and check for lint errors
- **Performance**: Monitor database queries and implement proper indexing

### Documentation
- This AGENTS.md file for AI assistance
- README.md for user documentation
- Code comments for technical implementation details
- Architecture decision records for major design choices
- **ESTATUS.md** - Registro de estatus de procesos y solicitudes

---

## Status Tracking & Recovery Protocol

### Purpose
Ensure continuity of work when connections are lost, tokens expire, or interruptions occur. Every process must update its status in ESTATUS.md before, during, and after execution.

### Mandatory Status Updates

#### Before Starting Any Process
1. **Check connectivity** - Verify network availability
2. **Validate token** - Ensure Supabase access token is valid
3. **Record status** - Update ESTATUS.md with `IN_PROGRESS` status
4. **Log checkpoint** - Register `PUNTO_DETENCION` with current operation details

#### During Process Execution
1. **Update progress** - For long-running operations, update progress percentage
2. **Refresh checkpoint** - Update `PUNTO_DETENCION` at each major step
3. **Handle errors** - On failure, set status to `FAILED` with detailed checkpoint

#### After Process Completion
1. **Mark complete** - Set status to `COMPLETED` 
2. **Clear checkpoint** - Remove `PUNTO_DETENCION` for successful operations
3. **Log timestamp** - Record completion time

### Checkpoint Format (PUNTO_DETENCION)
```json
{
  "recurso": "tipo_recurso",           // ej: "alquiler", "propiedad", "pago"
  "id_registro": "identificador",      // ej: "123", "new"
  "operacion": "nombre_operacion",     // ej: "guardar", "actualizar", "sincronizar"
  "endpoint_ultima_peticion": "URL",   // ej: "https://supabase.co/rest/v1/alquileres"
  "parametros": {},                    // parámetros de la operación
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "token_vigente": "hash_token",       // hash del token usado
  "estado_salida": "PENDING/FAILED/COMPLETED"
}
```

### Recovery on App Restart
1. **Load all statuses** from local storage/ESTATUS.md
2. **Identify stalled processes** - Those with `PUNTO_DETENCION` defined
3. **Present to user** - Show "Procesos pendientes de reanudar" summary
4. **Offer options**:
   - Resume from checkpoint
   - Discard and start fresh
   - View detailed logs
5. **Validate token** before resuming any remote operation

### Status Values
| Status | Meaning | Next Action |
|--------|---------|-------------|
| `PENDING` | Waiting to start | Execute when ready |
| `IN_PROGRESS` | Currently running | Wait or cancel |
| `COMPLETED` | Finished successfully | None |
| `FAILED` | Error occurred | Retry or investigate |
| `CANCELLED` | User/system cancelled | Review incomplete work |

### Integration with Development Workflow
- **Every feature implementation** must include status tracking
- **Code reviews** should verify ESTATUS.md updates
- **CI/CD pipeline** should check for unresolved `FAILED` statuses
- **Release notes** should reference completed major processes

---

*Last updated: 2026-10-23*
*Version: 0.1.0*
