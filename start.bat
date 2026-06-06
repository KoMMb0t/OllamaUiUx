@echo off
chcp 65001 >nul
echo.
echo  Starte Ollama + Open WebUI Stack...
cd /d "%~dp0"
docker compose up -d
echo.
echo  [OK] Stack läuft!
echo  Open WebUI: http://localhost:3000
echo.
timeout /t 3 /nobreak >nul
start http://localhost:3000
