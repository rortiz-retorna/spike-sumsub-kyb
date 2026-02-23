# Generación de Links para Múltiples Empresas

**Fecha:** 2026-02-23
**Relacionado a:** SPIKE_KYB_INTEGRATION_ARCHITECTURE.md
**Caso de uso:** Un tenant (cliente B2B) necesita verificar múltiples empresas en diferentes países

---

## Escenario

Un cliente B2B de Retorna necesita verificar:
- 2 empresas en Colombia
- 1 empresa en México
- 1 empresa en Brasil

---

## Opciones de Implementación

### Opción 1: Un Permalink por Empresa (RECOMENDADO)

Generar un link único e independiente para cada empresa.

```
┌─────────────────────────────────────────────────────────────────┐
│                    TENANT: "Cliente ABC"                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐│
│  │ Empresa CO-1│  │ Empresa CO-2│  │ Empresa MX-1│  │ Emp BR-1││
│  │ Link #1     │  │ Link #2     │  │ Link #3     │  │ Link #4 ││
│  │ Level: kyb-co│ │ Level: kyb-co│ │ Level: kyb-mx│ │Level:kyb-br│
│  │ Lang: es    │  │ Lang: es    │  │ Lang: es    │  │ Lang: pt ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Implementación

```python
import asyncio
from dataclasses import dataclass
from typing import List

@dataclass
class CompanyToVerify:
    external_company_id: str
    country: str
    email: str
    legal_name: str

