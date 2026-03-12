# Reglas de Anti-Duplicacion e Idempotencia para Sumsub

**Fecha:** 2026-02-24
**Autor:** Core Reporting / Backend
**Status:** Documento de diseno para revision
**HU Relacionada:** COR-130 - Spike KYB Integration Architecture

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Reglas de Unicidad](#2-reglas-de-unicidad)
3. [Esquema de Estados](#3-esquema-de-estados)
4. [Configuracion de TTL y Ventanas de Bloqueo](#4-configuracion-de-ttl-y-ventanas-de-bloqueo)
5. [Matriz de Decision: Regenerar vs Reusar](#5-matriz-de-decision-regenerar-vs-reusar)
6. [Implementacion de Idempotencia](#6-implementacion-de-idempotencia)
7. [Manejo de Webhooks](#7-manejo-de-webhooks)
8. [Consideraciones de Edge Cases](#8-consideraciones-de-edge-cases)
9. [Esquema de Base de Datos](#9-esquema-de-base-de-datos)
10. [Pseudocodigo de Implementacion](#10-pseudocodigo-de-implementacion)
11. [Referencias](#11-referencias)

---

## 1. Resumen Ejecutivo

### Objetivo

Definir reglas claras y especificas para:
- Prevenir verificaciones duplicadas por empresa
- Gestionar el ciclo de vida de los links de verificacion
- Garantizar idempotencia en operaciones de API y webhooks
- Establecer ventanas de bloqueo apropiadas para cada estado

### Decisiones Clave

| Aspecto | Decision | Justificacion |
|---------|----------|---------------|
| **Clave de idempotencia** | `externalCompanyId` | Identificador unico y estable por empresa |
| **Verificacion activa** | 1 por empresa | Evita costos duplicados y flujos concurrentes |
| **TTL default de link** | 86400 seg (24 horas) | Balance entre UX y seguridad |
| **TTL maximo de link** | 604800 seg (7 dias) | Limite de seguridad interno |
| **Sesion activa Sumsub** | 30 minutos (fijo) | Configurado por Sumsub, no modificable |
| **Idempotencia webhooks** | `correlationId` | Identificador unico por evento de Sumsub |

---

## 2. Reglas de Unicidad

### 2.1 Regla Principal

```
+------------------------------------------------------------------+
|  REGLA: 1 verificacion activa por externalCompanyId              |
+------------------------------------------------------------------+
```

Esta regla garantiza que:
- No se generen costos duplicados en Sumsub
- No existan flujos de verificacion concurrentes para la misma empresa
- Se mantenga una trazabilidad clara del proceso de verificacion

### 2.2 Definicion de "Verificacion Activa"

Una verificacion se considera **activa** cuando su estado impide iniciar una nueva verificacion:

| Estado | Es Activo? | Permite Nueva? | Razon |
|--------|:----------:|:--------------:|-------|
| `NOT_STARTED` (link valido) | Si | No | Verificacion pendiente de inicio |
| `NOT_STARTED` (link expirado) | No | Si (regenerar) | Link invalido, puede regenerarse |
| `IN_PROGRESS` | Si | No | Usuario en proceso de verificacion |
| `PENDING_REVIEW` | Si | No | En cola de procesamiento Sumsub |
| `IN_REVIEW` | Si | No | En revision manual |
| `ACTION_REQUIRED` | Si | No | Usuario debe corregir documentos |
| `APPROVED` | Finalizado | No | Ya verificado exitosamente |
| `REJECTED` (FINAL) | Finalizado | Segun politica | Rechazo permanente |
| `REJECTED` (RETRY) | Parcial | No | Puede reenviar documentos |
| `EXPIRED` | No | Si | Link/sesion expiro sin completar |
| `CANCELED` | No | Si | Cancelado manualmente |

### 2.3 Identificador de Idempotencia

El `externalCompanyId` actua como clave de idempotencia:

```typescript
// ID empresa en sistema Retorna - usado como externalUserId en Sumsub
const idempotencyKey: string = externalCompanyId;
// Ejemplo: "company-123"
```

**Importante:** Segun la documentacion de Sumsub, el `externalUserId` (que usamos como `externalCompanyId`) soporta hasta 512 caracteres y puede ser generado manualmente o automaticamente por Sumsub.

### 2.4 Constraint de Base de Datos

```sql
-- Constraint unico para prevenir duplicados a nivel de BD
ALTER TABLE kyb_verifications
ADD CONSTRAINT uk_active_verification
UNIQUE (external_company_id)
WHERE status NOT IN ('APPROVED', 'REJECTED', 'EXPIRED', 'CANCELED');
```

---

## 3. Esquema de Estados

### 3.1 Diagrama de Estados

```
                         +---------------+
                         | NOT_STARTED   |<-------------------+
                         | (link valido) |                    |
                         +-------+-------+                    |
                                 |                            |
                    Usuario inicia verificacion               |
                                 |                            |
                                 v                            |
                         +---------------+                    |
                    +--->| IN_PROGRESS   |                    |
                    |    +-------+-------+                    |
                    |            |                            |
                    |  Usuario completa y envia               |
         Link       |            |                            |
         expirado   |            v                            |
                    |    +---------------+                    |
                    |    |PENDING_REVIEW |                    | Regenerar
                    |    +-------+-------+                    | link
                    |            |                            |
                    |            v                            |
                    |    +---------------+                    |
                    |    |  IN_REVIEW    |                    |
                    |    +-------+-------+                    |
                    |            |                            |
                    |   +--------+--------+                   |
                    |   |        |        |                   |
                    |   v        v        v                   |
                    | +-----+ +-----+ +----------------+      |
                    | |GREEN| | RED | | RED            |      |
                    | |     | |FINAL| | RETRY          |      |
                    | +--+--+ +--+--+ +-------+--------+      |
                    |    |       |            |               |
                    |    v       v            v               |
                    | +------+ +------+ +----------------+    |
                    | |APPROV| |REJECT| |ACTION_REQUIRED |----+
                    | |ED    | |ED    | +----------------+
                    | +------+ +------+
                    |
                    |
                    +---+----------+
                        |          |
                        v          |
                  +---------+      |
                  | EXPIRED |------+
                  +---------+
```

### 3.2 Mapping Estados Sumsub a Estados Retorna

Basado en la documentacion oficial de Sumsub:

| Sumsub `reviewStatus` | Sumsub `reviewAnswer` | Sumsub `reviewRejectType` | Estado Retorna |
|----------------------|----------------------|--------------------------|----------------|
| `init` | - | - | `NOT_STARTED` |
| `pending` | - | - | `PENDING_REVIEW` |
| `awaitingService` | - | - | `PENDING_REVIEW` |
| `onHold` | - | - | `IN_REVIEW` |
| `awaitingUser` | - | - | `ACTION_REQUIRED` |
| `completed` | `GREEN` | - | `APPROVED` |
| `completed` | `RED` | `RETRY` | `ACTION_REQUIRED` |
| `completed` | `RED` | `FINAL` | `REJECTED` |

### 3.3 Transiciones Validas

```typescript
const VALID_TRANSITIONS: Record<string, string[]> = {
  'NOT_STARTED':    ['IN_PROGRESS', 'PENDING_REVIEW', 'EXPIRED', 'CANCELED'],
  'IN_PROGRESS':    ['PENDING_REVIEW', 'EXPIRED', 'CANCELED'],
  'PENDING_REVIEW': ['IN_REVIEW', 'APPROVED', 'ACTION_REQUIRED', 'REJECTED'],
  'IN_REVIEW':      ['APPROVED', 'ACTION_REQUIRED', 'REJECTED'],
  'ACTION_REQUIRED':['PENDING_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED'],
  'APPROVED':       ['REJECTED'],  // Caso: fraude detectado post-aprobacion
  'REJECTED':       [],            // Estado terminal
  'EXPIRED':        ['NOT_STARTED'],  // Regeneracion de link
  'CANCELED':       []             // Estado terminal
};
```

---

## 4. Configuracion de TTL y Ventanas de Bloqueo

### 4.1 TTL de Links de Verificacion

Segun la documentacion de Sumsub, la sesion del applicant tiene un timeout de **30 minutos** (fijo, configurado por Sumsub). El TTL del link es configurable via el parametro `ttlInSecs`.

| Escenario | TTL Recomendado | Segundos | Justificacion |
|-----------|-----------------|----------|---------------|
| Email inicial | 24 horas | 86,400 | Usuario puede abrir email al dia siguiente |
| Email reminder | 48 horas | 172,800 | Extension para usuarios ocupados |
| Verificacion urgente | 4 horas | 14,400 | Requiere atencion inmediata |
| Limite maximo interno | 7 dias | 604,800 | Balance seguridad/UX |
| Limite maximo Sumsub | 30 dias | 2,592,000 | Maximo permitido por Sumsub |

### 4.2 Diferencia: TTL del Link vs Sesion Activa

```
+---------------------------------------------------------------------+
|                      TIEMPO DE VIDA DEL LINK                         |
|                        (TTL: hasta 30 dias)                          |
|                                                                      |
|  +----------+   +----------+   +----------+   +----------+          |
|  | Sesion 1 |   | Sesion 2 |   | Sesion 3 |   | Sesion N |   ...    |
|  |  30 min  |   |  30 min  |   |  30 min  |   |  30 min  |          |
|  +----+-----+   +----+-----+   +----+-----+   +----+-----+          |
|       |              |              |              |                 |
|       v              v              v              v                 |
|   Progreso       Progreso       Progreso       Completa              |
|   guardado       guardado       guardado       verificacion          |
|                                                                      |
+---------------------------------------------------------------------+
```

**Nota importante:** Si la sesion expira (30 min de inactividad) despues de completar la verificacion de email, el applicant debera repetir la verificacion de email al regresar.

### 4.3 Ventanas de Bloqueo por Estado

| Estado | Ventana de Bloqueo | Accion Permitida |
|--------|-------------------|------------------|
| `NOT_STARTED` | Hasta que link expire | Esperar o regenerar si expiro |
| `IN_PROGRESS` | Indefinido (hasta timeout sesion) | Esperar completacion |
| `PENDING_REVIEW` | Hasta 24-48h tipicamente | Esperar resultado Sumsub |
| `IN_REVIEW` | Hasta 72h tipicamente | Esperar revision manual |
| `ACTION_REQUIRED` | Hasta que link expire | Usuario corrige o regenerar link |
| `APPROVED` | Permanente | Ninguna (ya verificado) |
| `REJECTED` (FINAL) | Permanente o segun politica | Contactar soporte |
| `REJECTED` (RETRY) | Hasta que corrija | Usuario puede reenviar |

### 4.4 Cooldown para Reintentos

```typescript
const RETRY_POLICIES = {
  // Despues de rechazo FINAL
  afterFinalRejection: {
    enabled: true,            // Permitir reintentos
    cooldownDays: 30,         // Dias minimos de espera
    maxAttempts: 3,           // Maximo de verificaciones por empresa
    requiresApproval: true    // Requiere aprobacion manual
  },

  // Despues de expiracion
  afterExpiration: {
    enabled: true,
    cooldownMinutes: 0,       // Sin cooldown
    maxAttempts: null         // Sin limite
  },

  // Despues de cancelacion
  afterCancellation: {
    enabled: true,
    cooldownMinutes: 5,       // Pequeno cooldown anti-spam
    maxAttempts: null
  }
};
```

---

## 5. Matriz de Decision: Regenerar vs Reusar

### 5.1 Arbol de Decision

```
                  +---------------------------+
                  | Request: Iniciar/Obtener  |
                  | verificacion para empresa |
                  +-------------+-------------+
                                |
                                v
                  +---------------------------+
                  | Buscar verificacion       |
                  | activa existente          |
                  +-------------+-------------+
                                |
              +----------------+------------------+
              |                                   |
              v                                   v
        +----------+                        +-----------+
        | Existe?  |                        | No existe |
        +----+-----+                        +-----+-----+
             |                                    |
             v                                    v
   +-----------------+                   +-----------------+
   | Evaluar estado  |                   | CREAR NUEVA     |
   | y validez link  |                   | VERIFICACION    |
   +--------+--------+                   +-----------------+
            |
   +--------+--------+--------+--------+--------+
   |        |        |        |        |        |
   v        v        v        v        v        v
+------+ +------+ +------+ +------+ +------+ +------+
|APPROV| |REJECT| |ACTIVE| |ACTIVE| |EXPIRE| |CANCEL|
|ED    | |ED    | |link  | |link  | |D     | |ED    |
|      | |      | |valido| |expir | |      | |      |
+--+---+ +--+---+ +--+---+ +--+---+ +--+---+ +--+---+
   |        |        |        |        |        |
   v        v        v        v        v        v
+------+ +------+ +------+ +------+ +------+ +------+
|ERROR:| |ERROR | |REUSAR| |REGEN-| |CREAR | |CREAR |
|Ya    | |o     | |LINK  | |ERAR  | |NUEVA | |NUEVA |
|verif.| |CREAR | |EXIST.| |LINK  | |      | |      |
+------+ +------+ +------+ +------+ +------+ +------+
```

### 5.2 Tabla de Decisiones Detallada

| Estado Actual | Link Valido? | Accion | Resultado |
|---------------|:------------:|--------|-----------|
| No existe | - | **CREAR** | Nueva verificacion + nuevo link |
| `NOT_STARTED` | Si | **REUSAR** | Retornar link existente |
| `NOT_STARTED` | No | **REGENERAR** | Nuevo link, mismo applicant |
| `IN_PROGRESS` | Si | **REUSAR** | Retornar link existente |
| `IN_PROGRESS` | No | **REGENERAR** | Nuevo link, mismo applicant |
| `PENDING_REVIEW` | - | **BLOQUEAR** | Error: en proceso de revision |
| `IN_REVIEW` | - | **BLOQUEAR** | Error: en revision manual |
| `ACTION_REQUIRED` | Si | **REUSAR** | Retornar link existente |
| `ACTION_REQUIRED` | No | **REGENERAR** | Nuevo link para corregir |
| `APPROVED` | - | **BLOQUEAR** | Error: empresa ya verificada |
| `REJECTED` (FINAL) | - | **EVALUAR** | Segun politica de reintentos |
| `REJECTED` (RETRY) | - | **REUSAR/REGEN** | Depende si link sigue valido |
| `EXPIRED` | - | **CREAR/REGEN** | Nueva verificacion o regenerar |
| `CANCELED` | - | **CREAR** | Nueva verificacion |

### 5.3 Cuando Regenerar Link

**Se DEBE regenerar** cuando:
- Link anterior expiro (paso el TTL)
- Estado es `ACTION_REQUIRED` y link expiro
- Estado es `EXPIRED`
- Usuario solicita explicitamente nuevo link (con link actual expirado)

**NO se debe regenerar** cuando:
- Verificacion esta en `PENDING_REVIEW` o `IN_REVIEW`
- Verificacion esta `APPROVED`
- Verificacion esta `REJECTED` con tipo `FINAL`
- Link actual sigue valido y verificacion esta activa

### 5.4 Cuando Reusar Link Existente

**Se DEBE reusar** cuando:
- Estado es `NOT_STARTED`, `IN_PROGRESS`, o `ACTION_REQUIRED`
- Link sigue valido (no ha expirado)
- Es el mismo `externalCompanyId` + `tenantId`

---

## 6. Implementacion de Idempotencia

### 6.1 Idempotencia en Creacion de Verificacion

```typescript
interface CreateVerificationRequest {
  externalCompanyId: string;
  companyInfo: CompanyInfo;
  ttlSeconds?: number;
}

interface CreateVerificationResponse {
  id: string;
  status: VerificationStatus;
  verificationLink: string;
  linkExpiresAt: Date;
  isExisting: boolean;  // true si se reutilizo verificacion existente
}
```

**Comportamiento idempotente:**
- Si existe verificacion activa con link valido -> Retorna la existente
- Si existe verificacion con link expirado -> Regenera link
- Si no existe -> Crea nueva verificacion

### 6.2 Cache de Idempotencia (Redis)

```typescript
// Estructura de key en Redis
const IDEMPOTENCY_KEY_PREFIX = 'kyb:verification:';

interface IdempotencyEntry {
  verificationId: string;
  status: VerificationStatus;
  linkExpiresAt: number;  // Unix timestamp
  createdAt: number;
  requestHash: string;    // Hash del request original
}

// Ejemplo de key
const key = `${IDEMPOTENCY_KEY_PREFIX}${externalCompanyId}`;
// Resultado: "kyb:verification:company-123"
```

### 6.3 Distributed Lock para Operaciones Concurrentes

```typescript
// Patron de lock distribuido para evitar race conditions
const LOCK_KEY_PREFIX = 'kyb:lock:';
const LOCK_TTL_MS = 10000; // 10 segundos

async function acquireLock(companyId: string): Promise<string | null> {
  const lockKey = `${LOCK_KEY_PREFIX}${companyId}`;
  const lockValue = generateUniqueId();

  // SET NX EX - Solo setea si no existe
  const acquired = await redis.set(lockKey, lockValue, 'NX', 'PX', LOCK_TTL_MS);
  return acquired === 'OK' ? lockValue : null;
}

async function releaseLock(companyId: string, lockValue: string): Promise<void> {
  const lockKey = `${LOCK_KEY_PREFIX}${companyId}`;

  // Solo libera si el valor coincide (evita liberar lock de otro proceso)
  const script = `
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  `;
  await redis.eval(script, 1, lockKey, lockValue);
}
```

### 6.4 Request Deduplication

```typescript
// Hash del request para detectar duplicados exactos
function calculateRequestHash(request: CreateVerificationRequest): string {
  const normalized = {
    externalCompanyId: request.externalCompanyId,
    tenantId: request.tenantId,
    companyName: request.companyInfo.legalName,
    country: request.companyInfo.country
  };
  return crypto.createHash('sha256')
    .update(JSON.stringify(normalized))
    .digest('hex');
}
```

---

## 7. Manejo de Webhooks

### 7.1 Estructura de Webhook Sumsub

Segun la documentacion oficial, Sumsub envia webhooks con la siguiente estructura:

```json
{
  "applicantId": "unique-sumsub-id",
  "inspectionId": "inspection-id",
  "correlationId": "req-63f92830-4d68-4eee-98d5-875d53a12258",
  "levelName": "kyb-latam-colombia",
  "externalUserId": "company-123",
  "type": "applicantReviewed",
  "sandboxMode": false,
  "reviewStatus": "completed",
  "reviewResult": {
    "reviewAnswer": "GREEN"
  },
  "createdAtMs": "2026-02-24T10:30:00.000Z",
  "clientId": "retorna-client-id"
}
```

### 7.2 Idempotencia de Webhooks

El campo `correlationId` es el identificador unico de cada evento y debe usarse para deduplicacion:

```typescript
// Tabla para tracking de webhooks procesados
interface ProcessedWebhook {
  correlationId: string;       // PK - ID unico del evento
  applicantId: string;
  eventType: string;
  processedAt: Date;
  resultingStatus: string;
}

async function processWebhook(payload: WebhookPayload): Promise<WebhookResult> {
  // 1. Verificar si ya procesamos este evento
  const existing = await findProcessedWebhook(payload.correlationId);
  if (existing) {
    return { status: 'already_processed', originalResult: existing };
  }

  // 2. Procesar dentro de transaccion
  return await database.transaction(async (tx) => {
    // 2.1 Buscar verificacion por externalUserId
    const verification = await tx.findVerificationByExternalId(
      payload.externalUserId
    );

    if (!verification) {
      // Log warning pero no fallar - puede ser webhook de applicant no gestionado
      logger.warn('Webhook for unknown applicant', { payload });
      return { status: 'ignored', reason: 'applicant_not_found' };
    }

    // 2.2 Mapear a estado interno
    const newStatus = mapSumsubStatusToInternal(payload);

    // 2.3 Validar transicion
    if (!isValidTransition(verification.status, newStatus)) {
      logger.warn('Invalid status transition', {
        current: verification.status,
        new: newStatus,
        correlationId: payload.correlationId
      });
      // Guardar evento para auditoria pero no actualizar estado
    } else {
      // 2.4 Actualizar estado
      verification.status = newStatus;
      verification.updatedAt = new Date();
      if (newStatus === 'APPROVED' || newStatus === 'REJECTED') {
        verification.completedAt = new Date();
      }
      await tx.save(verification);
    }

    // 2.5 Guardar evento procesado (idempotencia)
    await tx.saveProcessedWebhook({
      correlationId: payload.correlationId,
      applicantId: payload.applicantId,
      eventType: payload.type,
      processedAt: new Date(),
      resultingStatus: newStatus
    });

    return { status: 'processed', newStatus };
  });
}
```

### 7.3 Validacion de Firma

Sumsub firma los webhooks con HMAC-SHA256. La validacion es critica para seguridad:

```typescript
function validateWebhookSignature(
  payload: string,
  signature: string,
  secretKey: string
): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secretKey)
    .update(payload)
    .digest('hex');

  // Comparacion segura (timing-safe)
  return crypto.timingSafeEqual(
    Buffer.from(signature, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}
```

### 7.4 Politica de Reintentos de Sumsub

Sumsub reintenta webhooks fallidos con el siguiente esquema:
- Timeout: 5 segundos (si no respondemos, reintenta)
- Reintentos: 4 veces con intervalos de 5 min, 1 hora, 5 horas, 18 horas
- Total: ~24 horas de reintentos

**Recomendacion:** Responder rapidamente (< 5 seg) y encolar procesamiento asincrono.

---

## 8. Consideraciones de Edge Cases

### 8.1 Race Conditions

| Escenario | Problema | Solucion |
|-----------|----------|----------|
| Dos requests simultaneos para misma empresa | Podrian crear verificaciones duplicadas | Distributed lock + constraint BD |
| Webhook llega antes de respuesta API | Estado desincronizado | Webhook actualiza estado independientemente |
| Link regenerado mientras usuario verifica | Usuario pierde progreso | No permitir regenerar en `IN_PROGRESS` |

### 8.2 Fallos de Red

| Escenario | Problema | Solucion |
|-----------|----------|----------|
| Fallo al crear applicant en Sumsub | Verificacion creada localmente sin applicant | Rollback transaccion, retry con backoff |
| Fallo al generar link | Applicant creado pero sin link | Endpoint de regeneracion de link |
| Webhook no llega | Estado desactualizado | Polling como fallback cada 15 min |

### 8.3 Datos Inconsistentes

| Escenario | Problema | Solucion |
|-----------|----------|----------|
| Estado local difiere de Sumsub | Verificacion aparece en estado incorrecto | Reconciliacion diaria automatica |
| Link expira pero estado no actualiza | Usuario no puede continuar | Cron job para detectar links expirados |
| Webhook fuera de orden | Transicion de estado invalida | Validar transiciones, log para auditoria |

### 8.4 Escenarios Multi-Dispositivo

Segun la documentacion de Sumsub:

| Escenario | Comportamiento |
|-----------|---------------|
| Usuario abre link en mismo dispositivo/browser | Retoma con progreso local (session storage) |
| Usuario abre link en otro dispositivo | Solo datos ya enviados a Sumsub se mantienen |
| Sesion expira (30 min inactividad) | Debe repetir verificacion de email |

### 8.5 Link Forwarding (Riesgo de Seguridad)

El link de verificacion podria ser reenviado a terceros. Mitigaciones:

```typescript
// Registrar metadatos de acceso
interface AccessLog {
  verificationId: string;
  ipAddress: string;
  userAgent: string;
  deviceFingerprint: string;  // Sumsub lo captura
  timestamp: Date;
}

// Alerta si detectamos acceso sospechoso
async function detectSuspiciousAccess(verificationId: string): Promise<void> {
  const logs = await getAccessLogs(verificationId);
  const uniqueIps = new Set(logs.map(l => l.ipAddress));

  if (uniqueIps.size > 2) {
    await alertComplianceTeam({
      type: 'SUSPICIOUS_MULTI_IP_ACCESS',
      verificationId,
      uniqueIps: Array.from(uniqueIps)
    });
  }
}
```

---

## 9. Esquema de Base de Datos

### 9.1 Tabla Principal: kyb_verifications

```sql
CREATE TABLE kyb_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identificadores
  external_company_id VARCHAR(512) NOT NULL,
  tenant_id VARCHAR(255) NOT NULL,
  provider_applicant_id VARCHAR(255),  -- ID en Sumsub

  -- Estado
  status VARCHAR(50) NOT NULL DEFAULT 'NOT_STARTED',
  provider_type VARCHAR(50) NOT NULL DEFAULT 'SUMSUB',

  -- Link de verificacion
  verification_link TEXT,
  link_expires_at TIMESTAMP WITH TIME ZONE,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Constraints
  CONSTRAINT uk_active_verification UNIQUE (external_company_id, tenant_id)
    WHERE status NOT IN ('APPROVED', 'REJECTED', 'EXPIRED', 'CANCELED')
);

-- Indices
CREATE INDEX idx_kyb_verifications_status ON kyb_verifications(status);
CREATE INDEX idx_kyb_verifications_tenant ON kyb_verifications(tenant_id);
CREATE INDEX idx_kyb_verifications_link_expires
  ON kyb_verifications(link_expires_at)
  WHERE status IN ('NOT_STARTED', 'IN_PROGRESS', 'ACTION_REQUIRED');
```

### 9.2 Tabla de Eventos: kyb_verification_events

```sql
CREATE TABLE kyb_verification_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id UUID NOT NULL REFERENCES kyb_verifications(id),

  -- Evento
  event_type VARCHAR(100) NOT NULL,
  provider_event_id VARCHAR(255),  -- correlationId de Sumsub
  provider_event_type VARCHAR(100),

  -- Transicion de estado
  previous_status VARCHAR(50),
  new_status VARCHAR(50),

  -- Payload completo
  payload JSONB NOT NULL,

  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,

  -- Constraint para idempotencia
  CONSTRAINT uk_provider_event UNIQUE (provider_event_id)
);

-- Index para busqueda por verification
CREATE INDEX idx_kyb_events_verification ON kyb_verification_events(verification_id);
```

### 9.3 Tabla de Webhooks Procesados

```sql
CREATE TABLE processed_webhooks (
  correlation_id VARCHAR(255) PRIMARY KEY,
  applicant_id VARCHAR(255) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  resulting_status VARCHAR(50),

  -- TTL - limpiar despues de 30 dias
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '30 days'
);

-- Index para limpieza periodica
CREATE INDEX idx_processed_webhooks_expires ON processed_webhooks(expires_at);
```

---

## 10. Pseudocodigo de Implementacion

### 10.1 Servicio de Verificacion

```typescript
class KybVerificationService {

  async createOrGetVerification(
    request: CreateVerificationRequest
  ): Promise<CreateVerificationResponse> {
    const { externalCompanyId, tenantId } = request;

    // 1. Adquirir lock distribuido
    const lockValue = generateUniqueId();
    const lockAcquired = await this.acquireLock(tenantId, externalCompanyId, lockValue);

    if (!lockAcquired) {
      throw new ConcurrentRequestError('Verification creation in progress');
    }

    try {
      // 2. Buscar verificacion existente
      const existing = await this.findActiveVerification(externalCompanyId, tenantId);

      if (existing) {
        return this.handleExistingVerification(existing, request);
      }

      // 3. Verificar si ya esta aprobada
      const approved = await this.findApprovedVerification(externalCompanyId, tenantId);
      if (approved) {
        throw new CompanyAlreadyVerifiedError(approved.id);
      }

      // 4. Crear nueva verificacion
      return this.createNewVerification(request);

    } finally {
      // 5. Liberar lock
      await this.releaseLock(tenantId, externalCompanyId, lockValue);
    }
  }

  private async handleExistingVerification(
    verification: KybVerification,
    request: CreateVerificationRequest
  ): Promise<CreateVerificationResponse> {

    // Evaluar estado y validez del link
    switch (verification.status) {
      case 'APPROVED':
        throw new CompanyAlreadyVerifiedError(verification.id);

      case 'REJECTED':
        if (verification.rejectType === 'FINAL') {
          throw new VerificationFinallyRejectedError(verification.id);
        }
        // RETRY - puede continuar con link existente o regenerar
        return this.handleRetryableVerification(verification);

      case 'PENDING_REVIEW':
      case 'IN_REVIEW':
        throw new VerificationInProgressError(verification.id);

      case 'NOT_STARTED':
      case 'IN_PROGRESS':
      case 'ACTION_REQUIRED':
        if (this.isLinkValid(verification)) {
          // Reusar link existente
          return {
            id: verification.id,
            status: verification.status,
            verificationLink: verification.verificationLink,
            linkExpiresAt: verification.linkExpiresAt,
            isExisting: true
          };
        } else {
          // Regenerar link
          return this.regenerateLink(verification);
        }

      case 'EXPIRED':
      case 'CANCELED':
        // Crear nueva verificacion
        return this.createNewVerification(request);

      default:
        throw new UnexpectedStatusError(verification.status);
    }
  }

  private isLinkValid(verification: KybVerification): boolean {
    if (!verification.linkExpiresAt) return false;
    return new Date() < verification.linkExpiresAt;
  }

  private async regenerateLink(
    verification: KybVerification
  ): Promise<CreateVerificationResponse> {
    // Generar nuevo link en Sumsub
    const newLink = await this.sumsubClient.generatePermalink({
      applicantId: verification.providerApplicantId,
      levelName: verification.levelName,
      ttlInSecs: this.config.defaultTtl
    });

    // Actualizar verificacion
    verification.verificationLink = newLink.url;
    verification.linkExpiresAt = this.calculateExpiration(this.config.defaultTtl);

    if (verification.status === 'EXPIRED') {
      verification.status = 'NOT_STARTED';
    }

    verification.updatedAt = new Date();
    await this.repository.save(verification);

    return {
      id: verification.id,
      status: verification.status,
      verificationLink: newLink.url,
      linkExpiresAt: verification.linkExpiresAt,
      isExisting: true
    };
  }

  private async createNewVerification(
    request: CreateVerificationRequest
  ): Promise<CreateVerificationResponse> {
    // 1. Crear applicant en Sumsub
    const applicant = await this.sumsubClient.createApplicant({
      externalUserId: request.externalCompanyId,
      type: 'company',
      levelName: this.getLevelByCountry(request.companyInfo.country),
      companyInfo: {
        companyName: request.companyInfo.legalName,
        registrationNumber: request.companyInfo.registrationNumber,
        country: request.companyInfo.country
      }
    });

    // 2. Generar link de verificacion
    const link = await this.sumsubClient.generatePermalink({
      applicantId: applicant.id,
      levelName: applicant.levelName,
      ttlInSecs: request.ttlSeconds || this.config.defaultTtl
    });

    // 3. Crear registro en BD
    const verification = await this.repository.create({
      externalCompanyId: request.externalCompanyId,
      tenantId: request.tenantId,
      providerApplicantId: applicant.id,
      providerType: 'SUMSUB',
      status: 'NOT_STARTED',
      verificationLink: link.url,
      linkExpiresAt: this.calculateExpiration(request.ttlSeconds || this.config.defaultTtl),
      levelName: applicant.levelName,
      metadata: {
        companyInfo: request.companyInfo,
        requestedAt: new Date().toISOString()
      }
    });

    // 4. Publicar evento
    await this.eventBus.publish('kyb.verification.created', {
      verificationId: verification.id,
      externalCompanyId: request.externalCompanyId,
      tenantId: request.tenantId
    });

    return {
      id: verification.id,
      status: 'NOT_STARTED',
      verificationLink: link.url,
      linkExpiresAt: verification.linkExpiresAt,
      isExisting: false
    };
  }
}
```

### 10.2 Handler de Webhooks

```typescript
class SumsubWebhookHandler {

  async handle(
    payload: string,
    signature: string
  ): Promise<WebhookResponse> {
    // 1. Validar firma
    if (!this.validateSignature(payload, signature)) {
      throw new UnauthorizedError('Invalid webhook signature');
    }

    const event: WebhookPayload = JSON.parse(payload);

    // 2. Verificar idempotencia
    const alreadyProcessed = await this.isAlreadyProcessed(event.correlationId);
    if (alreadyProcessed) {
      return { status: 'already_processed' };
    }

    // 3. Procesar en transaccion
    return await this.database.transaction(async (tx) => {
      // 3.1 Buscar verificacion
      const verification = await tx.findVerificationByProviderApplicantId(
        event.applicantId
      );

      if (!verification) {
        // Puede ser applicant creado directamente en Sumsub dashboard
        this.logger.warn('Webhook for unknown applicant', { event });
        await this.markAsProcessed(tx, event, null);
        return { status: 'ignored' };
      }

      // 3.2 Mapear estado
      const newStatus = this.mapStatus(event);
      const previousStatus = verification.status;

      // 3.3 Validar transicion
      if (!this.isValidTransition(previousStatus, newStatus)) {
        this.logger.warn('Invalid transition', {
          correlationId: event.correlationId,
          from: previousStatus,
          to: newStatus
        });
        // Guardar evento pero no actualizar estado
        await this.saveEvent(tx, verification.id, event, previousStatus, null);
        await this.markAsProcessed(tx, event, previousStatus);
        return { status: 'invalid_transition' };
      }

      // 3.4 Actualizar verificacion
      verification.status = newStatus;
      verification.updatedAt = new Date();

      if (newStatus === 'APPROVED' || newStatus === 'REJECTED') {
        verification.completedAt = new Date();

        if (event.reviewResult?.rejectLabels) {
          verification.metadata.rejectLabels = event.reviewResult.rejectLabels;
        }
        if (event.reviewResult?.moderationComment) {
          verification.metadata.moderationComment = event.reviewResult.moderationComment;
        }
      }

      await tx.save(verification);

      // 3.5 Guardar evento
      await this.saveEvent(tx, verification.id, event, previousStatus, newStatus);

      // 3.6 Marcar como procesado
      await this.markAsProcessed(tx, event, newStatus);

      // 3.7 Publicar evento interno
      await this.eventBus.publish('kyb.status.changed', {
        verificationId: verification.id,
        externalCompanyId: verification.externalCompanyId,
        tenantId: verification.tenantId,
        previousStatus,
        newStatus,
        correlationId: event.correlationId
      });

      return { status: 'processed', newStatus };
    });
  }

  private mapStatus(event: WebhookPayload): VerificationStatus {
    const { reviewStatus, reviewResult } = event;

    if (reviewStatus === 'init') return 'NOT_STARTED';
    if (reviewStatus === 'pending') return 'PENDING_REVIEW';
    if (reviewStatus === 'awaitingService') return 'PENDING_REVIEW';
    if (reviewStatus === 'onHold') return 'IN_REVIEW';
    if (reviewStatus === 'awaitingUser') return 'ACTION_REQUIRED';

    if (reviewStatus === 'completed') {
      if (reviewResult?.reviewAnswer === 'GREEN') return 'APPROVED';
      if (reviewResult?.reviewAnswer === 'RED') {
        if (reviewResult?.reviewRejectType === 'FINAL') return 'REJECTED';
        if (reviewResult?.reviewRejectType === 'RETRY') return 'ACTION_REQUIRED';
      }
    }

    this.logger.warn('Unknown status mapping', { reviewStatus, reviewResult });
    return 'PENDING_REVIEW'; // Default seguro
  }
}
```

### 10.3 Job de Reconciliacion

```typescript
class ReconciliationJob {

  // Ejecutar diariamente a las 3 AM
  @Cron('0 3 * * *')
  async reconcile(): Promise<void> {
    this.logger.log('Starting daily reconciliation');

    // 1. Obtener verificaciones activas
    const activeVerifications = await this.repository.findByStatuses([
      'NOT_STARTED', 'IN_PROGRESS', 'PENDING_REVIEW',
      'IN_REVIEW', 'ACTION_REQUIRED'
    ]);

    const discrepancies: Discrepancy[] = [];

    for (const verification of activeVerifications) {
      await this.rateLimiter.acquire(); // Max 2 req/sec a Sumsub

      try {
        // 2. Obtener estado actual de Sumsub
        const sumsubData = await this.sumsubClient.getApplicant(
          verification.providerApplicantId
        );

        const expectedStatus = this.mapSumsubStatus(sumsubData);

        // 3. Comparar
        if (expectedStatus !== verification.status) {
          discrepancies.push({
            verificationId: verification.id,
            localStatus: verification.status,
            sumsubStatus: expectedStatus,
            sumsubRaw: sumsubData
          });
        }
      } catch (error) {
        this.logger.error('Reconciliation failed for verification', {
          verificationId: verification.id,
          error: error.message
        });
      }
    }

    // 4. Reportar y corregir
    if (discrepancies.length > 0) {
      await this.alertComplianceTeam(discrepancies);

      // Auto-corregir si esta habilitado
      if (this.config.autoCorrect) {
        for (const d of discrepancies) {
          await this.correctStatus(d);
        }
      }
    }

    this.logger.log('Reconciliation completed', {
      checked: activeVerifications.length,
      discrepancies: discrepancies.length
    });
  }
}
```

### 10.4 Job de Deteccion de Links Expirados

```typescript
class LinkExpirationJob {

  // Ejecutar cada hora
  @Cron('0 * * * *')
  async checkExpiredLinks(): Promise<void> {
    const now = new Date();

    // Buscar verificaciones con links expirados que no se marcaron
    const expiredVerifications = await this.repository.query(`
      SELECT * FROM kyb_verifications
      WHERE status IN ('NOT_STARTED', 'IN_PROGRESS', 'ACTION_REQUIRED')
        AND link_expires_at < $1
        AND link_expires_at IS NOT NULL
    `, [now]);

    for (const verification of expiredVerifications) {
      // Marcar como expirado
      verification.status = 'EXPIRED';
      verification.updatedAt = now;
      await this.repository.save(verification);

      // Notificar
      await this.eventBus.publish('kyb.link.expired', {
        verificationId: verification.id,
        externalCompanyId: verification.externalCompanyId,
        tenantId: verification.tenantId,
        expiredAt: verification.linkExpiresAt
      });

      this.logger.log('Marked verification as expired', {
        verificationId: verification.id
      });
    }
  }
}
```

---

## 11. Referencias

### Documentacion Oficial Sumsub

1. **Verification Links** - Tipos de links, TTL, comportamiento de expiracion
   https://docs.sumsub.com/docs/verification-links

2. **User Verification Webhooks** - Tipos de webhook, payload, correlationId
   https://docs.sumsub.com/docs/user-verification-webhooks

3. **Create Applicant** - Creacion de applicants, externalUserId
   https://docs.sumsub.com/reference/create-applicant

4. **Get Applicant Data (externalUserId)** - Consulta por ID externo
   https://docs.sumsub.com/reference/get-applicant-data-via-externaluserid

5. **Applicant Statuses** - Estados de verificacion, reviewStatus, reviewAnswer
   https://docs.sumsub.com/docs/applicant-statuses

6. **Receive and Interpret Results via API** - Interpretacion de resultados
   https://docs.sumsub.com/docs/receive-and-interpret-results-via-api

7. **Token Expiration Handler** - Manejo de tokens expirados
   https://docs.sumsub.com/docs/token-expiration-handler

8. **Get Applicant Review Status** - Estados de revision
   https://docs.sumsub.com/reference/get-applicant-review-status

9. **Generate WebSDK External Link** - Generacion de permalinks via API
   https://docs.sumsub.com/reference/generate-websdk-external-link

10. **Reject Applicant** - Tipos de rechazo (FINAL vs RETRY)
    https://docs.sumsub.com/reference/reject-applicant

### Documentacion Interna Retorna

11. **SPIKE_LINK_BEHAVIOR.md** - Comportamiento detallado de links
    Ruta: `/home/rafael/Documents/retorna/core-reporting/spike-sumsub/SPIKE_LINK_BEHAVIOR.md`

12. **SPIKE_KYB_INTEGRATION_ARCHITECTURE.md** - Arquitectura de integracion
    Ruta: `/home/rafael/Documents/retorna/core-reporting/spike-sumsub/SPIKE_KYB_INTEGRATION_ARCHITECTURE.md`

### Patrones de Diseno

13. **Webhook Idempotency Patterns**
    https://dev.to/ramapratheeba/how-to-handle-duplicate-webhook-events-in-aspnet-core-idempotency-guide-4kj6

14. **Idempotence - What it is and How to Implement**
    https://dev.to/woovi/idempotence-what-is-and-how-to-implement-4bmc

---

## Historial de Cambios

| Fecha | Version | Cambios |
|-------|---------|---------|
| 2026-02-24 | 1.0 | Documento inicial |

---

**Documento preparado para revision por:**
- Equipo Backend
- Arquitectura
- Compliance
- QA
