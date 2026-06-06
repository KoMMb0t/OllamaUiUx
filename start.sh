#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")"
echo "Starte Ollama + Open WebUI..."
docker compose up -d
echo "[OK] Stack läuft → http://localhost:3000"
xdg-open http://localhost:3000 2>/dev/null || open http://localhost:3000 2>/dev/null || true
