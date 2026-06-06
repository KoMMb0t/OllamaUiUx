@echo off
chcp 65001 >nul
echo.
echo  Stoppe Ollama + Open WebUI Stack...
cd /d "%~dp0"
docker compose down
echo.
echo  [OK] Stack gestoppt.
pause
