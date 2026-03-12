# Spike: Comportamiento de Links de Verificación (Sumsub)

**Fecha:** 2026-02-24
**Autor:** Core Reporting / Backend
**Status:** Draft para revisión
**HU Relacionada:** Spike KYB Integration - Sección D (Comportamiento del link)

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Tipos de Links en Sumsub](#2-tipos-de-links-en-sumsub)
3. [Tiempos de Expiración](#3-tiempos-de-expiración)
4. [Comportamiento del Link: Reanudación y Expiración](#4-comportamiento-del-link-reanudación-y-expiración)
5. [Errores Esperados y Respuestas Técnicas](#5-errores-esperados-y-respuestas-técnicas)
6. [Anti-duplicación y Regeneración](#6-anti-duplicación-y-regeneración)
7. [Comparativa: Usuario Específico vs Batch](#7-comparativa-usuario-específico-vs-batch)
8. [Decisión para Retorna](#8-decisión-para-retorna)
9. [Casos de Prueba Validados](#9-casos-de-prueba-validados)
10. [Referencias](#10-referencias)

---

## 1. Resumen Ejecutivo

### Objetivo

Documentar el comportamiento de los links de verificación de Sumsub para:
- Entender reanudación vs reinicio de verificaciones
- Conocer tiempos de expiración y límites
- Mapear errores técnicos esperados
- Definir reglas de regeneración y anti-duplicación

### Decisiones Clave

| Aspecto | Decisión |
|---------|----------|
| Tipo de link | **Usuario específico** (External User ID) via API |
| TTL recomendado | 24-48 horas (configurable hasta 30 días) |
| Reanudación | ✅ Sí, el progreso se guarda mientras el link sea válido |
| Regeneración | Permitida si link expiró o estado es `ACTION_REQUIRED` |
| Anti-duplicación | 1 verificación activa por `externalCompanyId` |

---

## 2. Tipos de Links en Sumsub

Sumsub ofrece diferentes mecanismos para iniciar verificaciones. Es crítico entender las diferencias.

### 2.1 Tabla Comparativa General

| Tipo | Descripción | Vinculación | Reutilizable | Caso de Uso |
|------|-------------|-------------|--------------|-------------|
| **Unilink** | Link universal por nivel | Por email | ✅ Múltiples usuarios | Landing pages, QR |
| **Permalink - Usuario específico** | Link único por `externalUserId` | Por ID externo | ❌ Un solo uso | ✅ **B2B conocido** |
| **Permalink - Batch** | Conjunto de links independientes | Ninguna | ❌ Un solo uso cada uno | Campañas masivas |
| **Access Token** | Token para SDK embebido | Por `applicantId` | ❌ Un solo uso | SDK (MVP3) |

### 2.2 Opciones en Dashboard de Sumsub

```
Dashboard → Integrations → [Nivel] → WebSDK permalinks

┌─────────────────────────────────────────────────────────────────┐
│  Generar enlace permanente                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ○ Usuario específico                                           │
│    Enlace permanente basado en la id. de usuario externo.       │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ Idioma:              [Español ▼]                        │  │
│    │ Id. de usuario ext.: [company-123___________]           │  │
│    │ Validez del enlace:  [30 días ▼]                        │  │
│    │                                                         │  │
│    │ ⚠️ Ha seleccionado un período de validez prolongado...  │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ○ Usuarios externos                                            │
│    Conjunto de enlaces permanentes independientes.              │
│    ┌─────────────────────────────────────────────────────────┐  │
│    │ Idioma:              [Español ▼]                        │  │
│    │ Validez del enlace:  [30 días ▼]                        │  │
│    │ Recuento de enlaces: [10_______]                        │  │
│    └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Tiempos de Expiración

### 3.1 Matriz de Tiempos por Tipo de Link

| Tipo de Link | TTL por Defecto | TTL Máximo | TTL Configurable | Sesión Activa |
|--------------|-----------------|------------|------------------|---------------|
| **Unilink** | Ilimitado (mientras exista el nivel) | N/A | ❌ No | 30 min |
| **Permalink (Dashboard)** | 7 días | **30 días** | ✅ Sí (dropdown) | 30 min |
| **Permalink (API)** | 7200 seg (2h) | **2,592,000 seg (30 días)** | ✅ Sí (`ttlInSecs`) | 30 min |
| **Access Token** | 1800 seg (30 min) | Configurable | ✅ Sí (`ttlInSecs`) | Según token |

### 3.2 Diferencia: TTL del Link vs Sesión Activa

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TIEMPO DE VIDA DEL LINK                       │
│                         (TTL: hasta 30 días)                         │
│                                                                      │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐         │
│  │ Sesión 1 │   │ Sesión 2 │   │ Sesión 3 │   │ Sesión N │   ...   │
│  │  30 min  │   │  30 min  │   │  30 min  │   │  30 min  │         │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘         │
│       ↓              ↓              ↓              ↓                │
│   Progreso       Progreso       Progreso       Completa             │
│   guardado       guardado       guardado       verificación         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

| Concepto | Descripción | Duración |
|----------|-------------|----------|
| **TTL del Link** | Tiempo total para acceder al link | Configurable: 30 min - 30 días |
| **Sesión Activa** | Tiempo de inactividad antes de expirar sesión | **30 minutos** (fijo) |
| **Progreso** | Datos ingresados en formularios | Guardado en browser session storage |

### 3.3 Opciones de TTL en Dashboard

| Opción | Segundos | Caso de Uso |
|--------|----------|-------------|
| 30 minutos | 1,800 | Verificación inmediata, alta urgencia |
| 1 hora | 3,600 | Sesión única esperada |
| 4 horas | 14,400 | Verificación el mismo día |
| 24 horas | 86,400 | Email con link (recomendado) |
| 48 horas | 172,800 | Con reminder automático |
| 7 días | 604,800 | Default, balance seguridad/UX |
| 30 días | 2,592,000 | ⚠️ Máximo, alto riesgo |

### 3.4 Advertencia de Seguridad (Sumsub)

> **"Ha seleccionado un período de validez prolongado para el enlace permanente, lo que aumenta el riesgo de acceso no autorizado. Asegúrese de que este período extendido sea necesario."**

**Riesgos de TTL largo (>7 días):**

| Riesgo | Descripción | Mitigación |
|--------|-------------|------------|
| **Link forwarding** | Usuario reenvía link a tercero | TTL corto + logging de IP/device |
| **Acceso no autorizado** | Link interceptado o filtrado | HTTPS + TTL mínimo necesario |
| **Auditoría difícil** | Ventana larga = más variables | Reminders + alertas de expiración |
| **Suplantación** | Tercero completa verificación | Device fingerprint (Sumsub lo hace) |

---

## 4. Comportamiento del Link: Reanudación y Expiración

### 4.1 Escenarios de Reanudación

| # | Escenario | Resultado | Progreso |
|---|-----------|-----------|----------|
| 1 | Usuario abandona, vuelve con link válido (mismo dispositivo) | ✅ **Retoma donde dejó** | Guardado en session storage |
| 2 | Usuario abandona, vuelve con link válido (otro dispositivo) | ⚠️ **Retoma parcialmente** | Solo datos enviados a Sumsub |
| 3 | Usuario abandona, link expiró | ❌ **No puede acceder** | Perdido si no envió |
| 4 | Usuario completa, intenta usar link otra vez | ℹ️ **Ve "ya completado"** | N/A |
| 5 | Sesión expira (30 min inactivo), link aún válido | ⚠️ **Repite email verification** | Formularios se pierden |

### 4.2 Diagrama de Flujo: Reanudación

```
                    Usuario accede al link
                            │
                            ▼
                    ┌───────────────┐
                    │ ¿Link válido? │
                    └───────┬───────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
        ┌─────────┐                 ┌─────────┐
        │   Sí    │                 │   No    │
        └────┬────┘                 └────┬────┘
             │                           │
             ▼                           ▼
    ┌─────────────────┐         ┌─────────────────┐
    │ ¿Verificación   │         │ Error: Link     │
    │  completada?    │         │ expirado/inválido│
    └────────┬────────┘         └─────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌───────┐        ┌────────┐
│  Sí   │        │   No   │
└───┬───┘        └────┬───┘
    │                 │
    ▼                 ▼
┌─────────────┐  ┌─────────────────┐
│ Mensaje:    │  │ ¿Mismo          │
│ "Completado"│  │ dispositivo?    │
└─────────────┘  └────────┬────────┘
                          │
                ┌─────────┴─────────┐
                │                   │
                ▼                   ▼
          ┌─────────┐         ┌─────────┐
          │   Sí    │         │   No    │
          └────┬────┘         └────┬────┘
               │                   │
               ▼                   ▼
    ┌──────────────────┐  ┌──────────────────┐
    │ Retoma con       │  │ Retoma solo con  │
    │ progreso local   │  │ datos ya enviados│
    │ (session storage)│  │ a Sumsub         │
    └──────────────────┘  └──────────────────┘
```

### 4.3 ¿Qué Datos se Guardan?

| Tipo de Dato | ¿Dónde se guarda? | ¿Persiste entre sesiones? | ¿Persiste entre dispositivos? |
|--------------|-------------------|---------------------------|-------------------------------|
| Formularios (Questionnaire) | Browser session storage | ❌ No (30 min) | ❌ No |
| Datos del applicant | Servidor Sumsub | ✅ Sí | ✅ Sí |
| Documentos subidos | Servidor Sumsub | ✅ Sí | ✅ Sí |
| Estado de verificación | Servidor Sumsub | ✅ Sí | ✅ Sí |

### 4.4 Ejemplo Práctico: Timeline

```
Día 1 (1 marzo, 10:00)
    └── Generas link con TTL=7 días (expira 8 marzo, 10:00)

Día 1 (1 marzo, 14:00)
    └── Usuario abre link, completa paso 1 de 3, abandona
        └── Datos paso 1: guardados en Sumsub ✅
        └── Formulario paso 2: en session storage (30 min)

Día 1 (1 marzo, 14:45) - 45 min después
    └── Usuario vuelve en MISMO dispositivo
        └── Sesión expiró (>30 min), pero link válido
        └── Repite verificación de email
        └── Paso 1 ya está completado ✅
        └── Formulario paso 2 perdido (session storage expiró) ❌

Día 3 (3 marzo, 09:00)
    └── Usuario vuelve desde OTRO dispositivo
        └── Link válido ✅
        └── Paso 1 ya completado ✅
        └── Continúa desde paso 2

Día 10 (10 marzo, 11:00)
    └── Usuario intenta acceder
        └── Link expiró (8 marzo) ❌
        └── Error: link inválido
        └── Necesita nuevo link
```

---

## 5. Errores Esperados y Respuestas Técnicas

### 5.1 Códigos de Error Sumsub

| Código | Nombre | Descripción | Cuándo Ocurre |
|--------|--------|-------------|---------------|
| 401 | `Unauthorized` | Token inválido o expirado | Link/token expirado |
| 400 | `Bad Request` | Datos inválidos | Parámetros incorrectos |
| 404 | `Not Found` | Recurso no existe | Applicant no existe |
| 409 | `Conflict` | Conflicto de estado | Applicant ya verificado |
| 9100 | `invalid-data` | Datos inválidos proporcionados | Validación fallida |
| 9101 | `method-not-allowed` | Método no permitido | Verificación bloqueada |
| 9105 | `max-attempts` | Máximo de intentos excedido | Demasiados reintentos |

### 5.2 Errores Específicos de Links

| Escenario | HTTP Status | Error Body | Acción Recomendada |
|-----------|-------------|------------|-------------------|
| **Link expirado** | 401 | `{"errorCode": 401, "description": "token-invalid"}` | Regenerar link |
| **Link ya usado (completado)** | 200 | Muestra pantalla "completado" | Informar al usuario |
| **Link inválido/malformado** | 400 | `{"errorCode": 400, "description": "invalid-token"}` | Verificar URL |
| **Applicant no existe** | 404 | `{"errorCode": 404, "description": "applicant-not-found"}` | Crear nuevo applicant |
| **Nivel no existe** | 400 | `{"errorCode": 400, "description": "level-not-found"}` | Verificar configuración |

### 5.3 Respuesta de Link Expirado (WebSDK)

Cuando un usuario accede a un link expirado, el WebSDK muestra:

```json
{
  "errorCode": 4001,
  "errorName": "token-invalid",
  "description": "Access token is invalid or expired"
}
```

**Comportamiento visual:**
- El SDK muestra una pantalla de error
- No hay opción de "reintentar" desde el SDK
- El usuario debe obtener un nuevo link

### 5.4 Mapping de Errores → Acciones en Retorna

```python
ERROR_HANDLERS = {
    # Link/Token expirado
    "token-invalid": {
        "internal_status": "EXPIRED",
        "user_message": "Tu enlace ha expirado. Solicita uno nuevo.",
        "action": "REGENERATE_LINK",
        "notify_user": True
    },

    # Ya completado
    "already-verified": {
        "internal_status": "APPROVED",  # o el estado actual
        "user_message": "Tu verificación ya fue completada.",
        "action": "SHOW_STATUS",
        "notify_user": False
    },

    # Máximo de intentos
    "max-attempts-exceeded": {
        "internal_status": "REJECTED",
        "user_message": "Has excedido el número máximo de intentos.",
        "action": "CONTACT_SUPPORT",
        "notify_user": True
    },

    # Datos inválidos
    "invalid-data": {
        "internal_status": "ACTION_REQUIRED",
        "user_message": "Por favor verifica la información ingresada.",
        "action": "RETRY_STEP",
        "notify_user": True
    }
}
```

---

## 6. Anti-duplicación y Regeneración

### 6.1 Regla Principal

```
┌─────────────────────────────────────────────────────────────────┐
│  1 verificación activa por externalCompanyId + tenantId         │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Estados que Bloquean Nueva Verificación

| Estado | ¿Bloquea? | Razón |
|--------|-----------|-------|
| `NOT_STARTED` (link válido) | ✅ Sí | Verificación pendiente |
| `NOT_STARTED` (link expirado) | ❌ No | Puede regenerar |
| `IN_PROGRESS` | ✅ Sí | Usuario activamente verificando |
| `PENDING_REVIEW` | ✅ Sí | Esperando revisión |
| `IN_REVIEW` | ✅ Sí | En revisión manual |
| `ACTION_REQUIRED` | ⚠️ Parcial | Puede regenerar link, no nueva verificación |
| `APPROVED` | ✅ Sí | Ya verificado |
| `REJECTED` | ❌ No | Puede iniciar nueva (según política) |
| `EXPIRED` | ❌ No | Puede regenerar o nueva |
| `CANCELED` | ❌ No | Puede iniciar nueva |

### 6.3 Algoritmo de Decisión

```python
def handle_verification_request(company_id: str, tenant_id: str) -> Result:
    """
    Decide si crear nueva verificación, regenerar link, o bloquear.
    """
    # 1. Buscar verificación existente
    existing = find_verification(company_id, tenant_id)

    if not existing:
        # No hay verificación → Crear nueva
        return create_new_verification(company_id, tenant_id)

    # 2. Evaluar estado actual
    match existing.status:

        case "APPROVED":
            # Ya verificado → Bloquear
            raise CompanyAlreadyVerifiedError(existing.id)

        case "NOT_STARTED" | "IN_PROGRESS" | "ACTION_REQUIRED":
            if existing.link_is_valid():
                # Link válido → Reusar
                return existing
            else:
                # Link expirado → Regenerar
                return regenerate_link(existing)

        case "PENDING_REVIEW" | "IN_REVIEW":
            # En proceso → Bloquear
            raise VerificationInProgressError(existing.id)

        case "REJECTED":
            # Rechazado → Según política
            if policy.allow_retry_after_rejection:
                return create_new_verification(company_id, tenant_id)
            else:
                raise VerificationRejectedError(existing.id)

        case "EXPIRED" | "CANCELED":
            # Inactivo → Crear nueva
            return create_new_verification(company_id, tenant_id)
```

### 6.4 Regeneración de Link

**¿Cuándo se puede regenerar?**

| Condición | ¿Permitido? | Resultado |
|-----------|-------------|-----------|
| Link expiró, verificación no completada | ✅ Sí | Nuevo link, mismo applicant |
| Estado `ACTION_REQUIRED` | ✅ Sí | Nuevo link para corregir |
| Estado `NOT_STARTED`, link válido | ⚠️ Opcional | Invalidar anterior, generar nuevo |
| Estado `APPROVED` | ❌ No | Ya completado |
| Estado `IN_REVIEW` | ❌ No | Esperando resultado |

**Implementación:**

```python
async def regenerate_link(verification_id: str) -> dict:
    """
    Regenera el link para una verificación existente.
    """
    verification = await get_verification(verification_id)

    # Validar que se puede regenerar
    if not can_regenerate(verification):
        raise CannotRegenerateLinkError(
            f"No se puede regenerar en estado {verification.status}"
        )

    # Generar nuevo link para el mismo applicant
    new_link = await sumsub_client.generate_link(
        applicant_id=verification.provider_applicant_id,
        level_name=verification.level_name,
        ttl_seconds=86400  # 24 horas
    )

    # Actualizar verificación
    verification.verification_link = new_link["url"]
    verification.link_expires_at = calculate_expiration(86400)

    if verification.status == "EXPIRED":
        verification.status = "NOT_STARTED"

    await save_verification(verification)

    return {
        "id": verification.id,
        "verification_link": new_link["url"],
        "link_expires_at": verification.link_expires_at
    }

def can_regenerate(verification) -> bool:
    """Determina si se puede regenerar el link."""

    # Estados que permiten regeneración
    if verification.status in ["EXPIRED", "ACTION_REQUIRED"]:
        return True

    # NOT_STARTED con link expirado
    if verification.status == "NOT_STARTED" and verification.link_expired():
        return True

    # IN_PROGRESS con link expirado (usuario abandonó)
    if verification.status == "IN_PROGRESS" and verification.link_expired():
        return True

    return False
```

### 6.5 Tabla de Decisión: Nueva Verificación vs Regenerar vs Reusar

| Estado Actual | Link | Acción | Resultado |
|---------------|------|--------|-----------|
| `NOT_STARTED` | Válido | **Reusar** | Retorna link existente |
| `NOT_STARTED` | Expirado | **Regenerar** | Nuevo link, mismo applicant |
| `IN_PROGRESS` | Válido | **Reusar** | Retorna link existente |
| `IN_PROGRESS` | Expirado | **Regenerar** | Nuevo link, mismo applicant |
| `ACTION_REQUIRED` | Válido | **Reusar** | Retorna link existente |
| `ACTION_REQUIRED` | Expirado | **Regenerar** | Nuevo link, mismo applicant |
| `PENDING_REVIEW` | - | **Bloquear** | Error: en revisión |
| `IN_REVIEW` | - | **Bloquear** | Error: en revisión |
| `APPROVED` | - | **Bloquear** | Error: ya verificado |
| `REJECTED` | - | **Nueva** (si política permite) | Nueva verificación |
| `EXPIRED` | - | **Nueva o Regenerar** | Según preferencia |
| `CANCELED` | - | **Nueva** | Nueva verificación |
| (No existe) | - | **Nueva** | Crear verificación |

---

## 7. Comparativa: Usuario Específico vs Batch

### 7.1 Usuario Específico (External User ID)

**Descripción:** Un link vinculado a un `externalUserId` específico (tu ID de empresa).

```
┌─────────────────────────────────────────────────────────────────┐
│  POST /resources/sdkIntegrations/levels/-/websdkLink            │
│                                                                 │
│  {                                                              │
│    "levelName": "kyb-latam-colombia",                          │
│    "userId": "emp-co-001",        ← Tu externalCompanyId       │
│    "ttlInSecs": 86400,                                          │
│    "lang": "es"                                                 │
│  }                                                              │
│                                                                 │
│  Response: { "url": "https://in.sumsub.com/websdk/p/abc123" }  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Webhook recibido:                                              │
│  {                                                              │
│    "applicantId": "sumsub-internal-id",                        │
│    "externalUserId": "emp-co-001",  ← Correlación directa      │
│    "type": "applicantReviewed",                                │
│    "reviewResult": { "reviewAnswer": "GREEN" }                 │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

**Ventajas:**
- ✅ Trazabilidad directa: `externalUserId` = tu ID interno
- ✅ Correlación automática de webhooks
- ✅ Imposible que otra empresa use el link
- ✅ Automatizable via API
- ✅ Nivel de verificación por país

**Desventajas:**
- ❌ Requiere una llamada API por empresa
- ❌ Más código inicial (pero automatizado)

### 7.2 Usuarios Externos (Batch)

**Descripción:** Conjunto de links independientes sin vincular a ningún usuario.

```
┌─────────────────────────────────────────────────────────────────┐
│  Dashboard: Generar 5 links batch                               │
│                                                                 │
│  Resultado:                                                     │
│  - Link #1: https://in.sumsub.com/websdk/p/xyz1                │
│  - Link #2: https://in.sumsub.com/websdk/p/xyz2                │
│  - Link #3: https://in.sumsub.com/websdk/p/xyz3                │
│  - Link #4: https://in.sumsub.com/websdk/p/xyz4                │
│  - Link #5: https://in.sumsub.com/websdk/p/xyz5                │
│                                                                 │
│  ⚠️ Ninguno tiene externalUserId asignado                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Problema: ¿Cómo correlacionar?                                 │
│                                                                 │
│  Webhook: { "applicantId": "xxx", "externalUserId": null }     │
│                                                                 │
│  → Necesitas mapear manualmente qué link enviaste a quién      │
└─────────────────────────────────────────────────────────────────┘
```

**Ventajas:**
- ✅ Generación rápida de múltiples links
- ✅ Útil para campañas masivas

**Desventajas:**
- ❌ Sin `externalUserId` pre-definido
- ❌ No automatizable via API
- ❌ Links intercambiables (riesgo)
- ❌ Correlación manual requerida

### 7.3 Matriz de Decisión

| Criterio | Peso | Usuario Específico | Batch |
|----------|------|-------------------|-------|
| Trazabilidad | Alta | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Correlación automática | Alta | ⭐⭐⭐⭐⭐ | ⭐ |
| Automatización (API) | Alta | ⭐⭐⭐⭐⭐ | ⭐ |
| Control por empresa | Alta | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| Generación masiva simple | Media | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Seguridad | Alta | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **TOTAL** | | **28/30** | **14/30** |

---

## 8. Decisión para Retorna

### 8.1 Elección: Usuario Específico (External User ID) via API

| Aspecto | Decisión | Justificación |
|---------|----------|---------------|
| **Tipo de link** | Usuario específico | Trazabilidad y correlación automática |
| **Generación** | Via API | Automatización completa |
| **Vinculación** | `userId` = `externalCompanyId` | Mapeo directo con entidad interna |
| **TTL default** | 24-48 horas | Balance seguridad/UX |
| **TTL máximo** | 7 días | Evitar riesgos de TTL largo |
| **Nivel por país** | Configurable | `kyb-latam-{país}` |

### 8.2 Configuración Recomendada

```python
# config/kyb_links.py

LINK_CONFIG = {
    # TTL por tipo de envío
    "ttl": {
        "email_initial": 86400,      # 24 horas
        "email_reminder": 172800,    # 48 horas
        "urgent": 14400,             # 4 horas
        "max_allowed": 604800,       # 7 días (límite interno)
    },

    # Niveles por país
    "levels": {
        "CO": "kyb-latam-colombia",
        "MX": "kyb-latam-mexico",
        "BR": "kyb-latam-brazil",
        "CL": "kyb-latam-chile",
        "DEFAULT": "kyb-latam-generic",
    },

    # Idiomas por país
    "languages": {
        "CO": "es", "MX": "es", "CL": "es",
        "BR": "pt",
        "DEFAULT": "en",
    },

    # Políticas
    "policies": {
        "allow_retry_after_rejection": True,
        "retry_cooldown_days": 30,
        "max_active_verifications_per_company": 1,
    }
}
```

### 8.3 Flujo Completo

```
┌─────────────────────────────────────────────────────────────────────┐
│                          PORTAL B2B                                  │
│                                                                      │
│  Tenant: "Cliente ABC"                                              │
│  Empresas a verificar:                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ emp-co-001   │  │ emp-mx-001   │  │ emp-br-001   │              │
│  │ Colombia     │  │ México       │  │ Brasil       │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
└─────────┼──────────────────┼──────────────────┼─────────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       KYB SERVICE (Retorna)                          │
│                                                                      │
│  Para cada empresa:                                                 │
│  1. Validar no existe verificación activa                           │
│  2. POST /websdkLink con userId = externalCompanyId                 │
│  3. Guardar verification con link y TTL                             │
│  4. Enviar email con link                                           │
└─────────────────────────────────────────────────────────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                           SUMSUB                                     │
│                                                                      │
│  Applicants creados:                                                │
│  - externalUserId: "emp-co-001" → Level: kyb-latam-colombia        │
│  - externalUserId: "emp-mx-001" → Level: kyb-latam-mexico          │
│  - externalUserId: "emp-br-001" → Level: kyb-latam-brazil          │
└─────────────────────────────────────────────────────────────────────┘
          │                  │                  │
          │      Webhooks con externalUserId   │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       KYB SERVICE (Retorna)                          │
│                                                                      │
│  Actualizar estado por externalCompanyId (correlación directa)      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Casos de Prueba Validados

### 9.1 Checklist de Validación

| # | Caso de Prueba | Resultado Esperado | Validado |
|---|----------------|-------------------|----------|
| 1 | Usuario abre link válido por primera vez | Inicia verificación | ⬜ Pendiente |
| 2 | Usuario abandona, vuelve con link válido (mismo device) | Retoma con progreso local | ⬜ Pendiente |
| 3 | Usuario abandona, vuelve con link válido (otro device) | Retoma sin progreso local | ⬜ Pendiente |
| 4 | Usuario intenta acceder con link expirado | Error: link inválido | ⬜ Pendiente |
| 5 | Usuario completa, intenta usar link otra vez | Mensaje: ya completado | ⬜ Pendiente |
| 6 | Sesión expira (30 min), link válido | Repite email verification | ⬜ Pendiente |
| 7 | Regenerar link para verificación expirada | Nuevo link funcional | ⬜ Pendiente |
| 8 | Intentar crear verificación duplicada | Error: ya existe activa | ⬜ Pendiente |
| 9 | Link de empresa A usado por empresa B | N/A (link vinculado) | ⬜ Pendiente |
| 10 | Webhook llega con externalUserId | Correlación exitosa | ⬜ Pendiente |

### 9.2 Pruebas en Sandbox

```bash
# 1. Generar link de prueba
curl -X POST "https://api.sumsub.com/resources/sdkIntegrations/levels/-/websdkLink" \
  -H "Content-Type: application/json" \
  -H "X-App-Token: $SUMSUB_TOKEN" \
  -d '{
    "levelName": "kyb-test",
    "userId": "test-company-001",
    "ttlInSecs": 3600,
    "lang": "es"
  }'

# 2. Verificar applicant creado
curl "https://api.sumsub.com/resources/applicants/-;externalUserId=test-company-001" \
  -H "X-App-Token: $SUMSUB_TOKEN"

# 3. Simular expiración (esperar TTL o usar token corto)
# 4. Validar error de link expirado
```

---

## 10. Referencias

### Documentación Oficial Sumsub

1. Sumsub. (2026). *Verification links*. https://docs.sumsub.com/docs/verification-links

2. Sumsub. (2026). *Generate WebSDK permalink*. https://docs.sumsub.com/docs/generate-websdk-permalink

3. Sumsub. (2026). *Generate external WebSDK link (API)*. https://docs.sumsub.com/reference/generate-websdk-external-link

4. Sumsub. (2026). *Token expiration handler*. https://docs.sumsub.com/docs/token-expiration-handler

5. Sumsub. (2026). *Error codes*. https://docs.sumsub.com/reference/error-codes

6. Sumsub. (2026). *Configure verification levels*. https://docs.sumsub.com/docs/configure-verification-levels

### Documentación Interna Retorna

7. [SPIKE_KYB_INTEGRATION_ARCHITECTURE.md](./SPIKE_KYB_INTEGRATION_ARCHITECTURE.md) - Arquitectura completa de integración

8. [MULTI_COMPANY_LINK_GENERATION.md](./MULTI_COMPANY_LINK_GENERATION.md) - Generación multi-empresa

9. [SERVICE_ARCHITECTURE_OPTIONS.md](./SERVICE_ARCHITECTURE_OPTIONS.md) - Opciones de arquitectura

---

## Historial de Cambios

| Fecha | Versión | Cambios |
|-------|---------|---------|
| 2026-02-24 | 1.0 | Documento inicial |

---

**Documento preparado para revisión por:**
- Equipo Backend
- Producto
- Compliance
- QA (validación de casos de prueba)
