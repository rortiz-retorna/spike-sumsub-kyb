# POC - Integración Sumsub KYB

Proof of Concept completo para integración con Sumsub KYB (Know Your Business) utilizando permalinks con External User ID.

## Inicio Rápido

```bash
# Terminal 1 - Backend
cd poc-backend
npm install
cp .env.example .env
# Configurar SUMSUB_APP_TOKEN y SUMSUB_SECRET_KEY en .env
npm run start:dev

# Terminal 2 - Frontend
cd poc-frontend
npm install
npm run dev
```

Abre http://localhost:5173 en tu navegador.

## Documentación

- **[QUICK-START.md](QUICK-START.md)** - Inicio rápido en 5 minutos
- **[INSTRUCCIONES.md](INSTRUCCIONES.md)** - Guía paso a paso completa
- **[README-POC.md](README-POC.md)** - Documentación técnica detallada
- **[ESTRUCTURA-PROYECTO.txt](ESTRUCTURA-PROYECTO.txt)** - Estructura visual del proyecto
- **[RESUMEN-PROYECTO.md](RESUMEN-PROYECTO.md)** - Resumen de archivos y funcionalidades

## Estructura del Proyecto

```
spike-sumsub/
├── poc-backend/          # Backend NestJS
│   ├── src/
│   │   ├── config/       # Configuración
│   │   ├── sumsub/       # Integración Sumsub
│   │   └── webhooks/     # Webhooks
│   └── package.json
│
├── poc-frontend/         # Frontend React + Vite
│   ├── src/
│   │   ├── components/   # Componentes UI
│   │   ├── services/     # API services
│   │   ├── types/        # TypeScript types
│   │   └── data/         # Datos de empresas
│   └── package.json
│
└── docs/                 # Documentación
```

## Características

### Backend (NestJS)
- Generación de firmas HMAC-SHA256 para Sumsub API
- Creación de applicants tipo "company"
- Generación de permalinks con External User ID
- Validación de webhooks de Sumsub
- 4 endpoints REST + 2 endpoints de webhooks
- Logging completo de operaciones

### Frontend (React)
- UI con 3 empresas de ejemplo (2 Colombia, 1 Brasil)
- Generación de permalinks desde la interfaz
- Visualización de links generados
- Apertura de links en nueva ventana
- Manejo de estados de carga y error

## Empresas Configuradas

1. **emp-co-001** - Empresa Colombia 1 (kyb-latam-colombia)
2. **emp-co-002** - Empresa Colombia 2 (kyb-latam-colombia)
3. **emp-br-001** - Empresa Brasil 1 (kyb-latam-brazil)

## Endpoints API

### Sumsub
- `POST /sumsub/applicants` - Crear applicant
- `POST /sumsub/permalinks` - Generar permalink
- `GET /sumsub/applicants/:externalUserId` - Obtener applicant
- `GET /sumsub/levels/:country` - Obtener level por país

### Webhooks
- `POST /webhooks/sumsub` - Webhook con validación de firma
- `POST /webhooks/sumsub/test` - Webhook de prueba sin validación

## Ejemplos de Uso

### Generar Permalink
```bash
curl -X POST http://localhost:3001/sumsub/permalinks \
  -H "Content-Type: application/json" \
  -d '{
    "externalUserId": "emp-co-001",
    "levelName": "kyb-latam-colombia",
    "ttl": 86400
  }'
```

### Crear Applicant
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

Ver más ejemplos en [api-examples.http](api-examples.http)

## Configuración

### Backend (.env)
```env
SUMSUB_APP_TOKEN=tu_app_token
SUMSUB_SECRET_KEY=tu_secret_key
SUMSUB_BASE_URL=https://api.sumsub.com
PORT=3001
LEVEL_COLOMBIA=kyb-latam-colombia
LEVEL_BRAZIL=kyb-latam-brazil
PERMALINK_TTL=86400
```

### Frontend (.env)
```env
VITE_API_BASE_URL=http://localhost:3001
```

## Scripts Útiles

### Inicio Automatizado
```bash
./start-backend.sh   # Inicia el backend
./start-frontend.sh  # Inicia el frontend
```

### Testing
```bash
# Backend
cd poc-backend
npm run start:dev

# Frontend
cd poc-frontend
npm run dev

# Build
cd poc-backend && npm run build
cd poc-frontend && npm run build
```

## Tecnologías

- **Backend**: NestJS 10.3, TypeScript 5.3, Axios
- **Frontend**: React 18.2, TypeScript 5.3, Vite 5.0, Axios
- **Integración**: Sumsub Web SDK 2.7

## Flujo de Funcionamiento

1. Usuario selecciona empresa en frontend
2. Frontend llama a backend para generar permalink
3. Backend genera firma HMAC y llama a Sumsub API
4. Backend retorna permalink al frontend
5. Usuario abre permalink y completa verificación en Sumsub
6. Sumsub envía webhooks al backend con resultados

## Seguridad

- Secret Key nunca expuesto al frontend
- Firmas HMAC-SHA256 en todas las peticiones a Sumsub
- Validación de firmas en webhooks
- CORS restringido a localhost
- TypeScript strict mode

## Requisitos

- Node.js 18+
- npm
- Cuenta Sumsub con App Token y Secret Key
- Niveles KYB configurados en Sumsub

## Troubleshooting

### Backend no inicia
```bash
cd poc-backend
rm -rf node_modules package-lock.json
npm install
```

### Frontend no conecta con backend
Verificar que:
- Backend esté corriendo en http://localhost:3001
- `.env` del frontend tenga `VITE_API_BASE_URL=http://localhost:3001`
- CORS esté habilitado en el backend

### Credenciales inválidas
Verificar en `poc-backend/.env`:
- `SUMSUB_APP_TOKEN` correcto
- `SUMSUB_SECRET_KEY` correcto

Ver [INSTRUCCIONES.md](INSTRUCCIONES.md) para más detalles.

## Recursos Adicionales

- [Documentación Sumsub](https://developers.sumsub.com/)
- [Sumsub Web SDK](https://developers.sumsub.com/docs/web-sdk-reference)
- [Sumsub API Reference](https://developers.sumsub.com/api-reference/)
- [Webhooks Sumsub](https://developers.sumsub.com/docs/webhooks)

## Archivos del Proyecto

### Documentación
- `README.md` - Este archivo
- `QUICK-START.md` - Inicio rápido
- `INSTRUCCIONES.md` - Guía paso a paso
- `README-POC.md` - Documentación técnica
- `ESTRUCTURA-PROYECTO.txt` - Estructura visual
- `RESUMEN-PROYECTO.md` - Resumen detallado

### Código
- `poc-backend/` - Backend NestJS
- `poc-frontend/` - Frontend React
- `api-examples.http` - Ejemplos de API

### Scripts
- `start-backend.sh` - Iniciar backend
- `start-frontend.sh` - Iniciar frontend

## URLs

- **Frontend**: http://localhost:5173
- **Backend**: http://localhost:3001
- **Webhook**: http://localhost:3001/webhooks/sumsub
- **Test Webhook**: http://localhost:3001/webhooks/sumsub/test

## Soporte

Para más información:
1. Lee la documentación en orden: QUICK-START → INSTRUCCIONES → README-POC
2. Revisa los logs del backend y frontend
3. Consulta `api-examples.http` para ejemplos de API
4. Verifica la documentación de Sumsub

## Licencia

Este es un Proof of Concept para uso interno.

---

Creado con fines de demostración de integración con Sumsub KYB.
