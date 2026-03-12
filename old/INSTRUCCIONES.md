# Instrucciones para Ejecutar el POC

Guía paso a paso para ejecutar el Proof of Concept de integración con Sumsub.

## Pre-requisitos

Antes de comenzar, asegúrate de tener:

1. **Node.js 18 o superior** instalado
   ```bash
   node --version  # Debe ser >= 18
   npm --version
   ```

2. **Credenciales de Sumsub**:
   - App Token
   - Secret Key
   - Niveles KYB configurados en tu cuenta de Sumsub:
     - kyb-latam-colombia
     - kyb-latam-brazil
     - (Opcional) kyb-latam-mexico

3. **Dos terminales abiertas** (una para backend, otra para frontend)

## Paso 1: Configurar el Backend

### 1.1. Navegar al directorio del backend
```bash
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub/poc-backend
```

### 1.2. Instalar dependencias
```bash
npm install
```

### 1.3. Configurar variables de entorno
```bash
cp .env.example .env
```

### 1.4. Editar el archivo .env
Abre el archivo `.env` con tu editor favorito:
```bash
nano .env
# o
code .env
# o
vim .env
```

Configura las siguientes variables con tus credenciales de Sumsub:
```env
SUMSUB_APP_TOKEN=tu_app_token_aqui
SUMSUB_SECRET_KEY=tu_secret_key_aqui
SUMSUB_BASE_URL=https://api.sumsub.com

PORT=3001
NODE_ENV=development

LEVEL_COLOMBIA=kyb-latam-colombia
LEVEL_BRAZIL=kyb-latam-brazil
LEVEL_MEXICO=kyb-latam-mexico

PERMALINK_TTL=86400
```

### 1.5. Iniciar el backend
```bash
npm run start:dev
```

Deberías ver en la terminal:
```
[Bootstrap] Application is running on: http://localhost:3001
[Bootstrap] Webhook endpoint: http://localhost:3001/webhooks/sumsub
[Bootstrap] Test webhook endpoint: http://localhost:3001/webhooks/sumsub/test
```

**Deja esta terminal abierta y corriendo.**

## Paso 2: Configurar el Frontend

### 2.1. Abrir una nueva terminal

### 2.2. Navegar al directorio del frontend
```bash
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub/poc-frontend
```

### 2.3. Instalar dependencias
```bash
npm install
```

### 2.4. Verificar variables de entorno
El archivo `.env` ya debería existir con:
```env
VITE_API_BASE_URL=http://localhost:3001
```

Si no existe, créalo:
```bash
cp .env.example .env
```

### 2.5. Iniciar el frontend
```bash
npm run dev
```

Deberías ver en la terminal:
```
VITE v5.x.x ready in xxx ms

➜  Local:   http://localhost:5173/
➜  Network: use --host to expose
```

**Deja esta terminal abierta y corriendo.**

## Paso 3: Usar la Aplicación

### 3.1. Abrir el navegador
Abre tu navegador y ve a: http://localhost:5173

### 3.2. Verificar que se cargan las 3 empresas
Deberías ver:
- Empresa Colombia 1 (emp-co-001)
- Empresa Colombia 2 (emp-co-002)
- Empresa Brasil 1 (emp-br-001)

### 3.3. Generar un link de verificación

1. Selecciona una empresa (ejemplo: Empresa Colombia 1)
2. Haz clic en el botón "Generar Link de Verificación"
3. Espera unos segundos mientras se genera el link
4. Deberías ver:
   - El link generado
   - El TTL (24 horas)
   - Un botón "Abrir Link en Nueva Ventana"

### 3.4. Probar el link

1. Haz clic en "Abrir Link en Nueva Ventana"
2. Se abrirá una nueva pestaña con la página de Sumsub
3. Deberías ver el SDK de Sumsub cargado
4. Puedes iniciar el proceso de verificación

### 3.5. Verificar logs del backend

Regresa a la terminal del backend y verifica que se muestren logs como:
```
[SumsubService] Generating permalink for: emp-co-001 with level: kyb-latam-colombia
[SumsubService] Permalink generated successfully
[SumsubController] Generating permalink for: emp-co-001
```

## Paso 4: Probar los Webhooks

### 4.1. Abrir una tercera terminal

### 4.2. Probar el endpoint de webhook de prueba
```bash
curl -X POST http://localhost:3001/webhooks/sumsub/test \
  -H "Content-Type: application/json" \
  -d '{
    "applicantId": "test-123",
    "externalUserId": "emp-co-001",
    "type": "applicantReviewed",
    "reviewStatus": "completed",
    "reviewResult": {
      "reviewAnswer": "GREEN"
    }
  }'
```

### 4.3. Verificar logs del backend
Deberías ver en la terminal del backend:
```
[WebhookController] Received test webhook (no signature validation)
[WebhookController] Payload: { ... }
```

## Paso 5: Probar con API Examples (Opcional)

Si usas VS Code con la extensión REST Client:

### 5.1. Abrir el archivo api-examples.http
```bash
code api-examples.http
```

### 5.2. Ejecutar requests
Haz clic en "Send Request" sobre cualquiera de los ejemplos para probar los endpoints.

## Troubleshooting

### Backend no inicia

**Error: "Cannot find module"**
```bash
cd poc-backend
rm -rf node_modules package-lock.json
npm install
```

**Error: Credenciales inválidas**
- Verifica que el archivo `.env` tenga las credenciales correctas
- Verifica que el App Token y Secret Key sean válidos en Sumsub

### Frontend no inicia

**Error: "Cannot find module"**
```bash
cd poc-frontend
rm -rf node_modules package-lock.json
npm install
```

**Error: CORS o Network**
- Verifica que el backend esté corriendo en http://localhost:3001
- Verifica que el archivo `.env` del frontend tenga la URL correcta

### Link de verificación no se genera

**Error 401 o 403**
- Verifica las credenciales de Sumsub en el `.env` del backend
- Verifica que el App Token y Secret Key sean correctos

**Error 404**
- Verifica que el nivel KYB exista en tu cuenta de Sumsub
- Verifica que el nombre del nivel sea exacto (kyb-latam-colombia)

### No se reciben webhooks

Para recibir webhooks de Sumsub en desarrollo local:

1. Usa ngrok o similar para exponer tu puerto 3001:
   ```bash
   ngrok http 3001
   ```

2. Configura el webhook URL en Sumsub dashboard:
   ```
   https://tu-url-ngrok.ngrok.io/webhooks/sumsub
   ```

3. Asegúrate de que el Secret Key sea el mismo en ambos lugares

## Scripts de Inicio Rápido

También puedes usar los scripts proporcionados:

### Backend
```bash
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub
./start-backend.sh
```

### Frontend
```bash
cd /home/rafael/Documents/retorna/core-reporting/spike-sumsub
./start-frontend.sh
```

## Verificación de Instalación Correcta

Si todo está funcionando correctamente, deberías poder:

1. Ver el frontend en http://localhost:5173
2. Ver logs del backend en la terminal
3. Generar links de verificación desde el frontend
4. Abrir links y ver el SDK de Sumsub
5. Recibir logs de webhooks de prueba

## Próximos Pasos

Una vez que el POC esté funcionando:

1. Completa una verificación de prueba en Sumsub
2. Observa los logs del backend cuando se reciban webhooks
3. Prueba con las 3 empresas diferentes
4. Prueba generar múltiples links para la misma empresa
5. Verifica que los links reutilicen el mismo applicant

## Contacto

Si tienes problemas, verifica:
- Logs del backend en la terminal
- Logs del frontend en DevTools del navegador (F12)
- README-POC.md para más detalles
- README.md del backend y frontend
