import 'package:flutter/material.dart';

/// Modelo de documento de política para el módulo de políticas.
///
/// Comparación con Angular: Equivale a un `PolicyDocument` DTO con
/// propiedades como `id`, `titulo`, `cuerpo`, `icono` y `url`.
class PolicyDocument {
  const PolicyDocument({
    required this.id,
    required this.titulo,
    required this.cuerpo,
    this.icono = Icons.description_outlined,
    this.url,
  });

  final String id;
  final String titulo;
  final String cuerpo;
  final IconData icono;
  final String? url;

  factory PolicyDocument.fromJson(Map<String, dynamic> json) {
    return PolicyDocument(
      id: json['id'] as String,
      titulo: json['titulo'] as String,
      cuerpo: json['cuerpo'] as String,
      icono: Icons.description_outlined,
      url: json['url'] as String?,
    );
  }
}

/// Catalogo de políticas disponibles en la app.
class PolicyCatalog {
  const PolicyCatalog({required this.documents});

  final List<PolicyDocument> documents;

  static const PolicyCatalog catalog = PolicyCatalog(
    documents: [
      PolicyDocument(
        id: 'privacy',
        titulo: 'Política de Privacidad',
        cuerpo: _privacityBody,
        icono: Icons.privacy_tip_outlined,
      ),
      PolicyDocument(
        id: 'terms',
        titulo: 'Términos y Condiciones de Uso',
        cuerpo: _termsBody,
        icono: Icons.gavel_outlined,
      ),
      PolicyDocument(
        id: 'data',
        titulo: 'Política de Tratamiento de Datos',
        cuerpo: _dataBody,
        icono: Icons.data_object_outlined,
      ),
    ],
  );

  static PolicyDocument findById(String id) {
    return catalog.documents.firstWhere(
      (d) => d.id == id,
      orElse: () => catalog.documents.first,
    );
  }
}

// --- Contenido de las políticas ---

const String _privacityBody = '''
# Política de Privacidad

**Alquilados App** se compromete a proteger su privacidad y a salvaguardar
su información personal. Esta política describe cómo recopilamos, usamos,
beneficiamos, almacenamos y protegemos los datos que usted nos facilita.

## 1. ¿Qué datos recopilamos?

Cuando se registra en la aplicación, le solicitaremos los siguientes datos:

- **Nombre completo**: Identificador visual del usuario.
- **Correo electrónico**: Para autenticación y comunicación.
- **Contraseña**: Para proteger su cuenta.
- **Empresa**: Identificador de la organización a la que pertenece.

Además, al utilizar la aplicación, se recopilarán datos relacionados con:

- **Propiedades**: Dirección, precio mensual, estado.
- **Inquilinos**: Nombre, correo, fecha de contrato, día de pago.
- **Alquileres**: Fechas de inicio y fin, montos contractuales.
- **Pagos**: Montos cobrados, estado de cada pago.

## 2. ¿Para qué usamos sus datos?

- **Autenticación**: Acceso seguro a su cuenta.
- **Gestión de alquileres**: Administración de contratos y cobros.
- **Reportes**: Generación de estadísticas y métricas.
- **Comunicación**: Notificaciones sobre solicitudes de acceso y cambios.

## 3. ¿Dónde almacenamos sus datos?

- **Localmente**: La base de datos SQLite se guarda en el dispositivo.
  Esto garantiza que la funcionalidad completa funcione sin internet.
- **Remotamente (opcional)**: Si configura la sincronización con
  Supabase, los datos se sincronizan en un servidor seguro.

## 4. ¿Quién tiene acceso a sus datos?

- **Usted mismo**: Tiene control total sobre su cuenta.
- **Administradores de la empresa**: Accedidos solo a los datos
  relevantes de su organización.
- **Nuestro equipo técnico**: Acceso limitado para mantenimiento y soporte.

## 5. ¿Durante cuánto tiempo conservamos sus datos?

- Los datos de cuenta se conservan mientras la cuenta esté activa.
- Los registros de alquileres y pagos se conservan por la duración
  del contrato y, en caso de no renovación, durante un período
  máximo de 3 años.
- Los datos se eliminan cuando el usuario solicita la baja de su cuenta.

## 6. ¿Cómo protegemos sus datos?

- **Almacenamiento seguro**: Contraseñas se hashean con bcrypt.
- **Cifrado local**: La base de datos SQLite utiliza cifrado nativo.
- **Sincronización segura**: Los datos remotos se transfieren
  mediante HTTPS.
- **Control de accesos**: Solo los administradores autorizados pueden
  visualizar los datos de la empresa.

## 7. ¿Qué opciones tiene usted?

- **Eliminar su cuenta**: Pode solicitar la eliminación permanente de
  su cuenta y todos los datos asociados.
- **No sincronizar**: Puede desactivar la sincronización remota
  desde la configuración de la aplicación.
- **Exportar datos**: Puede solicitar una copia de sus datos
  dentro de la configuración de la cuenta.

## 8. ¿Cambios en esta política?

Publicaremos cualquier actualización a esta política en esta misma
página. Le notificaremos cuando haga cambios significativos.

## 9. Contacto

Si tiene preguntas sobre esta política, puede contactarnos a través
del formulario de soporte en la sección de configuración.
''';

