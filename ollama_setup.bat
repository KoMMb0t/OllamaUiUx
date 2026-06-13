@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo  ============================================================
echo    Ollama + Open WebUI Setup  ^|  Kommuniverse
echo  ============================================================
echo.

:: ============================================================
:: SCHRITT 1: Voraussetzungen
:: ============================================================
echo  [1/6] Pruefe Voraussetzungen...
echo.

docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [FEHLER] Docker nicht gefunden!
    echo.
    echo          Bitte Docker Desktop installieren:
    echo          https://www.docker.com/products/docker-desktop/
    echo.
    set /p _O="  Jetzt herunterladen? (J/N): "
    if /i "!_O!"=="J" start https://www.docker.com/products/docker-desktop/
    pause & exit /b 1
)
echo  [OK] Docker gefunden

docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  [WARTEN] Docker Desktop startet...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" >nul 2>&1
    timeout /t 20 /nobreak >nul
    docker info >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [FEHLER] Docker Desktop antwortet nicht. Bitte manuell starten.
        pause & exit /b 1
    )
)
echo  [OK] Docker Desktop laeuft

docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    docker compose version >nul 2>&1
    if !errorlevel! neq 0 (
        echo  [FEHLER] Docker Compose nicht gefunden. Bitte Docker Desktop aktualisieren.
        pause & exit /b 1
    )
)
echo  [OK] Docker Compose bereit
echo.

:: ============================================================
:: SCHRITT 2: .env Datei
:: ============================================================
echo  [2/6] Konfiguration einrichten...
echo.

if not exist ".env" (
    copy ".env.example" ".env" >nul
    echo  OPTIONAL: OpenRouter API Key eingeben
    echo  (Cloud-Modelle: Claude, GPT-4o, Gemini)
    echo  Registrieren: https://openrouter.ai/keys
    echo  Einfach Enter druecken zum Ueberspringen.
    echo.
    set /p ORKEY="  OpenRouter API Key: "
    if not "!ORKEY!"=="" (
        powershell -Command "(gc .env) -replace 'sk-or-xxxxxxxxxxxxxxxxxxxx','!ORKEY!' | sc .env"
        echo  [OK] API Key gespeichert
    ) else (
        echo  [SKIP] Kein API Key - nur lokale Modelle
    )
    powershell -Command "$k=[guid]::NewGuid().ToString('N'); (gc .env) -replace 'mein-geheimer-schluessel-bitte-aendern',$k | sc .env"
    echo  [OK] Sicherheitsschluessel generiert
) else (
    echo  [OK] .env bereits vorhanden
)
echo.

:: ============================================================
:: SCHRITT 3: Docker Stack starten
:: ============================================================
echo  [3/6] Starte Docker Stack...
echo        (Erster Start: Images laden, ca. 2-5 Min.)
echo.

docker compose up -d --pull always
if %errorlevel% neq 0 (
    echo  [FEHLER] Docker Compose fehlgeschlagen!
    echo          Haeufige Ursache: Port 3000 oder 11434 belegt.
    pause & exit /b 1
)
echo.
echo  [OK] Docker Stack gestartet

:: ============================================================
:: SCHRITT 4: Warten auf Open WebUI
:: ============================================================
echo.
echo  [4/6] Warte auf Open WebUI (bis zu 90 Sek.)...
echo.

set READY=0
for /l %%i in (1,1,18) do (
    if !READY!==0 (
        timeout /t 5 /nobreak >nul
        curl -sf http://localhost:3000 >nul 2>&1
        if !errorlevel!==0 (
            set READY=1
            echo  [OK] Open WebUI ist bereit!
        ) else (
            set /a EL=%%i*5
            echo        Warte... (!EL! / 90 Sek.)
        )
    )
)
if !READY!==0 (
    echo  [HINWEIS] Open WebUI noch nicht erreichbar - laeuft evtl. noch.
    echo           Pruefe: docker compose logs -f
)
echo.

:: ============================================================
:: SCHRITT 5: Chatbox installieren und verbinden
:: ============================================================
echo  [5/6] Chatbox Desktop App einrichten...
echo.

set CB=0
if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" set CB=1
if exist "%PROGRAMFILES%\Chatbox AI\Chatbox AI.exe" set CB=1

if !CB!==0 (
    echo  Chatbox nicht gefunden - installiere...
    winget --version >nul 2>&1
    if !errorlevel!==0 (
        winget install --id Bin-Huang.Chatbox -e --silent --accept-package-agreements --accept-source-agreements
        if !errorlevel!==0 set CB=1
    )
    if !CB!==0 (
        echo  Lade Chatbox direkt herunter...
        powershell -Command "$p='%TEMP%\cbsetup.exe'; iwr 'https://chatboxai.app/install.exe' -OutFile $p -UseBasicParsing; Start-Process $p '/S' -Wait"
        if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" set CB=1
    )
    if !CB!==0 (
        echo  [!!] Bitte Chatbox manuell installieren: https://chatboxai.app/
        start https://chatboxai.app/
    ) else (
        echo  [OK] Chatbox installiert
    )
) else (
    echo  [OK] Chatbox bereits installiert
)

