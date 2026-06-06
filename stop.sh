#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE[0]}")"
echo "Stoppe Ollama + Open WebUI..."
docker compose down
echo "[OK] Stack gestoppt."