class MultiCompanyLinkGenerator:
    """
    Generador de permalinks para múltiples empresas de un mismo tenant.
    """

    # Mapeo de país a nivel de verificación en Sumsub
    LEVEL_BY_COUNTRY = {
        "CO": "kyb-latam-colombia",
        "MX": "kyb-latam-mexico",
        "BR": "kyb-latam-brazil",
        "CL": "kyb-latam-chile",
        "PE": "kyb-latam-peru",
        "AR": "kyb-latam-argentina",
        # Default para países sin nivel específico
        "DEFAULT": "kyb-latam-generic"
    }

    # Mapeo de país a idioma
    LANG_BY_COUNTRY = {
        "CO": "es",
        "MX": "es",
        "CL": "es",
        "PE": "es",
        "AR": "es",
        "BR": "pt",
        "DEFAULT": "en"
    }

    def __init__(self, sumsub_client, config):
        self.sumsub_client = sumsub_client
        self.config = config

    def get_level_for_country(self, country: str) -> str:
        return self.LEVEL_BY_COUNTRY.get(country, self.LEVEL_BY_COUNTRY["DEFAULT"])

    def get_lang_for_country(self, country: str) -> str:
        return self.LANG_BY_COUNTRY.get(country, self.LANG_BY_COUNTRY["DEFAULT"])

    async def generate_link_for_company(
        self,
        company: CompanyToVerify,
        ttl_seconds: int = 86400
    ) -> dict:
        """
        Genera un permalink para una empresa específica.
        """
        level_name = self.get_level_for_country(company.country)
        lang = self.get_lang_for_country(company.country)

        payload = {
            "levelName": level_name,
            "userId": company.external_company_id,
            "ttlInSecs": ttl_seconds,
            "lang": lang,
            "applicantIdentifiers": {
                "email": company.email
            },
            "redirect": {
                "successUrl": f"{self.config.portal_url}/kyb/success?company={company.external_company_id}",
                "rejectUrl": f"{self.config.portal_url}/kyb/retry?company={company.external_company_id}"
            }
        }

        response = await self.sumsub_client.post(
            "/resources/sdkIntegrations/levels/-/websdkLink",
            payload
        )

        return {
            "external_company_id": company.external_company_id,
            "legal_name": company.legal_name,
            "country": company.country,
            "verification_link": response["url"],
            "level_name": level_name,
            "lang": lang,
            "ttl_seconds": ttl_seconds
        }

    async def generate_links_for_companies(
        self,
        companies: List[CompanyToVerify],
        ttl_seconds: int = 86400
    ) -> List[dict]:
        """
        Genera permalinks para múltiples empresas en paralelo.

        Args:
            companies: Lista de empresas a verificar
            ttl_seconds: Tiempo de vida de cada link

        Returns:
            Lista de resultados con link por cada empresa
        """
        tasks = [
            self.generate_link_for_company(company, ttl_seconds)
            for company in companies
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Procesar resultados y errores
        processed_results = []
        for i, result in enumerate(results):
            if isinstance(result, Exception):
                processed_results.append({
                    "external_company_id": companies[i].external_company_id,
                    "error": str(result),
                    "success": False
                })
            else:
                result["success"] = True
                processed_results.append(result)

        return processed_results


# Ejemplo de uso
async def main():
    companies = [
        CompanyToVerify(
            external_company_id="empresa-co-001",
            country="CO",
            email="contacto@empresa1.com.co",
            legal_name="Empresa Colombia 1 S.A.S."
        ),
        CompanyToVerify(
            external_company_id="empresa-co-002",
            country="CO",
            email="contacto@empresa2.com.co",
            legal_name="Empresa Colombia 2 S.A.S."
        ),
        CompanyToVerify(
            external_company_id="empresa-mx-001",
            country="MX",
            email="contacto@empresa.com.mx",
            legal_name="Empresa México S.A. de C.V."
        ),
        CompanyToVerify(
            external_company_id="empresa-br-001",
            country="BR",
            email="contato@empresa.com.br",
            legal_name="Empresa Brasil LTDA"
        ),
    ]

    generator = MultiCompanyLinkGenerator(sumsub_client, config)
    results = await generator.generate_links_for_companies(companies)

    for result in results:
        if result["success"]:
            print(f"✅ {result['legal_name']} ({result['country']})")
            print(f"   Link: {result['verification_link']}")
        else:
            print(f"❌ {result['external_company_id']}: {result['error']}")
```

#### Resultado Esperado

```json
[
  {
    "external_company_id": "empresa-co-001",
    "legal_name": "Empresa Colombia 1 S.A.S.",
    "country": "CO",
    "verification_link": "https://in.sumsub.com/websdk/p/abc123...",
    "level_name": "kyb-latam-colombia",
    "lang": "es",
    "success": true
  },
  {
    "external_company_id": "empresa-co-002",
    "legal_name": "Empresa Colombia 2 S.A.S.",
    "country": "CO",
    "verification_link": "https://in.sumsub.com/websdk/p/def456...",
    "level_name": "kyb-latam-colombia",
    "lang": "es",
    "success": true
  },
  {
    "external_company_id": "empresa-mx-001",
    "legal_name": "Empresa México S.A. de C.V.",
    "country": "MX",
    "verification_link": "https://in.sumsub.com/websdk/p/ghi789...",
    "level_name": "kyb-latam-mexico",
    "lang": "es",
    "success": true
  },
  {
    "external_company_id": "empresa-br-001",
    "legal_name": "Empresa Brasil LTDA",
    "country": "BR",
    "verification_link": "https://in.sumsub.com/websdk/p/jkl012...",
    "level_name": "kyb-latam-brazil",
    "lang": "pt",
    "success": true
  }
]
```

#### Ventajas

| Ventaja | Descripción |
|---------|-------------|
| **Trazabilidad** | Cada empresa tiene su propio `externalCompanyId` vinculado |
| **Estados independientes** | Una empresa puede estar APPROVED mientras otra está IN_PROGRESS |
| **Niveles por país** | Requisitos KYB diferentes según jurisdicción |
| **Idioma correcto** | ES para LATAM hispano, PT para Brasil |
| **Anti-duplicación** | Imposible que una empresa use el link de otra |
| **Reportería** | Métricas de conversión por país/empresa |

---

### Opción 2: Unilink Compartido (NO RECOMENDADO)

Un único link universal que cualquier empresa puede usar.

```
https://in.sumsub.com/websdk/unilink/sbx_universal123
```

#### Flujo

```
Usuario accede al unilink
        │
        ▼
┌─────────────────────┐
│ Ingresa su email    │  ◄── Obligatorio antes de iniciar
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ Sumsub crea         │
│ applicant con email │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ Inicia verificación │
└─────────────────────┘
```

#### Problemas

| Problema | Impacto |
|----------|---------|
| **Sin pre-vinculación** | No sabes qué empresa usará el link hasta que ingresen email |
| **Email obligatorio** | Fricción adicional para el usuario |
| **Un email = un applicant** | Si dos personas de la misma empresa usan emails diferentes, crea duplicados |
| **Sin control de país** | Todos usan el mismo nivel de verificación |
| **Riesgo de confusión** | Empresa A podría recibir link y reenviarlo a Empresa B |
| **Difícil trazabilidad** | ¿Cómo vinculas el applicant a tu `externalCompanyId`? |

#### Cuándo podría usarse

- Landing page pública de "Verificar mi empresa"
- Casos donde NO conoces a la empresa de antemano
- Demos o pruebas de concepto

**NO usar para:** Verificación de empresas conocidas en un flujo B2B controlado.

---

### Opción 3: Batch desde Dashboard (Sin API)

Sumsub permite generar múltiples links desde el Dashboard:

```
Dashboard → Integrations → Companies → WebSDK permalinks → Generate batch
```

#### Limitaciones

- No hay API de batch - solo manual desde Dashboard
- No automatizable
- No se integra con tu flujo de onboarding
- Útil solo para casos puntuales/manuales

---

## Configuración de Niveles por País

Para soportar requisitos KYB diferentes por jurisdicción, configurar niveles en Sumsub:

### Estructura Recomendada

```
Sumsub Dashboard → Verification Levels
│
├── kyb-latam-colombia
│   ├── Documentos: RUT, Cámara de Comercio, Certificado Existencia
│   ├── UBO: Requerido (>25% ownership)
│   └── Idioma default: ES
│
├── kyb-latam-mexico
│   ├── Documentos: RFC, Acta Constitutiva, Poder Notarial
│   ├── UBO: Requerido (>25% ownership)
│   └── Idioma default: ES
│
├── kyb-latam-brazil
│   ├── Documentos: CNPJ, Contrato Social, Quadro Societário
│   ├── UBO: Requerido (>25% ownership)
│   └── Idioma default: PT
│
└── kyb-latam-generic
    ├── Documentos: Certificate of Incorporation, Shareholder Registry
    ├── UBO: Requerido (>25% ownership)
    └── Idioma default: EN
```

### Mapeo en Código

```python
# config/kyb_levels.py

KYB_LEVELS = {
    # Colombia
    "CO": {
        "level_name": "kyb-latam-colombia",
        "lang": "es",
        "documents_required": [
            "RUT",
            "Certificado de Existencia y Representación Legal",
            "Cámara de Comercio"
        ],
        "ubo_threshold": 25.0
    },

    # México
    "MX": {
        "level_name": "kyb-latam-mexico",
        "lang": "es",
        "documents_required": [
            "RFC (Constancia de Situación Fiscal)",
            "Acta Constitutiva",
            "Poder Notarial del Representante"
        ],
        "ubo_threshold": 25.0
    },

    # Brasil
    "BR": {
        "level_name": "kyb-latam-brazil",
        "lang": "pt",
        "documents_required": [
            "CNPJ",
            "Contrato Social",
            "Quadro de Sócios e Administradores (QSA)"
        ],
        "ubo_threshold": 25.0
    },

    # Chile
    "CL": {
        "level_name": "kyb-latam-chile",
        "lang": "es",
        "documents_required": [
            "RUT Empresa",
            "Escritura de Constitución",
            "Certificado de Vigencia"
        ],
        "ubo_threshold": 25.0
    },

    # Default
    "DEFAULT": {
        "level_name": "kyb-latam-generic",
        "lang": "en",
        "documents_required": [
            "Certificate of Incorporation",
            "Shareholder Registry",
            "Director Registry"
        ],
        "ubo_threshold": 25.0
    }
}

def get_kyb_config(country_code: str) -> dict:
    return KYB_LEVELS.get(country_code, KYB_LEVELS["DEFAULT"])
```

---

## Integración con Modelo de Datos

### Tabla KYB_VERIFICATION

```sql
CREATE TABLE kyb_verification (
    id UUID PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,           -- Cliente B2B
    external_company_id VARCHAR(100) NOT NULL, -- ID empresa en Retorna
    country_code CHAR(2) NOT NULL,             -- CO, MX, BR, etc.
    provider_type VARCHAR(50) DEFAULT 'SUMSUB',
    provider_applicant_id VARCHAR(100),
    provider_level_name VARCHAR(100),          -- kyb-latam-colombia, etc.
    status VARCHAR(50) NOT NULL,
    verification_link TEXT,
    link_expires_at TIMESTAMP,
    lang CHAR(2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,

    -- Constraints
    CONSTRAINT uq_active_verification
        UNIQUE (tenant_id, external_company_id, status)
        WHERE status NOT IN ('APPROVED', 'REJECTED', 'CANCELED', 'EXPIRED')
);

-- Índices
CREATE INDEX idx_kyb_tenant_company ON kyb_verification(tenant_id, external_company_id);
CREATE INDEX idx_kyb_status ON kyb_verification(status);
CREATE INDEX idx_kyb_country ON kyb_verification(country_code);
```

### Consultas Útiles

```sql
-- Empresas pendientes de verificación por tenant
SELECT
    external_company_id,
    country_code,
    status,
    verification_link,
    link_expires_at
FROM kyb_verification
WHERE tenant_id = 'cliente-abc'
  AND status NOT IN ('APPROVED', 'REJECTED', 'CANCELED')
ORDER BY created_at;

-- Resumen por país
SELECT
    country_code,
    status,
    COUNT(*) as count
FROM kyb_verification
WHERE tenant_id = 'cliente-abc'
GROUP BY country_code, status;

-- Links próximos a expirar (próximas 4 horas)
SELECT *
FROM kyb_verification
WHERE status IN ('NOT_STARTED', 'IN_PROGRESS')
  AND link_expires_at BETWEEN NOW() AND NOW() + INTERVAL '4 hours';
```

---

## API Endpoints

### POST /api/v1/kyb/verifications/batch

Crear verificaciones para múltiples empresas en una sola llamada.

**Request:**
```json
{
  "tenant_id": "cliente-abc",
  "companies": [
    {
      "external_company_id": "empresa-co-001",
      "country": "CO",
      "legal_name": "Empresa Colombia 1 S.A.S.",
      "email": "contacto@empresa1.com.co"
    },
    {
      "external_company_id": "empresa-mx-001",
      "country": "MX",
      "legal_name": "Empresa México S.A. de C.V.",
      "email": "contacto@empresa.com.mx"
    }
  ],
  "link_ttl_seconds": 86400,
  "send_email": true
}
```

**Response:**
```json
{
  "created": 2,
  "failed": 0,
  "verifications": [
    {
      "id": "uuid-1",
      "external_company_id": "empresa-co-001",
      "status": "NOT_STARTED",
      "verification_link": "https://in.sumsub.com/websdk/p/abc123",
      "link_expires_at": "2026-02-24T10:00:00Z",
      "email_sent": true
    },
    {
      "id": "uuid-2",
      "external_company_id": "empresa-mx-001",
      "status": "NOT_STARTED",
      "verification_link": "https://in.sumsub.com/websdk/p/def456",
      "link_expires_at": "2026-02-24T10:00:00Z",
      "email_sent": true
    }
  ]
}
```

### GET /api/v1/kyb/verifications?tenant_id={id}

Listar todas las verificaciones de un tenant.

**Response:**
```json
{
  "tenant_id": "cliente-abc",
  "total": 4,
  "by_status": {
    "NOT_STARTED": 1,
    "IN_PROGRESS": 1,
    "APPROVED": 2
  },
  "by_country": {
    "CO": 2,
    "MX": 1,
    "BR": 1
  },
  "verifications": [
    {
      "id": "uuid-1",
      "external_company_id": "empresa-co-001",
      "legal_name": "Empresa Colombia 1 S.A.S.",
      "country": "CO",
      "status": "APPROVED",
      "completed_at": "2026-02-20T15:30:00Z"
    },
    // ... más empresas
  ]
}
```

---

## Resumen de Decisiones

| Decisión | Elección | Justificación |
|----------|----------|---------------|
| Tipo de link | **Permalink** | Control total, trazabilidad, anti-duplicación |
| Generación | **Paralela** | Performance, todas las empresas en una operación |
| Niveles | **Por país** | Requisitos legales diferentes por jurisdicción |
| Idioma | **Por país** | UX óptima para cada región |
| Almacenamiento | **Un registro por empresa** | Estados independientes, reportería granular |
| API batch | **Sí** | Simplifica integración para clientes B2B |

---

## Referencias

- [SPIKE_KYB_INTEGRATION_ARCHITECTURE.md](./SPIKE_KYB_INTEGRATION_ARCHITECTURE.md) - Arquitectura principal
- [SERVICE_ARCHITECTURE_OPTIONS.md](./SERVICE_ARCHITECTURE_OPTIONS.md) - Opciones de arquitectura de servicio
- [Sumsub: Generate WebSDK external link](https://docs.sumsub.com/reference/generate-websdk-external-link)
- [Sumsub: Verification links](https://docs.sumsub.com/docs/verification-links)
