# Quick Start Guide - POC Sumsub Integration

Guía de inicio rápido en 5 minutos.

## Pre-requisitos

- Node.js 18+
- Credenciales de Sumsub (App Token + Secret Key)

## Paso 1: Backend (2 minutos)

```bash
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub/poc-backend

# Instalar
npm install

# Configurar
cp .env.example .env
nano .env  # Agregar SUMSUB_APP_TOKEN y SUMSUB_SECRET_KEY

# Iniciar
npm run start:dev
```

Debe mostrar: `Application is running on: http://localhost:3001`

## Paso 2: Frontend (1 minuto)

```bash
# Nueva terminal
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub/poc-frontend

# Instalar
npm install

# Iniciar
npm run dev
```

Debe mostrar: `Local: http://localhost:5173/`

## Paso 3: Probar (2 minutos)

1. Abrir: http://localhost:5173
2. Hacer clic en "Generar Link de Verificación" en cualquier empresa
3. Hacer clic en "Abrir Link en Nueva Ventana"
4. Verificar que se carga Sumsub

## Verificación Rápida

### Backend funciona?
```bash
curl http://localhost:3001/sumsub/levels/CO
```
Debe retornar: `{"country":"CO","level":"kyb-latam-colombia"}`

### Frontend funciona?
Abrir: http://localhost:5173
Debe mostrar 3 empresas.

## Problemas Comunes

### Backend no inicia
```bash
cd poc-backend
rm -rf node_modules package-lock.json
npm install
```

### Frontend no inicia
```bash
cd poc-frontend
rm -rf node_modules package-lock.json
npm install
```

### Credenciales inválidas
Verificar `.env` en poc-backend:
- SUMSUB_APP_TOKEN correcto
- SUMSUB_SECRET_KEY correcto

## Scripts Automatizados

Alternativamente, usa los scripts:

```bash
# Terminal 1
./start-backend.sh

# Terminal 2
./start-frontend.sh
```

## Siguiente Paso

Una vez funcionando, revisar:
- `INSTRUCCIONES.md` para guía detallada
- `README-POC.md` para documentación completa
- `api-examples.http` para ejemplos de API

## URLs Importantes

- Frontend: http://localhost:5173
- Backend: http://localhost:3001
- Webhook test: http://localhost:3001/webhooks/sumsub/test

## Empresas Disponibles

1. **emp-co-001** - Empresa Colombia 1 (kyb-latam-colombia)
2. **emp-co-002** - Empresa Colombia 2 (kyb-latam-colombia)
3. **emp-br-001** - Empresa Brasil 1 (kyb-latam-brazil)

## Test Rápido con cURL

```bash
# Generar permalink
curl -X POST http://localhost:3001/sumsub/permalinks \
  -H "Content-Type: application/json" \
  -d '{"externalUserId":"emp-co-001","levelName":"kyb-latam-colombia"}'

# Webhook de prueba
curl -X POST http://localhost:3001/webhooks/sumsub/test \
  -H "Content-Type: application/json" \
  -d '{"externalUserId":"emp-co-001","type":"applicantReviewed"}'
```

Listo para usar!