:: Chatbox mit Ollama verbinden
echo.
echo  Verbinde Chatbox mit Ollama...
if not exist "%APPDATA%\Chatbox AI\data" mkdir "%APPDATA%\Chatbox AI\data" >nul 2>&1
set CBS=%APPDATA%\Chatbox AI\data\settings.json
powershell -Command "$c=[ordered]@{aiProvider='ollama';ollamaHost='http://localhost:11434';ollamaModel='llama3.2:3b';language='de';theme='system'}; $c | ConvertTo-Json | Set-Content '%CBS%' -Encoding UTF8"
echo  [OK] Chatbox mit Ollama verbunden (localhost:11434)

:: ============================================================
:: SCHRITT 6: Desktop-Verknuepfungen
:: ============================================================
echo.
echo  [6/6] Erstelle Desktop-Verknuepfungen...
echo.

set DSK=%USERPROFILE%\Desktop

powershell -Command "$ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut('%DSK%\Open WebUI.lnk'); $sc.TargetPath='C:\Windows\explorer.exe'; $sc.Arguments='http://localhost:3000'; $sc.Save()"
echo  [OK] Verknuepfung: Open WebUI

if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" (
    powershell -Command "$ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut('%DSK%\Chatbox AI.lnk'); $sc.TargetPath='%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe'; $sc.Save()"
    echo  [OK] Verknuepfung: Chatbox AI
)

powershell -Command "$ws=New-Object -ComObject WScript.Shell; $sc=$ws.CreateShortcut('%DSK%\KI Stack starten.lnk'); $sc.TargetPath='%~dp0start.bat'; $sc.WorkingDirectory='%~dp0'; $sc.Save()"
echo  [OK] Verknuepfung: KI Stack starten

:: ============================================================
:: STATUSPRUEFUNG
:: ============================================================
echo.
echo  Fuehre Statuspruefung durch...
echo.

set C1=0 & set C2=0 & set C3=0 & set C4=0 & set C5=0

curl -sf http://localhost:11434/api/tags >nul 2>&1
if !errorlevel!==0 set C1=1

curl -sf http://localhost:3000 >nul 2>&1
if !errorlevel!==0 set C2=1

if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" set C3=1

if exist "%CBS%" set C4=1

if exist "%DSK%\Open WebUI.lnk" set C5=1

echo  ============================================================
echo    SETUP-CHECKLISTE
echo  ============================================================
echo.
if !C1!==1 (echo   [OK] Ollama API laeuft      -^> http://localhost:11434) else (echo   [XX] Ollama API NICHT erreichbar ^| docker compose logs ollama)
if !C2!==1 (echo   [OK] Open WebUI laeuft      -^> http://localhost:3000)  else (echo   [XX] Open WebUI NICHT erreichbar ^| docker compose logs open-webui)
if !C3!==1 (echo   [OK] Chatbox AI installiert) else (echo   [!!] Chatbox fehlt -^> https://chatboxai.app/)
if !C4!==1 (echo   [OK] Chatbox mit Ollama verbunden) else (echo   [!!] Chatbox-Konfiguration fehlt)
if !C5!==1 (echo   [OK] Desktop-Verknuepfungen erstellt) else (echo   [!!] Desktop-Verknuepfungen fehlen)
echo.

set /a TOT=C1+C2+C3+C4+C5
if !TOT!==5 (echo   ^>^> ALLES ERFOLGREICH! Setup abgeschlossen.) else (echo   ^>^> Teilweise erfolgreich (!TOT!/5^) - siehe Hinweise oben.)

echo.
echo   Erste Schritte:
echo    1. http://localhost:3000 oeffnen
echo    2. Account registrieren (erster Account = Admin)
echo    3. Chatbox AI starten - direkt mit Ollama verbunden
echo.
echo   Stack steuern:
echo    Starten:  start.bat  ^|  Stoppen: stop.bat
echo    Logs:     docker compose logs -f
echo.
echo  ============================================================
echo.

set /p _B="  Open WebUI im Browser oeffnen? (J/N): "
if /i "!_B!"=="J" start http://localhost:3000

if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" (
    set /p _C="  Chatbox AI jetzt starten? (J/N): "
    if /i "!_C!"=="J" start "" "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe"
)

echo.
pause
exit /b 0
