@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

echo.
echo ============================================================
echo   Ollama + Open WebUI Setup  ^|  Kommuniverse
echo ============================================================
echo.

:: --- Verzeichnis auf Skript-Pfad setzen ---
cd /d "%~dp0"

:: ============================================================
:: SCHRITT 1: Voraussetzungen prüfen
:: ============================================================
echo [1/5] Prüfe Voraussetzungen...

:: Docker prüfen
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [FEHLER] Docker nicht gefunden!
    echo  Bitte Docker Desktop installieren: https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)
echo  [OK] Docker gefunden

:: Docker Desktop läuft?
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [FEHLER] Docker Desktop läuft nicht!
    echo  Bitte Docker Desktop starten und erneut versuchen.
    echo.
    pause
    exit /b 1
)
echo  [OK] Docker Desktop läuft

:: ============================================================
:: SCHRITT 2: .env Datei erstellen
:: ============================================================
echo.
echo [2/5] Konfiguration einrichten...

if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo.
    echo  ─────────────────────────────────────────────────
    echo  WICHTIG: Bitte deinen OpenRouter API Key eingeben
    echo  (https://openrouter.ai/keys)
    echo  ─────────────────────────────────────────────────
    set /p ORKEY="  OpenRouter API Key (Enter zum Überspringen): "
    
    if not "!ORKEY!"=="" (
        :: API Key in .env schreiben
        powershell -Command "(Get-Content .env) -replace 'sk-or-xxxxxxxxxxxxxxxxxxxx', '!ORKEY!' | Set-Content .env"
        echo  [OK] API Key gespeichert
    ) else (
        echo  [HINWEIS] Kein API Key eingegeben. Kann später in .env eingetragen werden.
    )
    
    :: Zufälligen Secret Key generieren
    for /f %%i in ('powershell -Command "[System.Guid]::NewGuid().ToString() + [System.Guid]::NewGuid().ToString()"') do set NEWKEY=%%i
    powershell -Command "(Get-Content .env) -replace 'mein-geheimer-schluessel-bitte-aendern', '!NEWKEY!' | Set-Content .env"
    echo  [OK] Sicherheitsschlüssel generiert
) else (
    echo  [OK] .env bereits vorhanden
)

:: ============================================================
:: SCHRITT 3: Docker Stack starten
:: ============================================================
echo.
echo [3/5] Starte Docker Stack (kann beim ersten Mal einige Minuten dauern)...
echo.

docker compose up -d --pull always

if %errorlevel% neq 0 (
    echo.
    echo  [FEHLER] Docker Compose fehlgeschlagen!
    echo  Prüfe die Ausgabe oben auf Fehler.
    pause
    exit /b 1
)

echo.
echo  [OK] Stack gestartet

:: ============================================================
:: SCHRITT 4: Auf Open WebUI warten
:: ============================================================
echo.
echo [4/5] Warte auf Open WebUI (bis zu 60 Sekunden)...

set READY=0
for /l %%i in (1,1,12) do (
    if !READY!==0 (
        timeout /t 5 /nobreak >nul
        curl -sf http://localhost:3000 >nul 2>&1
        if !errorlevel!==0 (
            set READY=1
            echo  [OK] Open WebUI ist bereit!
        ) else (
            set /a PROGRESS=%%i*5
            echo  Warte... ^(!PROGRESS! Sek.^)
        )
    )
)

if !READY!==0 (
    echo  [HINWEIS] Open WebUI noch nicht bereit - läuft möglicherweise noch im Hintergrund.
)

:: ============================================================
:: SCHRITT 5: Desktop App installieren
:: ============================================================
echo.
echo [5/5] Desktop App einrichten...

:: Prüfen ob winget verfügbar ist
winget --version >nul 2>&1
if %errorlevel%==0 (
    echo  Installiere Chatbox Desktop App via winget...
    winget install --id Bin-Huang.Chatbox -e --silent
    if %errorlevel%==0 (
        echo  [OK] Chatbox Desktop App installiert!
        echo       Chatbox verbindet sich mit deinem lokalen Ollama.
    ) else (
        echo  [HINWEIS] Chatbox konnte nicht automatisch installiert werden.
        call :download_chatbox
    )
) else (
    call :download_chatbox
)

:: Open WebUI PWA Shortcut auf Desktop erstellen
echo.
echo  Erstelle Open WebUI Desktop-Verknüpfung...
powershell -Command ^
  "$WshShell = New-Object -comObject WScript.Shell;" ^
  "$Shortcut = $WshShell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Open WebUI.lnk');" ^
  "$Shortcut.TargetPath = 'http://localhost:3000';" ^
  "$Shortcut.Description = 'Open WebUI - Lokales KI Interface';" ^
  "$Shortcut.Save()"

:: Start-Skript Verknüpfung erstellen
powershell -Command ^
  "$WshShell = New-Object -comObject WScript.Shell;" ^
  "$Shortcut = $WshShell.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\KI Stack starten.lnk');" ^
  "$Shortcut.TargetPath = '%~dp0start.bat';" ^
  "$Shortcut.Description = 'Ollama + Open WebUI starten';" ^
  "$Shortcut.WorkingDirectory = '%~dp0';" ^
  "$Shortcut.Save()"

echo  [OK] Desktop-Verknüpfungen erstellt

:: ============================================================
:: FERTIG
:: ============================================================
echo.
echo ============================================================
echo   SETUP ABGESCHLOSSEN!
echo ============================================================
echo.
echo   Open WebUI:    http://localhost:3000
echo   Ollama API:    http://localhost:11434
echo.
echo   Desktop Verknüpfungen auf dem Desktop erstellt:
echo    - "Open WebUI"        → Browser Interface
echo    - "KI Stack starten"  → Stack neu starten
echo.
echo   Beim ersten Öffnen: Account registrieren
echo   (erster Account = Admin)
echo.
echo ============================================================
echo.

set /p OPEN="Browser jetzt öffnen? (J/N): "
if /i "!OPEN!"=="J" start http://localhost:3000

pause
exit /b 0

:: ============================================================
:: Hilfsfunktion: Chatbox manuell herunterladen
:: ============================================================
:download_chatbox
echo.
echo  Öffne Chatbox Download-Seite...
start https://chatboxai.app/
echo  [HINWEIS] Lade Chatbox für Windows herunter und installiere es.
echo            Nach Installation: Einstellungen → AI Provider → Ollama
echo            Ollama URL: http://localhost:11434
goto :eof
