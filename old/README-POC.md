# POC - Integración Sumsub KYB

Proof of Concept para integración con Sumsub KYB (Know Your Business) utilizando permalinks con External User ID.

## Estructura del Proyecto

```
spike-sumsub/
├── poc-backend/          # Backend NestJS
│   ├── src/
│   │   ├── config/       # Configuración de Sumsub
│   │   ├── sumsub/       # Módulo de integración Sumsub
│   │   ├── webhooks/     # Manejo de webhooks
│   │   └── main.ts
│   ├── package.json
│   └── README.md
│
├── poc-frontend/         # Frontend React + Vite
│   ├── src/
│   │   ├── components/   # Componentes React
│   │   ├── services/     # Servicios API
│   │   ├── types/        # Tipos TypeScript
│   │   ├── data/         # Datos mock
│   │   └── App.tsx
│   ├── package.json
│   └── README.md
│
└── README-POC.md         # Este archivo
```

## Requisitos Previos

- Node.js 18+ y npm
- Cuenta de Sumsub con:
  - App Token
  - Secret Key
  - Niveles KYB configurados (kyb-latam-colombia, kyb-latam-brazil)

## Instalación Rápida

### 1. Backend (Terminal 1)

```bash
cd poc-backend
npm install
cp .env.example .env
# Editar .env con tus credenciales de Sumsub
npm run start:dev
```

El backend estará corriendo en: http://localhost:3001

### 2. Frontend (Terminal 2)

```bash
cd poc-frontend
npm install
npm run dev
```

El frontend estará corriendo en: http://localhost:5173

## Configuración

### Backend (.env)

```env
SUMSUB_APP_TOKEN=your_app_token_here
SUMSUB_SECRET_KEY=your_secret_key_here
SUMSUB_BASE_URL=https://api.sumsub.com

PORT=3001
NODE_ENV=development

LEVEL_COLOMBIA=kyb-latam-colombia
LEVEL_BRAZIL=kyb-latam-brazil
LEVEL_MEXICO=kyb-latam-mexico

PERMALINK_TTL=86400
```

### Frontend (.env)

```env
VITE_API_BASE_URL=http://localhost:3001
```

## Flujo de Funcionamiento

### 1. Generación de Permalink

```
Usuario selecciona empresa → Frontend llama al backend → Backend genera permalink con Sumsub API → Retorna URL al frontend
```

### 2. Verificación

```
Usuario abre permalink → Redirige a Sumsub → Completa verificación → Sumsub envía webhook al backend
```

### 3. Webhook

```
Sumsub envía evento → Backend valida firma → Backend procesa evento → Backend registra en logs
```

## Empresas de Ejemplo

El POC incluye 3 empresas predefinidas:

1. **emp-co-001** - Empresa Colombia 1
   - País: Colombia
   - Level: kyb-latam-colombia

2. **emp-co-002** - Empresa Colombia 2
   - País: Colombia
   - Level: kyb-latam-colombia

3. **emp-br-001** - Empresa Brasil 1
   - País: Brasil
   - Level: kyb-latam-brazil

## Endpoints del Backend

### API de Sumsub

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | /sumsub/applicants | Crear applicant (empresa) |
| POST | /sumsub/permalinks | Generar permalink |
| GET | /sumsub/applicants/:externalUserId | Obtener applicant |
| GET | /sumsub/levels/:country | Obtener level por país |

### Webhooks

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | /webhooks/sumsub | Webhook de Sumsub (con validación) |
| POST | /webhooks/sumsub/test | Webhook de prueba (sin validación) |

## Ejemplos de Uso

### Generar Permalink (curl)

```bash
curl -X POST http://localhost:3001/sumsub/permalinks \
  -H "Content-Type: application/json" \
  -d '{
    "externalUserId": "emp-co-001",
    "levelName": "kyb-latam-colombia",
    "ttl": 86400
  }'
```

Respuesta:
```json
{
  "url": "https://sumsub.com/websdk/...",
  "externalUserId": "emp-co-001",
  "levelName": "kyb-latam-colombia",
  "ttl": 86400
}
```

### Crear Applicant (curl)

```bash
curl -X POST http://localhost:3001/sumsub/applicants \
  -H "Content-Type: application/json" \
  -d '{
    "externalUserId": "emp-co-001",
    "levelName": "kyb-latam-colombia",
    "companyName": "Empresa Colombia 1",
    "country": "CO"
  }'
```

### Probar Webhook (curl)

```bash
curl -X POST http://localhost:3001/webhooks/sumsub/test \
  -H "Content-Type: application/json" \
  -d '{
    "applicantId": "test-123",
    "externalUserId": "emp-co-001",
    "type": "applicantReviewed",
    "reviewStatus": "completed"
  }'
```

