#!/bin/bash

# Script para iniciar el frontend del POC

echo "================================================"
echo "Iniciando POC Frontend - Sumsub Integration"
echo "================================================"
echo ""

# Verificar si estamos en el directorio correcto
if [ ! -d "poc-frontend" ]; then
    echo "Error: Directorio poc-frontend no encontrado"
    echo "Por favor ejecuta este script desde el directorio spike-sumsub/"
    exit 1
fi

cd poc-frontend

# Verificar si existe .env
if [ ! -f ".env" ]; then
    echo "Creando archivo .env..."
    cp .env.example .env
    echo ""
fi

# Verificar si node_modules existe
if [ ! -d "node_modules" ]; then
    echo "Instalando dependencias..."
    npm install
    echo ""
fi

echo "Iniciando aplicación en modo desarrollo..."
echo ""
echo "Frontend corriendo en: http://localhost:5173"
echo ""
echo "IMPORTANTE: Asegúrate de que el backend esté corriendo en http://localhost:3001"
echo ""
echo "================================================"
echo ""

npm run dev
