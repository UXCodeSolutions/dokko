#!/usr/bin/env bash
set -e

# Detiene todos los procesos en segundo plano al presionar Ctrl+C
trap 'kill 0' EXIT

echo "→ Iniciando Backend FastAPI en http://127.0.0.1:8000 ..."
(cd dokko-backend && venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload) &

echo "→ Esperando 2 segundos para levantar el frontend..."
sleep 2

echo "→ Iniciando Frontend Flutter..."
# Por defecto abre en Chrome. Puedes cambiar -d chrome por -d macos si prefieres app nativa
(cd dokko && flutter run -d chrome) &

wait