## Características Implementadas

### Backend
- Generación de firmas HMAC-SHA256
- Autenticación con Sumsub API
- Creación de applicants tipo "company"
- Generación de permalinks con External User ID
- Validación de webhooks
- Manejo de eventos: applicantCreated, applicantPending, applicantReviewed
- Logging detallado
- Configuración por variables de entorno

### Frontend
- Lista de empresas con información
- Generación de permalinks
- Visualización de links generados
- Apertura de links en nueva ventana
- Manejo de estados de carga y error
- UI responsive y limpia
- Integración con backend vía API REST

## Conceptos Clave

### External User ID
- Identificador único de la empresa en tu sistema
- Formato: emp-{country}-{number} (ej: emp-co-001)
- Permanente y reutilizable
- Usado para generar permalinks del tipo "Usuario específico"

### Permalink
- Link de verificación permanente
- Asociado a un External User ID específico
- TTL configurable (por defecto 24 horas)
- Reutilizable dentro del TTL
- Redirige a la página de Sumsub para completar verificación

### Niveles KYB
- kyb-latam-colombia: Colombia
- kyb-latam-brazil: Brasil
- kyb-latam-mexico: México

### Webhooks
- Eventos enviados por Sumsub
- Validación de firma con HMAC-SHA256
- Tipos: applicantCreated, applicantPending, applicantReviewed
- Payload incluye: applicantId, externalUserId, reviewStatus, reviewResult

## Pruebas

### 1. Verificar Backend

```bash
# Health check (puedes crear este endpoint si lo necesitas)
curl http://localhost:3001/

# Obtener level por país
curl http://localhost:3001/sumsub/levels/CO
```

### 2. Generar Permalink desde Frontend

1. Abrir http://localhost:5173
2. Seleccionar una empresa
3. Hacer clic en "Generar Link de Verificación"
4. Verificar que se genera el link
5. Hacer clic en "Abrir Link en Nueva Ventana"

### 3. Verificar Webhooks

```bash
# Probar webhook sin validación
curl -X POST http://localhost:3001/webhooks/sumsub/test \
  -H "Content-Type: application/json" \
  -d '{
    "test": "data",
    "externalUserId": "emp-co-001"
  }'

# Revisar logs del backend
```

## Logs y Debugging

### Backend
Los logs se muestran en la consola del backend:
- Creación de applicants
- Generación de permalinks
- Eventos de webhooks
- Errores de API

### Frontend
Los logs se muestran en la consola del navegador:
- Llamadas a API
- Respuestas
- Errores

## Arquitectura

### Backend (NestJS)
```
AppModule
├── ConfigModule (global)
├── SumsubModule
│   ├── SumsubController
│   └── SumsubService
└── WebhookModule
    ├── WebhookController
    └── SumsubService (inyectado)
```

### Frontend (React)
```
App
└── CompanyCard (x3)
    └── ApiService
```

## Seguridad

- Secret Key nunca se expone al frontend
- Firmas HMAC-SHA256 en todas las peticiones a Sumsub
- Validación de firmas en webhooks
- CORS habilitado solo para localhost
- Variables de entorno para credenciales

## Limitaciones del POC

- No hay persistencia de datos (solo logs)
- No hay autenticación de usuarios
- UI simplificada con estilos inline
- No hay tests automatizados
- No hay manejo de errores de red
- No hay retry logic
- No hay rate limiting

## Próximos Pasos (Fuera del POC)

1. Implementar base de datos para persistir applicants y verificaciones
2. Agregar autenticación y autorización
3. Implementar manejo de eventos en tiempo real (WebSockets)
4. Agregar UI completa con estados de verificación
5. Implementar retry logic y manejo de errores robusto
6. Agregar tests unitarios y de integración
7. Implementar CI/CD
8. Dockerizar aplicaciones
9. Configurar ambiente de staging

## Recursos

- [Documentación Sumsub](https://developers.sumsub.com/)
- [Sumsub Web SDK](https://developers.sumsub.com/docs/web-sdk-reference)
- [Sumsub API Reference](https://developers.sumsub.com/api-reference/)
- [Webhooks Sumsub](https://developers.sumsub.com/docs/webhooks)

## Soporte

Para más información, revisa:
- `/poc-backend/README.md` - Documentación del backend
- `/poc-frontend/README.md` - Documentación del frontend
- Logs del backend en consola
- Logs del frontend en DevTools del navegador

## Licencia

Este es un Proof of Concept para uso interno.