const String _termsBody = '''
# Términos y Condiciones de Uso

**Alquilados App** («el Servicio») es una herramienta de gestión
inmobiliaria diseñada para propietarios y gestores de inmuebles.
A continuación, se establecen los términos y condiciones para el
uso del Servicio.

## 1. Registro y cuenta

1.1. Para usar el Servicio, usted debe crear una cuenta proporcionando
los datos solicitados en el formulario de registro.

1.2. Usted es responsable de mantener su contraseña confidencial y
de notificar inmediatamente al Servicio si detecta actividad no autorizada.

1.3. El Servicio se reserva el derecho de rechazar el registro de
cualquier persona que no reúna los requisitos de acceso.

## 2. Propósito del Servicio

2.1. El Servicio permite gestionar contratos de alquiler, inquilinos,
pagos y propiedades de forma local y, opcionalmente, sincronizada
con un backend remoto.

2.2. Usted es el único responsable de verificar que los datos
proporcionados sean correctos y oportunos.

## 3. Datos financieros

3.1. Los montos de alquiler, pagos y cobros son datos financieros
sensibles. El Servicio no real ninguna transacción financiera
nominalmente; sin embargo, los datos financieros se almacenan
localmente y, opcionalmente, en un servidor remoto.

3.2. El Servicio no factura ni emite comprobantes fiscales.
Para fines fiscales, debe consultar con su contador o sistema
fiscal.

## 4. Derechos de propiedad intelectual

4.1. Todos los contenidos del Servicio, incluyendo diseños,
iconografía, código fuente y documentación, son propiedad del
editor del Servicio.

4.2. Usted reconoce que no puede modificar, copiar, distribuir,
enviar por correo, publicar, transmitir o lucrar de ninguna
manera los contenidos del Servicio sin el consentimiento previo
especial escrito.

## 5. Limitación de responsabilidad

5.1. El Servicio se proporciona «tal como está» sin garantías
expresas ni tácitas.

5.2. El editor del Servicio no será responsable por daños directos
nor indirectos, incluyendo pérdida de datos, derivados de:
- Uso incorrecto del Servicio.
- Fallos en la conexión a internet.
- Errores en la base de datos local.

5.3. El Servicio se diseña para funcionar sin conexión. Cualquier
dependencia de internet para funcionalidades específicas es
indicada en la documentación.

## 6. Cambios en los términos

6.1. El editor del Servicio se reserva el derecho de modificar
estos términos en cualquier momento. Las modificaciones serán
publicadas en esta página.

6.2. Usted acepta revisar regularmente estos términos para estar
al tanto de los cambios.

## 7. Cumplimiento legal

7.1. Usted reconoce y acepta que el uso del Servicio se regirá
por las leyes de la República Dominicana.

7.2. En caso de disputa, ambas partes se someterán a la jurisdicción
de los tribunales competentes.

## 8. Contacto

Para cualquier consulta relacionada con estos términos, puede
contactarnos a través del formulario de soporte en la sección
de configuración.
''';

const String _dataBody = '''
# Política de Tratamiento de Datos

Esta política describe el tratamiento de datos personales
que se recopilan y procesan a través del Servicio "Alquilados App".

## 1. Finalidades del tratamiento

Los datos personales recopilados se utilizan para las siguientes
finalidades legítimas:

- Gestión de cuentas de usuarios y autenticación.
- Administración de propiedades, inquilinos y alquileres.
- Registro y seguimiento de pagos.
- Comunicación con usuarios sobre solicitudes de acceso y
  cambios en el servicio.
- Operación y mantenimiento del Servicio.

## 2. Fuentes de los datos

- **Datos proporcionados por el usuario**: Nombre, correo,
  contraseña, empresa.
- **Datos generados por la actividad del usuario**: Propiedades,
  inquilinos, alquileres, pagos.
- **Datos de sincronización remota** (opcional): Cuando el usuario
  configura la sincronización con Supabase.

## 3. Comunicación de datos

- **Internamente**: Los datos se manejan en dispositivos locales
  y, opcionalmente, en servidores gestionados por el editor.
- **No se cederán datos a terceros** sin el consentimiento expreso
  del usuario, excepto para fines de soporte técnico.

## 4. Seguridad de los datos

Se aplican las siguientes medidas de seguridad:

- Almacenamiento local cifrado con SQLite.
- Almacenamiento remoto con cifrado HTTPS.
- Control de accesos por roles de la empresa.
- Protección de contraseñas con hashing.

## 5. Transferencia internacional

Si los datos se sincronizan con un servidor en el extranjero
(Supabase), se transfieren datos personales fuera de la jurisdicción
donde el usuario reside. Usted consiente este tratamiento
según lo dispuesto en la legislación vigente.

## 6. Derechos del interesado

Tiene derecho a:

- **Acceso**: Obtener confirmación sobre si se tratan sus datos.
- **Rectificación**: Corregir datos incorrectos.
- **Eliminación**: Solicitar la eliminación de sus datos.
- **Oposición**: Oposicarse al tratamiento de sus datos.
- **Limitación**: Solicitar limitación en el tratamiento.
- **Portabilidad**: Obtener y transmitir sus datos en un formato
  estructurado.

Para ejercer estos derechos, puede contactarnos a través
del formulario de soporte en la configuración.

## 7. Periodo de conservación

Los datos se conservan durante el tiempo necesario para
cumplir las finalidades descritas, o durante el plazo legal
applicable, lo que resulte en una menor duración.

## 8. Notificaciones de breaches

En caso de violación de seguridad, notificaremos al usuario
según lo dispuesto por la ley.
''';