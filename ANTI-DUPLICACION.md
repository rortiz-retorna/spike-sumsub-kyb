# Anti-duplicacion e Idempotencia - KYB

> **Version**: 1.0.0 | **Estado**: Draft

## 1. Regla Principal

```
┌────────────────────────────────────────────────────┐
│  1 verificacion activa por externalId (empresa)   │
└────────────────────────────────────────────────────┘
```

**Clave de idempotencia**: `externalId` (ID de empresa en nuestro sistema)

### Proteccion de Sumsub (built-in)

Sumsub tiene proteccion adicional a nivel de sesion:

```
┌─────────────────────────────────────────────────────────────────┐
│  Si un permalink con externalId ya tiene sesion activa,         │
│  Sumsub BLOQUEA apertura en otra pestana/navegador/dispositivo  │
└─────────────────────────────────────────────────────────────────┘
```

**Capas de proteccion:**

| Capa | Responsable | Proteccion |
|------|-------------|------------|
| 1. API | Nosotros | 1 verificacion activa por empresa |
| 2. BD | Nosotros | Constraint unico en estados activos |
| 3. Sesion | Sumsub | Bloquea multiples sesiones simultaneas |

Esto significa que aunque un usuario comparta el link, solo una persona puede estar activamente verificando a la vez.

---

## 2. Estados Activos vs Inactivos

| Estado | Activo? | Permite nueva? |
|--------|:-------:|:--------------:|
| `PENDING` | Si | No |
| `IN_PROGRESS` | Si | No |
| `APPROVED` | No (final) | No |
| `REJECTED` | No (final) | Si |
| `EXPIRED` | No | Si |

---

## 3. Logica de Generacion de Link

```mermaid
flowchart TD
    A[Request: generar link] --> B{Existe verificacion?}
    B -->|No| C[Crear nueva]
    B -->|Si| D{Estado?}

    D -->|PENDING/IN_PROGRESS| E{Link expirado?}
    E -->|No| F[Retornar link existente]
    E -->|Si| G[Marcar EXPIRED]
    G --> C

    D -->|APPROVED| H[Error: ya verificado]
    D -->|REJECTED/EXPIRED| C

    C --> I[Llamar Sumsub API]
    I --> J[Guardar verificacion]
    J --> K[Retornar nuevo link]
```

### Pseudocodigo

```typescript
async function getOrCreateVerificationLink(externalId: string, country: CountryCode): Promise<VerificationLink> {

  // 1. Buscar verificacion existente
  const existing = await repository.findByExternalId(externalId);

  // 2. Si no existe, crear nueva
  if (!existing) {
    return createNewVerification(externalId, country);
  }

  // 3. Evaluar estado
  switch (existing.status) {

    case 'APPROVED':
      throw new Error('Empresa ya verificada');

    case 'PENDING':
    case 'IN_PROGRESS':
      // Verificar si link sigue valido
      if (existing.urlExpiresAt > new Date()) {
        return existing.verificationUrl; // Retornar existente
      }
      // Link expirado -> marcar y crear nuevo
      await repository.updateStatus(existing.id, 'EXPIRED');
      return createNewVerification(externalId, country);

    case 'REJECTED':
    case 'EXPIRED':
      // Permitir nueva verificacion
      return createNewVerification(externalId, country);
  }
}
```

---

## 4. Constraint de Base de Datos

```sql
-- Solo 1 verificacion activa por empresa
CREATE UNIQUE INDEX idx_one_active_per_company
ON business_verifications (external_id)
WHERE status IN ('PENDING', 'IN_PROGRESS');
```

---

## 5. Idempotencia en Webhooks

### Problema
Sumsub puede enviar el mismo webhook multiples veces (reintentos, duplicados).

### Solucion
Guardar `webhookId` de cada evento procesado.

