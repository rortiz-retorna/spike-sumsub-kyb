# Spike: Arquitectura de Integración KYB (Sumsub)

**Fecha:** 2026-02-23
**Autor:** Core Reporting / Backend
**Status:** Draft para revisión

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Modelo de Dominio y Contrato Interno](#2-modelo-de-dominio-y-contrato-interno)
3. [Mapping Estados Sumsub → Retorna](#3-mapping-estados-sumsub--retorna)
4. [Anti-duplicación e Idempotencia](#4-anti-duplicación-e-idempotencia)
5. [Mecanismo de Sincronización](#5-mecanismo-de-sincronización)
6. [Comportamiento del Link](#6-comportamiento-del-link)
7. [Automatización de Emails](#7-automatización-de-emails)
8. [Preparación MVP3 (SDK Embebido)](#8-preparación-mvp3-sdk-embebido)
9. [Riesgos y Mitigaciones](#9-riesgos-y-mitigaciones)
10. [Checklist de Implementación](#10-checklist-de-implementación)
11. [Fuentes](#11-fuentes)

---

## 1. Resumen Ejecutivo

### Objetivo
Diseñar una arquitectura provider-agnostic para integrar verificación KYB que permita:
- Generar y entregar links de verificación desde el portal
- Recibir y persistir estados del onboarding en tiempo razonable
- Bloquear verificaciones duplicadas
- Automatizar comunicaciones por email
- Facilitar cambio de proveedor o migración a SDK en el futuro

### Decisiones Clave

| Aspecto | Decisión |
|---------|----------|
| Sincronización primaria | Webhooks (event-driven) |
| Fallback | Polling cada 15 min para verificaciones activas |
| Identificador | `externalCompanyId` como ID estable |
| Anti-duplicación | 1 verificación activa por empresa |
| Contrato | Provider-agnostic con adapter pattern |
| Unidad de verificación | Por empresa (no por representante individual) |
| Módulo Sumsub | KYB + UBO (sin AML Screening en MVP2) |

### Alcance de Módulos Sumsub

> **Importante:** Sumsub es una plataforma modular. Los módulos son independientes y tienen costos separados.

| Módulo | Incluido MVP2 | Descripción |
|--------|---------------|-------------|
| **KYB** | ✅ Sí | Verificación de empresas (existencia, legitimidad, documentos) |
| **UBO** | ✅ Sí | Identificación de beneficiarios finales (incluido en flujo KYB) |
| **KYC** | ❌ No | Verificación de personas naturales (representantes) |
| **AML Screening** | ❌ No | Listas OFAC/ONU/UE, PEP, adverse media (módulo separado) |
| **KYT** | ❌ No | Know Your Transaction / análisis cripto |
| **TM** | ❌ No | Transaction Monitoring |

**Decisión:** MVP2 se enfoca exclusivamente en **KYB + UBO**. AML Screening se mantiene con Ceptinel hasta evaluar migración en fase posterior.

### Unidad de Verificación

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| Por empresa | Una verificación KYB por `externalCompanyId` | ✅ **Seleccionada** |
| Por representante | Una verificación por persona/UBO | ❌ No aplica para KYB |
| Por ambos | Empresa + cada representante separado | ❌ Complejidad innecesaria |

**Justificación:**
- KYB verifica la **empresa como entidad**, no individuos
- Los UBOs se verifican **dentro del mismo flujo KYB** de Sumsub
- El identificador estable es `externalCompanyId` (ID de empresa en Retorna)
- Un `tenantId` adicional permite multi-tenancy (clientes B2B usando el portal)

---

## 2. Modelo de Dominio y Contrato Interno

### 2.1 Entidades de Dominio

```
┌─────────────────────────────────────────────────────────────┐
│                      KYB VERIFICATION                        │
├─────────────────────────────────────────────────────────────┤
│ id: UUID (interno Retorna)                                  │
│ externalCompanyId: string (ID empresa en Retorna)           │
│ tenantId: string (cliente B2B multi-tenant)                 │
│ providerType: enum (SUMSUB | FUTURE_PROVIDER)               │
│ providerApplicantId: string (ID en el proveedor)            │
│ status: KybVerificationStatus                               │
│ verificationLink: string (URL del link activo)              │
│ linkExpiresAt: timestamp                                    │
│ createdAt: timestamp                                        │
│ updatedAt: timestamp                                        │
│ completedAt: timestamp (nullable)                           │
│ uboCount: integer (cantidad de UBOs identificados)          │
│ uboVerificationStatus: enum (PENDING|COMPLETE|PARTIAL)      │
│ metadata: jsonb (datos adicionales provider-specific)       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  KYB VERIFICATION EVENT                      │
├─────────────────────────────────────────────────────────────┤
│ id: UUID                                                    │
│ verificationId: UUID (FK → KYB_VERIFICATION)                │
│ eventType: string                                           │
│ providerEventId: string (para deduplicación)                │
│ providerEventType: string (evento original)                 │
│ previousStatus: KybVerificationStatus                       │
│ newStatus: KybVerificationStatus                            │
│ payload: jsonb (payload completo del webhook)               │
│ processedAt: timestamp                                      │
│ createdAt: timestamp                                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      KYB UBO (Beneficiario Final)            │
├─────────────────────────────────────────────────────────────┤
│ id: UUID                                                    │
│ verificationId: UUID (FK → KYB_VERIFICATION)                │
│ providerUboId: string (ID del UBO en Sumsub)                │
│ fullName: string                                            │
│ ownershipPercentage: decimal (nullable)                     │
│ role: string (director, shareholder, etc.)                  │
│ verificationStatus: enum (PENDING|VERIFIED|REJECTED)        │
│ createdAt: timestamp                                        │
│ updatedAt: timestamp                                        │
│ metadata: jsonb (datos adicionales del UBO)                 │
└─────────────────────────────────────────────────────────────┘
```

> **Nota sobre UBOs:** Los Ultimate Beneficial Owners se verifican como parte del flujo KYB de Sumsub.
> La entidad `KYB_UBO` almacena los datos extraídos del proveedor para auditoría y visualización en backoffice.
> No se requiere verificación KYC individual de UBOs en MVP2.

### 2.2 Estados Internos (Provider-Agnostic)

```typescript
enum KybVerificationStatus {
  NOT_STARTED    = 'NOT_STARTED',    // Link generado, usuario no inició
  IN_PROGRESS    = 'IN_PROGRESS',    // Usuario completando formulario
  PENDING_REVIEW = 'PENDING_REVIEW', // Enviado, esperando revisión
  IN_REVIEW      = 'IN_REVIEW',      // Revisión manual en curso
  ACTION_REQUIRED= 'ACTION_REQUIRED',// Usuario debe corregir/resubir docs
  APPROVED       = 'APPROVED',       // Verificación aprobada
  REJECTED       = 'REJECTED',       // Rechazo final (no reintentable)
  EXPIRED        = 'EXPIRED',        // Link/sesión expiró sin completar
  CANCELED       = 'CANCELED'        // Cancelado manualmente
}
```

### 2.3 Contrato Backend ↔ Frontend/Backoffice

#### GET /api/v1/kyb/verifications/{externalCompanyId}

**Response:**
```json
{
  "id": "uuid",
  "externalCompanyId": "company-123",
  "tenantId": "tenant-abc",
  "status": "IN_PROGRESS",
  "statusLabel": "En progreso",
  "verificationLink": "https://...",
  "linkExpiresAt": "2026-02-24T10:00:00Z",
  "canGenerateNewLink": false,
  "canRetry": false,
  "createdAt": "2026-02-23T10:00:00Z",
  "updatedAt": "2026-02-23T12:30:00Z",
  "completedAt": null,
  "rejectionReason": null,
  "actionRequired": null,
  "uboSummary": {
    "count": 2,
    "verificationStatus": "COMPLETE",
    "verified": 2,
    "pending": 0,
    "rejected": 0
  }
}
```

#### GET /api/v1/kyb/verifications/{id}/ubos

**Response:**
```json
{
  "verificationId": "uuid",
  "ubos": [
    {
      "id": "ubo-uuid-1",
      "fullName": "Juan Pérez",
      "ownershipPercentage": 51.0,
      "role": "shareholder",
      "verificationStatus": "VERIFIED"
    },
    {
      "id": "ubo-uuid-2",
      "fullName": "María García",
      "ownershipPercentage": 49.0,
      "role": "director",
      "verificationStatus": "VERIFIED"
    }
  ]
}
```

#### POST /api/v1/kyb/verifications

**Request:**
```json
{
  "externalCompanyId": "company-123",
  "tenantId": "tenant-abc",
  "companyInfo": {
    "legalName": "Empresa S.A.",
    "registrationNumber": "12345678-9",
    "country": "CL"
  },
  "linkTtlSeconds": 86400,
  "callbackUrl": "https://...",
  "lang": "es"
}
```

**Response:**
```json
{
  "id": "uuid",
  "status": "NOT_STARTED",
  "verificationLink": "https://...",
  "linkExpiresAt": "2026-02-24T10:00:00Z"
}
```

#### POST /api/v1/kyb/verifications/{id}/regenerate-link

**Condiciones:**
- Solo si status es `EXPIRED`, `ACTION_REQUIRED`, o `NOT_STARTED` con link expirado
- Retorna error si hay verificación activa

**Response:**
```json
{
  "id": "uuid",
  "verificationLink": "https://new-link...",
  "linkExpiresAt": "2026-02-25T10:00:00Z"
}
```

#### POST /api/v1/kyb/verifications/{id}/cancel

**Condiciones:**
- Solo si status NO es `APPROVED`, `REJECTED`, o `CANCELED`

---

## 3. Mapping Estados Sumsub → Retorna

### 3.1 Tabla de Mapping

| Sumsub reviewStatus | Sumsub reviewAnswer | Sumsub rejectType | → Estado Retorna | Notas |
|---------------------|---------------------|-------------------|------------------|-------|
| `init` | - | - | `NOT_STARTED` | Applicant creado, sin datos |
| `pending` | - | - | `PENDING_REVIEW` | Enviado para verificación |
| `queued` | - | - | `PENDING_REVIEW` | En cola de procesamiento |
| `onHold` | - | - | `IN_REVIEW` | En revisión manual |
| `completed` | `GREEN` | - | `APPROVED` | ✅ Aprobado |
| `completed` | `RED` | `RETRY` | `ACTION_REQUIRED` | Usuario puede corregir |
| `completed` | `RED` | `FINAL` | `REJECTED` | ❌ Rechazo definitivo |

### 3.2 Webhooks Sumsub → Transiciones

| Webhook Type | Transición de Estado |
|--------------|---------------------|
| `applicantCreated` | → `NOT_STARTED` |
| `applicantPending` | → `PENDING_REVIEW` |
| `applicantPrechecked` | → `PENDING_REVIEW` |
| `applicantOnHold` | → `IN_REVIEW` |
| `applicantReviewed` (GREEN) | → `APPROVED` |
| `applicantReviewed` (RED/RETRY) | → `ACTION_REQUIRED` |
| `applicantReviewed` (RED/FINAL) | → `REJECTED` |

### 3.3 Detección de IN_PROGRESS

Sumsub no envía webhook explícito cuando el usuario comienza. Opciones:

1. **Tracking via frontend callback** (recomendado para SDK)
2. **Inferir por cambio de datos** - Si `applicantPending` llega, asumimos que pasó por `IN_PROGRESS`
3. **Polling ligero** - Verificar estado cada X minutos si está en `NOT_STARTED`

**Decisión MVP2:** Transición implícita `NOT_STARTED` → `PENDING_REVIEW` cuando llegue webhook de pending.

### 3.4 Webhooks de UBO (Beneficiarios Finales)

Sumsub envía webhooks específicos para el proceso de verificación de UBOs dentro del flujo KYB:

| Webhook Type | Descripción | Acción en Retorna |
|--------------|-------------|-------------------|
| `applicantWorkflowCompleted` | Flujo KYB+UBO completado | Extraer datos de UBOs del payload |
| `applicantReviewed` (company) | Empresa revisada | Actualizar estado principal |

**Extracción de UBOs del payload:**

```python
def extract_ubos_from_webhook(payload):
    """
    Los UBOs vienen en el campo 'info.companyInfo.beneficiaries'
    del applicant de tipo 'company'
    """
    beneficiaries = payload.get('info', {}).get('companyInfo', {}).get('beneficiaries', [])

    ubos = []
    for b in beneficiaries:
        ubos.append({
            'provider_ubo_id': b.get('applicantId'),
            'full_name': f"{b.get('firstName', '')} {b.get('lastName', '')}".strip(),
            'ownership_percentage': b.get('shareSize'),
            'role': b.get('type'),  # 'ubo', 'director', 'shareholder'
            'verification_status': map_ubo_status(b.get('reviewResult'))
        })

    return ubos
```

**Estados de UBO:**

| Estado Sumsub | → Estado Retorna |
|---------------|------------------|
| `reviewResult.reviewAnswer = GREEN` | `VERIFIED` |
| `reviewResult.reviewAnswer = RED` | `REJECTED` |
| Sin reviewResult | `PENDING` |

---

## 4. Anti-duplicación e Idempotencia

### 4.1 Regla Principal

```
1 verificación activa por externalCompanyId + tenantId
```

**Estados "activos" que bloquean nueva verificación:**
- `NOT_STARTED` (con link no expirado)
- `IN_PROGRESS`
- `PENDING_REVIEW`
- `IN_REVIEW`
- `ACTION_REQUIRED`

**Estados que permiten nueva verificación:**
- `APPROVED` (ya verificado)
- `REJECTED` (decisión: ¿permitir retry después de X días?)
- `EXPIRED`
- `CANCELED`

### 4.2 Algoritmo de Creación

```python
def create_verification(company_id, tenant_id, ...):
    # 1. Buscar verificación activa
    active = find_active_verification(company_id, tenant_id)

    if active:
        if active.status == 'NOT_STARTED' and active.link_expired():
            # Regenerar link en verificación existente
            return regenerate_link(active)
        else:
            # Bloquear - hay verificación en curso
            raise VerificationAlreadyActiveError(active.id)

    # 2. Verificar si ya está aprobado
    approved = find_approved_verification(company_id, tenant_id)
    if approved:
        raise CompanyAlreadyVerifiedError(approved.id)

    # 3. Crear nueva verificación
    return create_new_verification(...)
```

### 4.3 Idempotencia de Webhooks

```python
def process_webhook(payload):
    event_id = payload['correlationId']  # ID único del evento

    # Verificar si ya procesamos este evento
    if event_exists(event_id):
        return {'status': 'already_processed'}

    # Procesar dentro de transacción
    with transaction():
        verification = find_by_provider_id(payload['applicantId'])

        # Validar transición de estado válida
        new_status = map_to_internal_status(payload)
        if not is_valid_transition(verification.status, new_status):
            log_invalid_transition(verification, new_status, payload)
            # Igual guardamos el evento para auditoría

        # Actualizar estado
        verification.status = new_status
        verification.updated_at = now()

        # Guardar evento para auditoría y deduplicación
        save_event(
            verification_id=verification.id,
            provider_event_id=event_id,
            provider_event_type=payload['type'],
            previous_status=verification.status,
            new_status=new_status,
            payload=payload
        )

    return {'status': 'processed'}
```

### 4.4 Manejo de Eventos Fuera de Orden

```python
VALID_TRANSITIONS = {
    'NOT_STARTED': ['IN_PROGRESS', 'PENDING_REVIEW', 'EXPIRED', 'CANCELED'],
    'IN_PROGRESS': ['PENDING_REVIEW', 'EXPIRED', 'CANCELED'],
    'PENDING_REVIEW': ['IN_REVIEW', 'APPROVED', 'ACTION_REQUIRED', 'REJECTED'],
    'IN_REVIEW': ['APPROVED', 'ACTION_REQUIRED', 'REJECTED'],
    'ACTION_REQUIRED': ['PENDING_REVIEW', 'APPROVED', 'REJECTED', 'EXPIRED'],
    'APPROVED': ['REJECTED'],  # Caso fraude detectado post-aprobación
    'REJECTED': [],
    'EXPIRED': ['NOT_STARTED'],  # Regeneración de link
    'CANCELED': []
}

def is_valid_transition(current, new):
    return new in VALID_TRANSITIONS.get(current, [])
```

---

## 5. Mecanismo de Sincronización

### 5.1 Arquitectura Híbrida

```
┌─────────────┐     Webhook      ┌──────────────┐
│   SUMSUB    │ ───────────────► │   RETORNA    │
│             │                  │   Backend    │
│             │ ◄─────────────── │              │
│             │   Polling API    │              │
└─────────────┘   (fallback)     └──────────────┘
```

### 5.2 Webhooks (Primario)

**Configuración en Sumsub:**
- URL: `https://api.retorna.app/webhooks/sumsub`
- Tipos: `applicantCreated`, `applicantPending`, `applicantOnHold`, `applicantReviewed`
- Applicant Types: `Company`
- Secret: Para validación de firma

**Validación de Firma:**
```python
import hmac
import hashlib

def validate_sumsub_signature(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
```

**Retry Policy de Sumsub:**
- Timeout: 5 segundos (si no respondemos, reintenta)
- Reintentos: 4 veces (5 min, 1 hora, 5 horas, 18 horas)
- Total: ~24 horas de reintentos

**Nuestro Endpoint:**
```python
@app.post("/webhooks/sumsub")
async def sumsub_webhook(request: Request):
    # 1. Validar firma
    signature = request.headers.get('X-Payload-Digest')
    if not validate_sumsub_signature(await request.body(), signature, SECRET):
        return Response(status_code=401)

    # 2. Responder rápido (< 5 seg)
    payload = await request.json()

    # 3. Encolar para procesamiento async
    await queue.publish('kyb.webhook.received', payload)

    return Response(status_code=200)
```

### 5.3 Polling (Fallback/Contingencia)

**Cuándo usar:**
- Webhooks no configurados o fallando
- Reconciliación periódica
- Verificaciones "estancadas"

**Implementación:**
```python
# Cron job cada 15 minutos
async def poll_active_verifications():
    active_verifications = get_verifications_by_status([
        'NOT_STARTED', 'IN_PROGRESS', 'PENDING_REVIEW',
        'IN_REVIEW', 'ACTION_REQUIRED'
    ])

    for v in active_verifications:
        # Rate limit: max 2 req/sec a Sumsub
        await rate_limiter.acquire()

        try:
            sumsub_data = await sumsub_client.get_applicant(
                v.provider_applicant_id
            )
            new_status = map_to_internal_status(sumsub_data)

            if new_status != v.status:
                await update_verification_status(v, new_status, source='polling')
        except Exception as e:
            log.error(f"Polling failed for {v.id}: {e}")
```

### 5.4 Reconciliación Diaria

```python
# Cron job diario a las 3 AM
async def daily_reconciliation():
    """
    Detecta discrepancias entre estado Retorna y Sumsub
    """
    all_active = get_all_active_verifications()

    discrepancies = []
    for v in all_active:
        sumsub_data = await sumsub_client.get_applicant(v.provider_applicant_id)
        expected_status = map_to_internal_status(sumsub_data)

        if expected_status != v.status:
            discrepancies.append({
                'verification_id': v.id,
                'retorna_status': v.status,
                'sumsub_status': expected_status,
                'sumsub_raw': sumsub_data
            })

    if discrepancies:
        await alert_compliance_team(discrepancies)
        # Opcionalmente auto-corregir
        for d in discrepancies:
            await update_verification_status(
                d['verification_id'],
                d['sumsub_status'],
                source='reconciliation'
            )
```

---

## 6. Comportamiento del Link

### 6.1 Tipos de Link en Sumsub

Sumsub ofrece diferentes mecanismos para iniciar verificaciones. Es crítico entender las diferencias para elegir el correcto.

#### Comparativa Detallada

| Característica | Unilink | Permalink | Access Token |
|----------------|---------|-----------|--------------|
| **Descripción** | Un link universal por nivel de verificación | Un link único por applicant | Token temporal para SDK embebido |
| **Reutilización** | ✅ Múltiples applicants | ❌ Un solo uso | ❌ Un solo uso |
| **Requiere email** | ✅ Obligatorio antes de iniciar | ❌ No requerido | ❌ No requerido |
| **Creación** | Automático al guardar nivel | Manual via Dashboard o API | API on-demand |
| **Control de expiración** | No configurable | ✅ `ttlInSecs` configurable | ✅ Configurable |
| **Identificación** | Por email (1 email = 1 applicant) | Por `externalUserId` | Por `applicantId` |
| **Caso de uso** | Landing pages públicas, QR codes | ✅ **Verificación de usuario conocido** | SDK embebido (MVP3) |
| **Riesgo** | Mezcla de empresas si se comparte | Bajo (vinculado a empresa) | Bajo |

#### Unilink - NO recomendado para KYB

```
Características:
- Se genera automáticamente al crear un nivel de verificación
- El mismo link puede ser usado por múltiples empresas
- Requiere que el usuario verifique su email antes de iniciar
- El email determina el applicant (1 email = 1 applicant por nivel)
- Sesión persiste 30 minutos en mismo dispositivo/browser

⚠️ NO USAR PARA KYB porque:
- No hay control sobre qué empresa usa el link
- Dependencia del email para identificación
- Imposible vincular a externalCompanyId antes de que inicie
```

#### Permalink - RECOMENDADO para MVP2

```
Características:
- Se genera bajo demanda via API o Dashboard
- Vinculado a un externalUserId específico (nuestra empresa)
- Un solo uso: una vez completado, no puede reutilizarse
- TTL configurable (recomendado: 24-72 horas)
- No requiere verificación de email previa
- Permite configurar redirects post-verificación

✅ USAR PARA KYB porque:
- Control total: sabemos qué empresa usará el link
- Trazabilidad: externalUserId = externalCompanyId
- Seguridad: link único, no compartible entre empresas
- UX: configuramos redirect a nuestro portal
```

### 6.2 Generación de Permalink (MVP2)

#### API Endpoint

```http
POST https://api.sumsub.com/resources/sdkIntegrations/levels/-/websdkLink
Content-Type: application/json
X-App-Token: {API_TOKEN}
X-App-Access-Sig: {SIGNATURE}
X-App-Access-Ts: {TIMESTAMP}

{
  "levelName": "kyb-company-verification",
  "userId": "company-123",
  "ttlInSecs": 86400,
  "lang": "es",
  "applicantIdentifiers": {
    "email": "contacto@empresa.com",
    "phone": "+56912345678"
  },
  "redirect": {
    "successUrl": "https://app.retorna.com/kyb/success?id={externalUserId}",
    "rejectUrl": "https://app.retorna.com/kyb/retry?id={externalUserId}"
  }
}
```

#### Response

```json
{
  "url": "https://in.sumsub.com/websdk/p/sbx_abc123xyz..."
}
```

#### Parámetros Detallados

| Parámetro | Tipo | Requerido | Descripción |
|-----------|------|-----------|-------------|
| `levelName` | string | ✅ | Nombre del nivel de verificación configurado en Sumsub |
| `userId` | string | ✅ | `externalCompanyId` de Retorna para trazabilidad |
| `ttlInSecs` | integer | ❌ | Tiempo de vida en segundos (default: 7200 = 2h) |
| `lang` | string | ❌ | Idioma del WebSDK (`es`, `en`, `pt`, etc.) |
| `applicantIdentifiers.email` | string | ❌ | Email para pre-poblar formulario |
| `applicantIdentifiers.phone` | string | ❌ | Teléfono para pre-poblar |
| `redirect.successUrl` | string | ❌ | URL redirect tras verificación exitosa |
| `redirect.rejectUrl` | string | ❌ | URL redirect tras rechazo/retry |

#### TTL Recomendados

| Escenario | TTL | Justificación |
|-----------|-----|---------------|
| Email con link | 86400 (24h) | Usuario puede abrir email al día siguiente |
| Reminder | 172800 (48h) | Extender para usuarios ocupados |
| Urgente | 14400 (4h) | Verificación inmediata requerida |
| Máximo | 604800 (7d) | Límite práctico por seguridad |

### 6.3 Implementación en Retorna

```python
from datetime import datetime, timedelta

class SumsubLinkGenerator:
    """
    Generador de Permalinks de Sumsub para verificación KYB.
    Usa la API de WebSDK External Link.
    """

    BASE_URL = "https://api.sumsub.com/resources/sdkIntegrations/levels/-/websdkLink"
    DEFAULT_TTL = 86400  # 24 horas
    DEFAULT_LANG = "es"

    def __init__(self, api_client: SumsubApiClient, config: KybConfig):
        self.api_client = api_client
        self.config = config

    async def generate_permalink(
        self,
        external_company_id: str,
        company_email: str | None = None,
        company_phone: str | None = None,
        ttl_seconds: int | None = None,
        lang: str | None = None
    ) -> dict:
        """
        Genera un permalink único para verificación KYB.

        Args:
            external_company_id: ID de la empresa en Retorna
            company_email: Email de contacto (opcional, pre-popula formulario)
            company_phone: Teléfono de contacto (opcional)
            ttl_seconds: Tiempo de vida del link en segundos
            lang: Idioma del WebSDK

        Returns:
            {
                "url": "https://in.sumsub.com/websdk/p/...",
                "expires_at": "2026-02-24T10:00:00Z"
            }
        """
        ttl = ttl_seconds or self.DEFAULT_TTL

        payload = {
            "levelName": self.config.kyb_level_name,
            "userId": external_company_id,  # Nuestro ID = externalUserId en Sumsub
            "ttlInSecs": ttl,
            "lang": lang or self.DEFAULT_LANG,
            "redirect": {
                "successUrl": f"{self.config.portal_base_url}/kyb/verification-complete",
                "rejectUrl": f"{self.config.portal_base_url}/kyb/verification-pending"
            }
        }

        # Agregar identificadores si están disponibles
        if company_email or company_phone:
            payload["applicantIdentifiers"] = {}
            if company_email:
                payload["applicantIdentifiers"]["email"] = company_email
            if company_phone:
                payload["applicantIdentifiers"]["phone"] = company_phone

        response = await self.api_client.post(self.BASE_URL, payload)

        return {
            "url": response["url"],
            "expires_at": (datetime.utcnow() + timedelta(seconds=ttl)).isoformat() + "Z"
        }
```

### 6.4 Flujo Completo: Generación y Envío de Link

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Portal    │      │  KYB API    │      │   SUMSUB    │      │   Email     │
│   B2B       │      │  Service    │      │    API      │      │   Service   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │                    │
       │ POST /kyb/verifications               │                    │
       │ {externalCompanyId, tenantId}          │                    │
       │───────────────────►│                    │                    │
       │                    │                    │                    │
       │                    │ Validar no duplicado                   │
       │                    │───────────┐       │                    │
       │                    │◄──────────┘       │                    │
       │                    │                    │                    │
       │                    │ POST /websdkLink  │                    │
       │                    │ {levelName, userId,│                    │
       │                    │  ttlInSecs, redirect}                  │
       │                    │───────────────────►│                    │
       │                    │                    │                    │
       │                    │ {url: "https://..."}                   │
       │                    │◄───────────────────│                    │
       │                    │                    │                    │
       │                    │ Guardar verification                   │
       │                    │ con link y expiration                  │
       │                    │───────────┐       │                    │
       │                    │◄──────────┘       │                    │
       │                    │                    │                    │
       │                    │ Publicar evento   │                    │
       │                    │ KYB_LINK_GENERATED│                    │
       │                    │────────────────────────────────────────►│
       │                    │                    │                    │
       │ {id, verificationLink,                 │                    │
       │  linkExpiresAt}    │                    │                    │
       │◄───────────────────│                    │                    │
       │                    │                    │                    │
       │                    │                    │    Enviar email   │
       │                    │                    │    con link       │
       │                    │                    │◄───────────────────│
       │                    │                    │                    │
```

### 6.5 Comportamiento de Reanudación

| Escenario | Comportamiento | Verificado |
|-----------|----------------|------------|
| Usuario abandona, vuelve con link válido | **Retoma donde dejó** - El progreso se guarda | ✅ Documentado |
| Usuario abandona, link expiró | **No puede acceder** - Necesita nuevo link | ✅ Documentado |
| Usuario completa, intenta usar link otra vez | **Ve mensaje de completado** - No puede modificar | ✅ Documentado |
| Link forwarded a tercero | **Puede completar** - ⚠️ Riesgo de suplantación | ⚠️ Riesgo |

### 6.6 Expiración del Link

**¿Qué pasa cuando el link expira?**

1. **Durante navegación activa:** El SDK muestra error de sesión expirada
2. **Al intentar acceder:** Página de error/link inválido
3. **Respuesta técnica:** Sumsub retorna error en la carga del SDK

**Código de Error Esperado:**
```json
{
  "errorCode": 4001,
  "errorName": "token-invalid",
  "description": "Access token is invalid or expired"
}
```

**Manejo en Retorna:**
```python
async def handle_link_expiration(verification_id):
    verification = get_verification(verification_id)

    # Solo marcar como expirado si no avanzó
    if verification.status in ['NOT_STARTED', 'IN_PROGRESS']:
        if verification.link_expires_at < now():
            verification.status = 'EXPIRED'
            await notify_user_link_expired(verification)
```

### 6.7 Regeneración de Link

**Condiciones para regenerar:**

```python
def can_regenerate_link(verification):
    # Casos válidos para regenerar
    if verification.status == 'EXPIRED':
        return True

    if verification.status == 'NOT_STARTED' and verification.link_expired():
        return True

    if verification.status == 'ACTION_REQUIRED':
        return True

    return False
```

**API para regenerar:**
```python
async def regenerate_link(verification_id):
    verification = get_verification(verification_id)

    if not can_regenerate_link(verification):
        raise CannotRegenerateLinkError(
            f"Cannot regenerate link in status {verification.status}"
        )

    # Generar nuevo link para el mismo applicant
    new_link = await sumsub_client.generate_external_link(
        applicant_id=verification.provider_applicant_id,
        ttl_seconds=86400
    )

    verification.verification_link = new_link['url']
    verification.link_expires_at = now() + timedelta(seconds=86400)
    verification.status = 'NOT_STARTED' if verification.status == 'EXPIRED' else verification.status

    return verification
```

### 6.8 Tabla de Decisiones: Link Existente vs Nuevo

| Estado Actual | Link Expirado | Acción |
|---------------|---------------|--------|
| `NOT_STARTED` | No | Reusar link existente |
| `NOT_STARTED` | Sí | Regenerar link |
| `IN_PROGRESS` | No | Reusar link existente |
| `IN_PROGRESS` | Sí | Regenerar link |
| `ACTION_REQUIRED` | No | Reusar link existente |
| `ACTION_REQUIRED` | Sí | Regenerar link |
| `APPROVED` | - | Error: ya verificado |
| `REJECTED` | - | Requiere nueva verificación (si política lo permite) |
| `EXPIRED` | - | Regenerar link |

---

## 7. Automatización de Emails

### 7.1 Disparadores de Email

| Evento | Disparador | Contenido | Ventana |
|--------|------------|-----------|---------|
| Link generado | `NOT_STARTED` creado | "Completa tu verificación" + link | Inmediato |
| Reminder 1 | `NOT_STARTED` por 24h | "No olvides completar..." | 24h después de creación |
| Reminder 2 | `NOT_STARTED` por 48h | "Tu verificación está pendiente" | 48h después de creación |
| Link expirando | Link expira en 4h | "Tu link expira pronto" | 4h antes de expiración |
| En revisión | → `IN_REVIEW` | "Estamos revisando tu información" | Inmediato |
| Acción requerida | → `ACTION_REQUIRED` | "Necesitamos que corrijas..." + motivo | Inmediato |
| Aprobado | → `APPROVED` | "¡Felicitaciones! Tu empresa está verificada" | Inmediato |
| Rechazado | → `REJECTED` | "Tu verificación no pudo completarse" + pasos | Inmediato |
| Expirado | → `EXPIRED` | "Tu link expiró, genera uno nuevo" | Inmediato |

### 7.2 Arquitectura de Emails

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  KYB Service    │────►│  Event Queue    │────►│  Email Service  │
│                 │     │  (SQS/RabbitMQ) │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │  Email Provider │
                                                │  (SendGrid/SES) │
                                                └─────────────────┘
```

### 7.3 Eventos para Cola

```python
# Evento de estado cambiado
class KybStatusChangedEvent:
    verification_id: str
    company_id: str
    tenant_id: str
    previous_status: str
    new_status: str
    email: str
    company_name: str
    verification_link: str  # Solo si aplica
    rejection_reason: str   # Solo si aplica
    timestamp: datetime

# Publicar evento
async def on_status_change(verification, old_status, new_status):
    event = KybStatusChangedEvent(
        verification_id=verification.id,
        company_id=verification.external_company_id,
        tenant_id=verification.tenant_id,
        previous_status=old_status,
        new_status=new_status,
        email=verification.contact_email,
        company_name=verification.company_name,
        verification_link=verification.verification_link,
        rejection_reason=verification.rejection_reason,
        timestamp=now()
    )
    await queue.publish('kyb.status.changed', event)
```

### 7.4 Scheduler para Reminders

```python
# Cron job cada hora
async def check_pending_reminders():
    # Verificaciones en NOT_STARTED por más de 24h sin reminder 1
    pending_24h = get_verifications_needing_reminder(
        status='NOT_STARTED',
        hours_since_creation=24,
        reminder_sent=False,
        reminder_type='REMINDER_1'
    )

    for v in pending_24h:
        await queue.publish('kyb.reminder.needed', {
            'verification_id': v.id,
            'reminder_type': 'REMINDER_1'
        })
        await mark_reminder_sent(v.id, 'REMINDER_1')
```

### 7.5 Templates de Email (Ejemplo)

```yaml
# emails/kyb/link_generated.yaml
subject: "Completa la verificación de {{company_name}}"
body: |
  Hola,

  Para completar el proceso de onboarding de {{company_name}},
  necesitamos verificar la información de tu empresa.

  Haz clic en el siguiente enlace para continuar:
  {{verification_link}}

  Este enlace expira el {{link_expires_at | date("DD/MM/YYYY HH:mm")}}.

  Si tienes preguntas, contacta a nuestro equipo de soporte.

  Saludos,
  Equipo Retorna
```

---

## 8. Preparación MVP3 (SDK Embebido)

### 8.1 Cambios Esperados

| Aspecto | MVP2 (Link Externo) | MVP3 (SDK Embebido) |
|---------|---------------------|---------------------|
| Flujo usuario | Redirección a Sumsub | Iframe/modal en portal |
| Autenticación | Permalink con TTL | Access Token dinámico |
| Callbacks | Solo webhooks | Webhooks + JS callbacks |
| Detección IN_PROGRESS | No disponible | SDK `onStarted` callback |
| UX | Salir del portal | Sin salir del portal |

### 8.2 Contrato Interno - Sin Cambios

El contrato Backend ↔ Frontend **se mantiene idéntico**:
- Mismos endpoints
- Mismos estados
- Misma estructura de response

**Cambio en response para MVP3:**
```json
{
  "id": "uuid",
  "status": "NOT_STARTED",
  "verificationLink": null,  // Ya no se usa
  "accessToken": "sbx_abc123...",  // Nuevo campo
  "accessTokenExpiresAt": "2026-02-23T11:00:00Z",
  "linkExpiresAt": null  // Ya no aplica
}
```

### 8.3 Adapter Pattern para Proveedores

```python
# interfaces/kyb_provider.py
from abc import ABC, abstractmethod

class KybProvider(ABC):
    @abstractmethod
    async def create_applicant(self, company_info: CompanyInfo) -> str:
        """Retorna provider_applicant_id"""
        pass

    @abstractmethod
    async def generate_verification_link(
        self,
        applicant_id: str,
        ttl_seconds: int
    ) -> VerificationLink:
        pass

    @abstractmethod
    async def get_applicant_status(self, applicant_id: str) -> ProviderStatus:
        pass

    @abstractmethod
    def map_status(self, provider_status: ProviderStatus) -> KybVerificationStatus:
        pass

# providers/sumsub_provider.py
class SumsubProvider(KybProvider):
    async def create_applicant(self, company_info: CompanyInfo) -> str:
        response = await self.client.post('/resources/applicants', {
            'externalUserId': company_info.external_id,
            'type': 'company',
            'info': {
                'companyInfo': {
                    'companyName': company_info.legal_name,
                    'registrationNumber': company_info.registration_number,
                    'country': company_info.country
                }
            }
        })
        return response['id']

    def map_status(self, provider_status: ProviderStatus) -> KybVerificationStatus:
        # Implementación del mapping de sección 3
        ...

# providers/future_provider.py (ejemplo)
class FutureProvider(KybProvider):
    # Implementación para otro proveedor
    ...
```

### 8.4 Feature Flag para Migración

```python
# config.py
KYB_PROVIDER = os.getenv('KYB_PROVIDER', 'sumsub')
KYB_MODE = os.getenv('KYB_MODE', 'link')  # 'link' | 'sdk'

# factory.py
def get_kyb_provider() -> KybProvider:
    if KYB_PROVIDER == 'sumsub':
        return SumsubProvider(api_key=SUMSUB_API_KEY)
    elif KYB_PROVIDER == 'future':
        return FutureProvider(...)
    raise ValueError(f"Unknown provider: {KYB_PROVIDER}")
```

---

## 9. Riesgos y Mitigaciones

### 9.1 Matriz de Riesgos

| # | Riesgo | Probabilidad | Impacto | Mitigación |
|---|--------|--------------|---------|------------|
| 1 | **Duplicación de verificaciones** | Media | Alto (costos, fraude) | Bloqueo por externalCompanyId, validación en create |
| 2 | **Eventos perdidos (webhooks)** | Baja | Alto (estados desalineados) | Polling fallback, reconciliación diaria |
| 3 | **Link forwarding a terceros** | Media | Crítico (suplantación) | IP logging, device fingerprint (Sumsub lo hace), TTL corto |
| 4 | **Expiración silenciosa** | Media | Medio (caída conversión) | Reminders automáticos, alertas pre-expiración |
| 5 | **Multi-tenant data leak** | Baja | Crítico | Tenant ID en todas las queries, auditoría de acceso |
| 6 | **Acoplamiento a Sumsub** | Media | Medio (costo cambio) | Adapter pattern, contrato agnóstico |
| 7 | **Eventos fuera de orden** | Baja | Bajo | Validación de transiciones, logging |
| 8 | **Rate limiting Sumsub** | Baja | Medio | Backoff exponencial, cola de requests |

### 9.2 Mitigaciones Detalladas

#### Riesgo 5: Multi-tenant Data Leak

```python
# SIEMPRE incluir tenant_id en queries
def get_verification(verification_id: str, tenant_id: str):
    return db.query(KybVerification).filter(
        KybVerification.id == verification_id,
        KybVerification.tenant_id == tenant_id  # CRÍTICO
    ).first()

# Middleware de validación
@app.middleware
async def validate_tenant_access(request, call_next):
    tenant_id = get_tenant_from_token(request)
    verification_id = get_verification_id_from_path(request)

    if verification_id:
        verification = get_verification_by_id(verification_id)
        if verification.tenant_id != tenant_id:
            raise ForbiddenError("Access denied")

    return await call_next(request)
```

#### Riesgo 3: Link Forwarding

```python
# Registrar metadatos de acceso
async def on_verification_started(verification_id, request_metadata):
    await save_access_log(
        verification_id=verification_id,
        ip_address=request_metadata.ip,
        user_agent=request_metadata.user_agent,
        device_fingerprint=request_metadata.fingerprint,
        timestamp=now()
    )

# Alerta si hay acceso desde múltiples IPs/devices
async def detect_suspicious_access(verification_id):
    logs = get_access_logs(verification_id)
    unique_ips = set(log.ip_address for log in logs)

    if len(unique_ips) > 2:  # Umbral configurable
        await alert_compliance('SUSPICIOUS_MULTI_IP_ACCESS', {
            'verification_id': verification_id,
            'unique_ips': list(unique_ips)
        })
```

---

## 10. Checklist de Implementación

### 10.1 MVP2 - Stories Derivadas

#### Backend

- [ ] **KYB-001**: Crear modelo de datos (KybVerification, KybVerificationEvent, KybUbo)
- [ ] **KYB-002**: Implementar adapter Sumsub (create applicant, generate link, get status)
- [ ] **KYB-003**: Endpoint POST /api/v1/kyb/verifications
- [ ] **KYB-004**: Endpoint GET /api/v1/kyb/verifications/{externalCompanyId}
- [ ] **KYB-005**: Endpoint POST /api/v1/kyb/verifications/{id}/regenerate-link
- [ ] **KYB-006**: Endpoint POST /api/v1/kyb/verifications/{id}/cancel
- [ ] **KYB-007**: Endpoint GET /api/v1/kyb/verifications/{id}/ubos
- [ ] **KYB-008**: Webhook receiver /webhooks/sumsub (con validación de firma)
- [ ] **KYB-009**: Worker para procesar webhooks desde cola (incluye extracción UBOs)
- [ ] **KYB-010**: Cron job de polling (fallback cada 15 min)
- [ ] **KYB-011**: Cron job de reconciliación diaria
- [ ] **KYB-012**: Integración con servicio de emails (eventos de estado)
- [ ] **KYB-013**: Cron job para reminders automáticos
- [ ] **KYB-014**: Tests unitarios y de integración
- [ ] **KYB-015**: Documentación API (OpenAPI/Swagger)

#### Frontend/Backoffice

- [ ] **KYB-F01**: Vista de estado de verificación por empresa
- [ ] **KYB-F02**: Botón "Generar link de verificación"
- [ ] **KYB-F03**: Botón "Regenerar link" (condicionalmente visible)
- [ ] **KYB-F04**: Copiar link al clipboard
- [ ] **KYB-F05**: Indicadores visuales de estado (badges/chips)
- [ ] **KYB-F06**: Historial de eventos de verificación
- [ ] **KYB-F07**: Filtros por estado en listado de empresas
- [ ] **KYB-F08**: Vista de UBOs (beneficiarios finales) con estado de verificación

#### DevOps/Infra

- [ ] **KYB-D01**: Configurar webhook en Sumsub dashboard (sandbox)
- [ ] **KYB-D02**: Configurar webhook en Sumsub dashboard (producción)
- [ ] **KYB-D03**: Secrets management (API keys Sumsub)
- [ ] **KYB-D04**: Alertas de monitoreo (webhooks fallidos, discrepancias)
- [ ] **KYB-D05**: Dashboard de métricas (conversión, tiempos)

### 10.2 MVP3 - Stories Adicionales

- [ ] **KYB-301**: Implementar generación de Access Token
- [ ] **KYB-302**: Integrar WebSDK en frontend
- [ ] **KYB-303**: Implementar callbacks JS (onStarted, onCompleted, onError)
- [ ] **KYB-304**: Actualizar endpoint para retornar accessToken
- [ ] **KYB-305**: Handler para token expiration (refresh)
- [ ] **KYB-306**: Tests E2E con SDK embebido

---

## 11. Fuentes

### Documentación Sumsub

1. Sumsub. (2026). *Get started with API*. Sumsub Developers. https://docs.sumsub.com/reference/get-started-with-api

2. Sumsub. (2026). *User verification webhooks*. Sumsub Developers. https://docs.sumsub.com/docs/user-verification-webhooks

3. Sumsub. (2026). *Verification links*. Sumsub Developers. https://docs.sumsub.com/docs/verification-links

4. Sumsub. (2026). *Generate external WebSDK link*. Sumsub Developers. https://docs.sumsub.com/reference/generate-websdk-external-link

5. Sumsub. (2026). *Receive verification results*. Sumsub Developers. https://docs.sumsub.com/docs/receive-verification-results

6. Sumsub. (2026). *Get started with Business Verification*. Sumsub Developers. https://docs.sumsub.com/docs/verify-businesses

7. Sumsub. (2026). *Applicant statuses*. Sumsub Developers. https://docs.sumsub.com/docs/applicant-statuses

8. Sumsub. (2026). *Webhook manager*. Sumsub Developers. https://docs.sumsub.com/docs/webhook-manager

9. Sumsub. (2026). *Customize links and notifications*. Sumsub Developers. https://docs.sumsub.com/docs/links-and-notifications

10. Sumsub. (2026). *Generate WebSDK verification links (Permalinks)*. Sumsub Developers. https://docs.sumsub.com/docs/generate-websdk-permalink

### Documentación Interna Retorna

11. Retorna. (2026). *Evaluación de Proveedor para KYB B2B (Sumsub)*. Notion. https://www.notion.so/appretorna/Evaluaci-n-de-Proveedor-para-KYB-B2B-Sumsub-2e28f1cca57e8094a2f6c9ceca5d351c

12. Retorna. (2026). *COR-130: Spike KYB Integration Architecture*. Jira. https://retorna-team.atlassian.net/browse/COR-130

### Evaluaciones Técnicas Relacionadas

13. Retorna. (2026). *COR-88: Evaluación Técnica Módulo 1 - KYC/KYB/UBO*. Notion. https://www.notion.so/appretorna/COR-88-Evaluacion-Tecnica-Modulo-1-KYC-KYB-UBO-3048f1cca57e8045974ad9d57e74e535

14. Retorna. (2026). *COR-95: Evaluación Técnica Módulo 2 - AML Screening/Risk Monitor*. Notion. https://www.notion.so/appretorna/COR-95-Evaluacion-Tecnica-Modulo-2-AML-Screening-Risk-Monitor-Proveedor-Sumsub-3048f1cca57e8134a4eaf54581b2968d

15. Retorna. (2026). *COR-96: Evaluación Técnica Módulo 3 - KYT/Transaction Monitoring*. Notion. https://www.notion.so/appretorna/COR-96-Evaluacion-Tecnica-Modulo-3-KYT-Transaction-Monitoring-Chainalysis-Proveedor-Sumsub-3068f1cca57e81f0a67cee6bc107b5c8

---

## Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RETORNA PLATFORM                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────────────────────┐   │
│  │   Portal    │     │  Backoffice │     │        Email Service        │   │
│  │    B2B      │     │   Interno   │     │                             │   │
│  └──────┬──────┘     └──────┬──────┘     └──────────────▲──────────────┘   │
│         │                   │                           │                   │
│         └─────────┬─────────┘                           │                   │
│                   │                                     │                   │
│                   ▼                                     │                   │
│  ┌─────────────────────────────────────────────────────┴─────────────────┐ │
│  │                          KYB API Service                               │ │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────┐  │ │
│  │  │   REST API    │  │    Worker     │  │      Cron Jobs            │  │ │
│  │  │   Endpoints   │  │   (Webhooks)  │  │  (Polling/Reconciliation) │  │ │
│  │  └───────┬───────┘  └───────┬───────┘  └────────────┬──────────────┘  │ │
│  │          │                  │                       │                  │ │
│  │          └──────────┬───────┴───────────────────────┘                  │ │
│  │                     │                                                  │ │
│  │                     ▼                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │ │
│  │  │                    KYB Provider Adapter                          │  │ │
│  │  │  ┌─────────────────┐          ┌─────────────────┐               │  │ │
│  │  │  │ SumsubProvider  │          │ FutureProvider  │               │  │ │
│  │  │  │   (Active)      │          │   (Placeholder) │               │  │ │
│  │  │  └────────┬────────┘          └─────────────────┘               │  │ │
│  │  └───────────┼─────────────────────────────────────────────────────┘  │ │
│  └──────────────┼────────────────────────────────────────────────────────┘ │
│                 │                                                           │
└─────────────────┼───────────────────────────────────────────────────────────┘
                  │
                  │ HTTPS (API + Webhooks)
                  │
                  ▼
         ┌─────────────────┐
         │     SUMSUB      │
         │   KYB Provider  │
         └─────────────────┘
```

---

## Flujo de Estados

```
                    ┌──────────────┐
                    │  NOT_STARTED │◄─────────────────────────┐
                    └──────┬───────┘                          │
                           │                                  │
                           │ Usuario inicia                   │
                           │ verificación                     │
                           ▼                                  │
                    ┌──────────────┐                          │
              ┌─────│ IN_PROGRESS  │                          │
              │     └──────┬───────┘                          │
              │            │                                  │
              │            │ Usuario completa                 │
              │            │ y envía                          │
              │            ▼                                  │
              │     ┌──────────────┐                          │
              │     │PENDING_REVIEW│                          │
              │     └──────┬───────┘                          │
              │            │                                  │
              │            ▼                                  │
              │     ┌──────────────┐                          │
              │     │  IN_REVIEW   │                          │
              │     └──────┬───────┘                          │
              │            │                                  │
              │     ┌──────┼───────┐                          │
              │     │      │       │                          │
    Link      │     ▼      ▼       ▼                          │ Regenerar
    expiró    │  ┌─────┐ ┌─────┐ ┌────────────────┐           │ link
              │  │GREEN│ │RED  │ │RED             │           │
              │  │     │ │FINAL│ │RETRY           │           │
              │  └──┬──┘ └──┬──┘ └───────┬────────┘           │
              │     │       │            │                    │
              │     ▼       ▼            ▼                    │
              │ ┌────────┐ ┌────────┐ ┌────────────────┐      │
              │ │APPROVED│ │REJECTED│ │ACTION_REQUIRED │──────┘
              │ └────────┘ └────────┘ └────────────────┘
              │
              ▼
        ┌──────────┐
        │ EXPIRED  │──────────────────────────────────────────┘
        └──────────┘
```

---

**Documento preparado para revisión por:**
- Equipo Backend
- Equipo Frontend
- Compliance
- Arquitectura

**Próximos pasos:**
1. Validar con equipo de Compliance los estados y reglas de negocio
2. Revisar con Frontend el contrato propuesto
3. Configurar sandbox de Sumsub para pruebas
4. Crear stories en backlog según checklist
