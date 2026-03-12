#!/bin/bash

# Script para iniciar el backend del POC

echo "================================================"
echo "Iniciando POC Backend - Sumsub Integration"
echo "================================================"
echo ""

# Verificar si estamos en el directorio correcto
if [ ! -d "poc-backend" ]; then
    echo "Error: Directorio poc-backend no encontrado"
    echo "Por favor ejecuta este script desde el directorio spike-sumsub/"
    exit 1
fi

cd poc-backend

# Verificar si existe .env
if [ ! -f ".env" ]; then
    echo "Advertencia: Archivo .env no encontrado"
    echo "Creando .env desde .env.example..."
    cp .env.example .env
    echo ""
    echo "IMPORTANTE: Debes configurar las credenciales de Sumsub en el archivo .env"
    echo "Ubicación: poc-backend/.env"
    echo ""
    echo "Variables requeridas:"
    echo "  - SUMSUB_APP_TOKEN"
    echo "  - SUMSUB_SECRET_KEY"
    echo ""
    read -p "Presiona Enter cuando hayas configurado el archivo .env..."
fi

# Verificar si node_modules existe
if [ ! -d "node_modules" ]; then
    echo "Instalando dependencias..."
    npm install
    echo ""
fi

echo "Iniciando servidor en modo desarrollo..."
echo ""
echo "Backend corriendo en: http://localhost:3001"
echo "Endpoints disponibles:"
echo "  - POST http://localhost:3001/sumsub/applicants"
echo "  - POST http://localhost:3001/sumsub/permalinks"
echo "  - GET  http://localhost:3001/sumsub/applicants/:externalUserId"
echo "  - POST http://localhost:3001/webhooks/sumsub"
echo "  - POST http://localhost:3001/webhooks/sumsub/test"
echo ""
echo "================================================"
echo ""

npm run start:dev