```mermaid
flowchart TD
    A[Webhook recibido] --> B{webhookId ya procesado?}
    B -->|Si| C[Ignorar - retornar 200]
    B -->|No| D[Procesar evento]
    D --> E[Guardar webhookId]
    E --> F[Actualizar estado]
    F --> G[Retornar 200]
```

### Tabla de Webhooks Procesados

```sql
CREATE TABLE processed_webhooks (
  webhook_id VARCHAR(100) PRIMARY KEY,
  external_id VARCHAR(100) NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  processed_at TIMESTAMP DEFAULT NOW()
);

-- Limpiar webhooks viejos (opcional, cron job)
-- DELETE FROM processed_webhooks WHERE processed_at < NOW() - INTERVAL '7 days';
```

### Pseudocodigo

```typescript
async function handleWebhook(payload: SumsubWebhook): Promise<void> {
  const webhookId = payload.correlationId || payload.applicantId + '_' + payload.type;

  // 1. Verificar si ya se proceso
  const alreadyProcessed = await webhookRepo.exists(webhookId);
  if (alreadyProcessed) {
    return; // Ignorar duplicado
  }

  // 2. Procesar
  const status = mapSumsubStatus(payload);
  await verificationRepo.updateStatus(payload.externalUserId, status);

  // 3. Marcar como procesado
  await webhookRepo.save({
    webhookId,
    externalId: payload.externalUserId,
    eventType: payload.type
  });
}
```

---

## 6. Diagrama de Secuencia Completo

```mermaid
sequenceDiagram
    participant Client
    participant API
    participant DB
    participant Sumsub

    %% Caso 1: Nueva verificacion
    Client->>API: POST /verifications {externalId}
    API->>DB: buscar por externalId
    DB-->>API: null
    API->>Sumsub: crear applicant + generar link
    Sumsub-->>API: url, expiresAt
    API->>DB: guardar verificacion (PENDING)
    API-->>Client: {url, expiresAt}

    %% Caso 2: Ya existe link valido
    Client->>API: POST /verifications {externalId}
    API->>DB: buscar por externalId
    DB-->>API: verificacion (PENDING, link valido)
    API-->>Client: {url existente}

    %% Caso 3: Link expirado
    Client->>API: POST /verifications {externalId}
    API->>DB: buscar por externalId
    DB-->>API: verificacion (PENDING, link expirado)
    API->>DB: actualizar status = EXPIRED
    API->>Sumsub: generar nuevo link
    Sumsub-->>API: nueva url
    API->>DB: guardar nueva verificacion (PENDING)
    API-->>Client: {nueva url}
```

---

## 7. Resumen de Reglas

| Escenario | Accion |
|-----------|--------|
| No existe verificacion | Crear nueva |
| Existe PENDING con link valido | Retornar existente |
| Existe PENDING con link expirado | Marcar EXPIRED, crear nueva |
| Existe IN_PROGRESS | Retornar existente (o error) |
| Existe APPROVED | Error: ya verificado |
| Existe REJECTED | Crear nueva |
| Existe EXPIRED | Crear nueva |
| Webhook duplicado | Ignorar (idempotente) |

---

## 8. Nomenclatura del externalId

### Formato

```
{tenantId}_{companyId}
```

### Ejemplo

| Campo | Valor |
|-------|-------|
| tenantId | `retorna` |
| companyId | `emp-co-001` |
| **externalId** | `retorna_emp-co-001` |

### En el webhook

```json
{
  "externalUserId": "retorna_emp-co-001",
  "type": "applicantReviewed",
  "reviewResult": { "reviewAnswer": "GREEN" }
}
```

### Parsing

```typescript
function parseExternalId(externalId: string): { tenantId: string; companyId: string } {
  const [tenantId, ...rest] = externalId.split('_');
  return { tenantId, companyId: rest.join('_') };
}

// parseExternalId("retorna_emp-co-001")
// → { tenantId: "retorna", companyId: "emp-co-001" }
```
