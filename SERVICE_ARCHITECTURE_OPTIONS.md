# Opciones de Arquitectura: Servicio de Compliance/Verificación

**Fecha:** 2026-02-23
**Contexto:** Definir estructura de servicio(s) para integrar verificación KYB/KYC/AML de forma provider-agnostic
**Relacionado:** [SPIKE_KYB_INTEGRATION_ARCHITECTURE.md](./SPIKE_KYB_INTEGRATION_ARCHITECTURE.md)

---

## Tabla de Contenidos

1. [Contexto](#1-contexto)
2. [Opción A: Servicio Unificado con Módulos](#2-opción-a-servicio-unificado-con-módulos)
3. [Opción B: Microservicios Separados](#3-opción-b-microservicios-separados)
4. [Comparativa](#4-comparativa)
5. [Recomendación](#5-recomendación)
6. [Nombres Sugeridos](#6-nombres-sugeridos)

---

## 1. Contexto

### Módulos de Compliance a Considerar

| Módulo | Descripción | Proveedor Actual/Futuro |
|--------|-------------|-------------------------|
| **KYB** | Verificación de empresas | Sumsub |
| **KYC** | Verificación de personas | MetaMap / Sumsub |
| **UBO** | Beneficiarios finales | Sumsub (dentro de KYB) |
| **AML Screening** | Listas OFAC/PEP/Sanciones | Ceptinel / Sumsub |
| **KYT** | Know Your Transaction (crypto) | Chainalysis / Sumsub |
| **TM** | Transaction Monitoring | Por definir |

### Preguntas Clave

- ¿Un servicio que maneje todo compliance o servicios separados por dominio?
- ¿Cómo escalar si un módulo crece más que otros?
- ¿Cómo manejar múltiples proveedores (Sumsub, Ceptinel, Chainalysis)?
- ¿Cómo facilitar el cambio de proveedor en el futuro?

---

## 2. Opción A: Servicio Unificado con Módulos

### Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                      COMPLIANCE SERVICE                          │
│                    (verification-service)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │     KYB     │  │     KYC     │  │     AML     │              │
│  │   Module    │  │   Module    │  │   Module    │              │
│  │             │  │             │  │  Screening  │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │     KYT     │  │     TM      │                               │
│  │   Module    │  │   Module    │                               │
│  │   (Crypto)  │  │ (Monitoring)│                               │
│  └──────┬──────┘  └──────┬──────┘                               │
│         │                │                                       │
│         └────────┬───────┴───────────────────────────────────┐  │
│                  │                                            │  │
│                  ▼                                            │  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                  PROVIDER ADAPTERS LAYER                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │  Sumsub  │  │ Ceptinel │  │Chainalysis│ │  Future  │   │  │
│  │  │ Adapter  │  │ Adapter  │  │  Adapter  │ │ Adapter  │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  Shared: Auth, Multi-tenant, Webhooks, Events, Audit            │
└─────────────────────────────────────────────────────────────────┘
```

### Estructura de Código

```
verification-service/
├── src/
│   ├── modules/
│   │   ├── kyb/
│   │   │   ├── kyb.controller.ts
│   │   │   ├── kyb.service.ts
│   │   │   ├── kyb.repository.ts
│   │   │   └── entities/
│   │   ├── kyc/
│   │   │   └── ...
│   │   ├── aml/
│   │   │   └── ...
│   │   └── kyt/
│   │       └── ...
│   ├── providers/
│   │   ├── interfaces/
│   │   │   ├── kyb-provider.interface.ts
│   │   │   ├── kyc-provider.interface.ts
│   │   │   └── aml-provider.interface.ts
│   │   ├── sumsub/
│   │   │   ├── sumsub.adapter.ts
│   │   │   ├── sumsub-kyb.provider.ts
│   │   │   └── sumsub-kyc.provider.ts
│   │   ├── ceptinel/
│   │   │   └── ceptinel-aml.provider.ts
│   │   └── chainalysis/
│   │       └── chainalysis-kyt.provider.ts
│   ├── webhooks/
│   │   ├── webhook.controller.ts
│   │   └── handlers/
│   ├── shared/
│   │   ├── auth/
│   │   ├── multi-tenant/
│   │   ├── events/
│   │   └── audit/
│   └── main.ts
├── test/
└── package.json
```

### Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Dominio cohesivo** | Todo es "compliance/verificación" - tiene sentido junto |
| **Código compartido** | Adapters, webhooks, eventos, audit en un solo lugar |
| **Transacciones simples** | KYB + AML en mismo request sin coordinación distribuida |
| **Menos infra** | Un solo deploy, una sola base de datos, menos complejidad |
| **Equipo pequeño** | Más manejable para equipos de 2-5 personas |
| **Provider switching** | Cambiar Sumsub por otro afecta solo el adapter |
| **Multi-tenant** | Una sola implementación de tenant isolation |

### Desventajas

| Desventaja | Descripción |
|------------|-------------|
| **Escala acoplada** | Si AML crece 10x, escala todo el servicio |
| **Blast radius** | Bug en KYT puede afectar KYB |
| **Ownership difuso** | Menos claro quién es dueño de qué módulo |
| **Deploy conjunto** | Cambio en AML requiere deploy de todo |
| **Complejidad creciente** | Puede volverse "monolito" difícil de mantener |

### Mitigaciones

```python
# Feature flags por módulo
KYB_ENABLED = True
KYC_ENABLED = False  # Activar cuando esté listo
AML_ENABLED = True
KYT_ENABLED = False

# Health checks independientes
/health/kyb  → OK
/health/kyc  → DISABLED
/health/aml  → OK

# Métricas separadas por módulo
verification_requests{module="kyb", provider="sumsub"}
verification_requests{module="aml", provider="ceptinel"}
```

---

## 3. Opción B: Microservicios Separados

### Arquitectura

```
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   VERIFICATION   │   │       AML        │   │       KYT        │
│     SERVICE      │   │     SERVICE      │   │     SERVICE      │
│    (KYB/KYC)     │   │   (Screening)    │   │    (Crypto)      │
├──────────────────┤   ├──────────────────┤   ├──────────────────┤
│ ┌──────────────┐ │   │ ┌──────────────┐ │   │ ┌──────────────┐ │
│ │  KYB Module  │ │   │ │   Screening  │ │   │ │  Transaction │ │
│ └──────────────┘ │   │ │    Module    │ │   │ │   Analysis   │ │
│ ┌──────────────┐ │   │ └──────────────┘ │   │ └──────────────┘ │
│ │  KYC Module  │ │   │ ┌──────────────┐ │   │ ┌──────────────┐ │
│ └──────────────┘ │   │ │  Monitoring  │ │   │ │    Wallet    │ │
│ ┌──────────────┐ │   │ │    Module    │ │   │ │   Scoring    │ │
│ │  UBO Module  │ │   │ └──────────────┘ │   │ └──────────────┘ │
│ └──────────────┘ │   │                  │   │                  │
├──────────────────┤   ├──────────────────┤   ├──────────────────┤
│ Sumsub Adapter   │   │ Ceptinel Adapter │   │Chainalysis Adapt │
│ MetaMap Adapter  │   │ Sumsub Adapter   │   │                  │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘
         │                      │                      │
         │                      │                      │
         ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                       MESSAGE BROKER                             │
│                    (RabbitMQ / SQS / Kafka)                      │
└─────────────────────────────────────────────────────────────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│   PostgreSQL     │   │   PostgreSQL     │   │   PostgreSQL     │
│   (verification) │   │      (aml)       │   │      (kyt)       │
└──────────────────┘   └──────────────────┘   └──────────────────┘
```

### Shared Library

```
@retorna/compliance-core/
├── src/
│   ├── interfaces/
│   │   ├── provider.interface.ts
│   │   └── webhook.interface.ts
│   ├── auth/
│   │   └── tenant.guard.ts
│   ├── events/
│   │   └── compliance.events.ts
│   └── utils/
│       ├── signature.ts
│       └── idempotency.ts
└── package.json
```

### Comunicación entre Servicios

```typescript
// verification-service necesita AML check
// Opción 1: Sync HTTP
const amlResult = await amlClient.screen({
  entityId: company.id,
  entityType: 'COMPANY',
  name: company.legalName,
  country: company.country
});

// Opción 2: Async Events
await eventBus.publish('verification.completed', {
  verificationId: verification.id,
  companyId: company.id,
  status: 'APPROVED'
});

// aml-service escucha y hace screening automático
@OnEvent('verification.completed')
async handleVerificationCompleted(event: VerificationCompletedEvent) {
  await this.screenEntity(event.companyId);
}
```

### Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Escala independiente** | AML puede escalar sin afectar KYB |
| **Deploy independiente** | Cambio en KYT no requiere deploy de KYB |
| **Ownership claro** | Equipo A → verification, Equipo B → AML |
| **Falla aislada** | Bug en KYT no tumba KYB |
| **Tech stack flexible** | KYT puede usar Go si es más performante |
| **Testing aislado** | Tests más rápidos por servicio |

### Desventajas

| Desventaja | Descripción |
|------------|-------------|
| **Complejidad operativa** | 3+ servicios, 3+ DBs, networking, etc. |
| **Consistencia eventual** | KYB aprobado pero AML pendiente = estado intermedio |
| **Duplicación de código** | Auth, logging, etc. en cada servicio |
| **Overhead comunicación** | Latencia HTTP/mensaje entre servicios |
| **Debugging complejo** | Tracing distribuido necesario |
| **Transacciones distribuidas** | Saga pattern si necesitas rollback |

### Complejidad Adicional Requerida

```yaml
# Infraestructura adicional necesaria
- Service discovery (Consul / K8s DNS)
- Load balancer por servicio
- Message broker (RabbitMQ / SQS)
- Distributed tracing (Jaeger / X-Ray)
- Centralized logging (ELK / CloudWatch)
- API Gateway (Kong / AWS API Gateway)
- Circuit breaker (Resilience4j / Hystrix)
```

---

## 4. Comparativa

### Matriz de Decisión

| Criterio | Peso | Opción A (Unificado) | Opción B (Microservicios) |
|----------|------|---------------------|---------------------------|
| **Complejidad inicial** | Alta | 5 (Simple) | 2 (Complejo) |
| **Complejidad operativa** | Alta | 5 (Baja) | 2 (Alta) |
| **Escalabilidad futura** | Media | 3 (Limitada) | 5 (Alta) |
| **Time to market** | Alta | 5 (Rápido) | 2 (Lento) |
| **Equipo pequeño (< 5)** | Alta | 5 (Ideal) | 2 (Difícil) |
| **Equipo grande (> 10)** | Baja | 2 (Difícil) | 5 (Ideal) |
| **Cambio de proveedor** | Media | 4 (Adapter) | 4 (Adapter) |
| **Aislamiento de fallas** | Media | 2 (Acoplado) | 5 (Aislado) |
| **Multi-tenant** | Alta | 5 (Una impl) | 3 (Múltiples) |
| **Costo infra** | Media | 5 (Bajo) | 2 (Alto) |
| **TOTAL** | - | **41** | **32** |

### Cuándo Elegir Cada Opción

#### Elegir Opción A (Unificado) si:

- Equipo < 5 personas
- Volumen < 10k verificaciones/día
- MVP o producto en etapa temprana
- Presupuesto de infra limitado
- Un solo proveedor principal (Sumsub)
- Time-to-market es prioridad

#### Elegir Opción B (Microservicios) si:

- Equipo > 10 personas con ownership separado
- Volumen > 100k verificaciones/día
- Módulos con requerimientos de escala muy diferentes
- Presupuesto de infra no es limitante
- Múltiples proveedores con integraciones complejas
- Ya existe infraestructura de microservicios madura

---

## 5. Recomendación

### Para Retorna: **Opción A (Servicio Unificado)**

| Factor | Estado Actual | Implicación |
|--------|---------------|-------------|
| Tamaño equipo | Pequeño (< 5) | Un servicio es más práctico |
| Volumen | Bajo (MVP) | No necesita escalar por módulo |
| Dominio | Cohesivo | Todo es verificación/compliance |
| Proveedor | Sumsub principal | Adapter compartido tiene sentido |
| Multi-tenant | Requerido | Una implementación es suficiente |
| MVP2 scope | Solo KYB | Empezar simple, crecer después |

### Roadmap de Evolución

```
Fase 1 (MVP2): verification-service con módulo KYB
    │
    ▼
Fase 2: Agregar módulo AML Screening (reemplazar Ceptinel)
    │
    ▼
Fase 3: Agregar módulo KYC (migrar de MetaMap si aplica)
    │
    ▼
Fase 4: Agregar módulo KYT (si hay producto crypto)
    │
    ▼
Fase 5 (si necesario): Extraer microservicio de módulo que más escale
```

### Señales para Migrar a Microservicios

Considerar migración cuando:

- [ ] Equipo crece a > 10 personas
- [ ] Un módulo tiene 10x más carga que otros
- [ ] Deploys frecuentes de un módulo bloquean otros
- [ ] Tiempos de build/test superan 15 minutos
- [ ] Fallas en un módulo afectan SLA de otros
- [ ] Necesidad de tech stack diferente por módulo

---

## 6. Nombres Sugeridos

### Para Servicio Unificado

| Nombre | Pros | Contras | Recomendación |
|--------|------|---------|---------------|
| `verification-service` | Claro, enfocado en verificación | No cubre TM/monitoring | **Recomendado** |
| `compliance-service` | Cubre todo el dominio | Muy genérico | Alternativa |
| `identity-service` | Si incluye identidad | Puede confundir con auth | No recomendado |
| `kyb-service` | Específico | Limitante si crece | No recomendado |
| `onboarding-service` | Enfocado en flujo | Puede confundir con otros onboardings | No recomendado |
| `trust-service` | Moderno, único | Poco descriptivo | Alternativa |

### Decisión Sugerida

```
verification-service
```

**Justificación:**
- Descriptivo: "verificación" es el core del servicio
- Extensible: KYB, KYC, UBO, AML son tipos de verificación
- No limita: Si crece a TM, se puede renombrar o extraer
- Convención: Sigue patrón `{dominio}-service`

### Nomenclatura Completa

```
Servicio:     verification-service
Base de datos: verification_db
Schemas:      kyb, kyc, aml, kyt (por módulo)
API prefix:   /api/v1/verifications/...
Events:       verification.kyb.created, verification.aml.completed
Metrics:      verification_requests_total{module="kyb"}
Logs:         verification-service.kyb.create
```

---

## Anexo: Estructura de Proyecto Recomendada

```
verification-service/
├── src/
│   ├── app.module.ts
│   ├── main.ts
│   │
│   ├── modules/
│   │   ├── kyb/
│   │   │   ├── kyb.module.ts
│   │   │   ├── kyb.controller.ts
│   │   │   ├── kyb.service.ts
│   │   │   ├── kyb.repository.ts
│   │   │   ├── dto/
│   │   │   │   ├── create-verification.dto.ts
│   │   │   │   └── verification-response.dto.ts
│   │   │   ├── entities/
│   │   │   │   ├── kyb-verification.entity.ts
│   │   │   │   ├── kyb-verification-event.entity.ts
│   │   │   │   └── kyb-ubo.entity.ts
│   │   │   └── events/
│   │   │       └── kyb.events.ts
│   │   │
│   │   ├── aml/                    # Fase 2
│   │   │   └── ...
│   │   │
│   │   └── kyc/                    # Fase 3
│   │       └── ...
│   │
│   ├── providers/
│   │   ├── provider.module.ts
│   │   ├── interfaces/
│   │   │   ├── kyb-provider.interface.ts
│   │   │   └── aml-provider.interface.ts
│   │   ├── sumsub/
│   │   │   ├── sumsub.module.ts
│   │   │   ├── sumsub.client.ts
│   │   │   ├── sumsub-kyb.provider.ts
│   │   │   └── sumsub.mapper.ts
│   │   └── ceptinel/               # Fase 2
│   │       └── ...
│   │
│   ├── webhooks/
│   │   ├── webhook.module.ts
│   │   ├── webhook.controller.ts
│   │   └── handlers/
│   │       ├── sumsub.handler.ts
│   │       └── ceptinel.handler.ts
│   │
│   ├── shared/
│   │   ├── auth/
│   │   │   └── tenant.guard.ts
│   │   ├── database/
│   │   │   └── migrations/
│   │   ├── events/
│   │   │   └── event.service.ts
│   │   └── audit/
│   │       └── audit.interceptor.ts
│   │
│   └── config/
│       ├── database.config.ts
│       ├── sumsub.config.ts
│       └── app.config.ts
│
├── test/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
├── docker-compose.yml
├── Dockerfile
├── package.json
└── README.md
```

---

**Documento preparado para discusión con:**
- Equipo Backend
- Arquitectura
- DevOps/SRE
