@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

:: ============================================================
::  Ollama + Open WebUI Setup  |  Kommuniverse
::  Vollinstallation + Desktop App (Chatbox) Verbindung
:: ============================================================

cd /d "%~dp0"

set "RED=[91m"
set "GRN=[92m"
set "YLW=[93m"
set "BLU=[94m"
set "CYN=[96m"
set "NC=[0m"

echo.
echo  %CYN%============================================================%NC%
echo  %CYN%   Ollama + Open WebUI Setup  ^|  Kommuniverse%NC%
echo  %CYN%============================================================%NC%
echo.

:: ============================================================
:: SCHRITT 1: Voraussetzungen pruefen
:: ============================================================
echo  %BLU%[1/6]%NC% Pruefe Voraussetzungen...
echo.

:: Docker pruefen
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  %RED%[FEHLER]%NC% Docker nicht gefunden!
    echo.
    echo         Bitte Docker Desktop installieren:
    echo         https://www.docker.com/products/docker-desktop/
    echo.
    echo         Nach der Installation dieses Skript erneut starten.
    echo.
    set /p _OPEN="  Docker Desktop jetzt herunterladen? (J/N): "
    if /i "!_OPEN!"=="J" start https://www.docker.com/products/docker-desktop/
    pause & exit /b 1
)
echo  %GRN%[OK]%NC%   Docker gefunden

:: Docker Desktop laeuft?
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo  %YLW%[WARTEN]%NC% Docker Desktop laeuft noch nicht -- versuche zu starten...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe" >nul 2>&1
    echo         Warte 20 Sekunden auf Docker Desktop...
    timeout /t 20 /nobreak >nul
    docker info >nul 2>&1
    if !errorlevel! neq 0 (
        echo  %RED%[FEHLER]%NC% Docker Desktop antwortet nicht.
        echo         Bitte Docker Desktop manuell starten und erneut versuchen.
        pause & exit /b 1
    )
)
echo  %GRN%[OK]%NC%   Docker Desktop laeuft

:: Docker Compose pruefen (v1 und v2 kompatibel)
docker-compose --version >nul 2>&1
set COMPOSE_OK=!errorlevel!
if !COMPOSE_OK! neq 0 (
    docker compose version >nul 2>&1
    set COMPOSE_OK=!errorlevel!
)
if !COMPOSE_OK! neq 0 (
    echo  %RED%[FEHLER]%NC% Docker Compose nicht gefunden!
    echo         Bitte Docker Desktop aktualisieren.
    pause & exit /b 1
)
echo  %GRN%[OK]%NC%   Docker Compose bereit
echo.

:: ============================================================
:: SCHRITT 2: .env Datei erstellen
:: ============================================================
echo  %BLU%[2/6]%NC% Konfiguration einrichten...
echo.

if not exist ".env" (
    copy ".env.example" ".env" >nul

    echo  +-----------------------------------------------------+
    echo  ^|  OPTIONAL: OpenRouter API Key eingeben              ^|
    echo  ^|  Cloud-Modelle: Claude, GPT-4o, Gemini             ^|
    echo  ^|  Kostenlos: https://openrouter.ai/keys              ^|
    echo  ^|  (Enter druecken zum Ueberspringen)                 ^|
    echo  +-----------------------------------------------------+
    echo.
    set /p ORKEY="  OpenRouter API Key: "

    if not "!ORKEY!"=="" (
        powershell -Command "(Get-Content .env) -replace 'sk-or-xxxxxxxxxxxxxxxxxxxx', '!ORKEY!' | Set-Content .env -Encoding UTF8"
        echo  %GRN%[OK]%NC%   OpenRouter API Key gespeichert
    ) else (
        echo  %YLW%[SKIP]%NC% Kein API Key -- nur lokale Modelle verfuegbar
    )

    :: Zufaelligen Secret Key generieren
    for /f "delims=" %%i in ('powershell -Command "[System.Guid]::NewGuid().ToString('N') + [System.Guid]::NewGuid().ToString('N')"') do set NEWKEY=%%i
    powershell -Command "(Get-Content .env) -replace 'mein-geheimer-schluessel-bitte-aendern', '!NEWKEY!' | Set-Content .env -Encoding UTF8"
    echo  %GRN%[OK]%NC%   Sicherheitsschluessel generiert
) else (
    echo  %GRN%[OK]%NC%   .env bereits vorhanden
)
echo.

:: ============================================================
:: SCHRITT 3: Docker Stack starten
:: ============================================================
echo  %BLU%[3/6]%NC% Starte Docker Stack...
echo         (Erster Start: Docker-Images werden heruntergeladen, ca. 2-5 Min.)
echo.

docker compose up -d --pull always
if %errorlevel% neq 0 (
    echo.
    echo  %RED%[FEHLER]%NC% Docker Compose fehlgeschlagen!
    echo         Pruefe die Ausgabe oben auf Fehler.
    echo         Haeufige Ursache: Port 3000 oder 11434 bereits belegt.
    pause & exit /b 1
)
echo.
echo  %GRN%[OK]%NC%   Docker Stack gestartet

:: ============================================================
:: SCHRITT 4: Auf Open WebUI warten
:: ============================================================
echo.
echo  %BLU%[4/6]%NC% Warte auf Open WebUI (bis zu 90 Sekunden)...
echo.

set READY=0
for /l %%i in (1,1,18) do (
    if !READY!==0 (
        timeout /t 5 /nobreak >nul
        curl -sf http://localhost:3000 >nul 2>&1
        if !errorlevel!==0 (
            set READY=1
            echo  %GRN%[OK]%NC%   Open WebUI ist bereit!
        ) else (
            set /a ELAPSED=%%i*5
            echo         Warte... ^(!ELAPSED! / 90 Sek.^)
        )
    )
)

if !READY!==0 (
    echo  %YLW%[HINWEIS]%NC% Open WebUI noch nicht erreichbar.
    echo            Moeglicherweise laeuft der Download noch im Hintergrund.
    echo            Pruefe: docker compose logs -f
)
echo.

:: ============================================================
:: SCHRITT 5: Chatbox Desktop App installieren & verbinden
:: ============================================================
echo  %BLU%[5/6]%NC% Chatbox Desktop App einrichten...
echo.

set CHATBOX_INSTALLED=0
set CHATBOX_CONFIG_DIR=%APPDATA%\Chatbox AI

:: Pruefen ob Chatbox bereits installiert ist
where /q chatbox >nul 2>&1 && set CHATBOX_INSTALLED=1
if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" set CHATBOX_INSTALLED=1
if exist "%PROGRAMFILES%\Chatbox AI\Chatbox AI.exe" set CHATBOX_INSTALLED=1

if !CHATBOX_INSTALLED!==0 (
    echo  Chatbox nicht gefunden -- starte Installation...
    echo.

    :: Versuche winget (Windows 11 / aktuelles Win10)
    winget --version >nul 2>&1
    if !errorlevel!==0 (
        echo  Installiere via winget...
        winget install --id Bin-Huang.Chatbox -e --silent --accept-package-agreements --accept-source-agreements
        if !errorlevel!==0 (
            echo  %GRN%[OK]%NC%   Chatbox via winget installiert
            set CHATBOX_INSTALLED=1
        ) else (
            echo  %YLW%[HINWEIS]%NC% winget-Installation fehlgeschlagen, lade manuell herunter...
        )
    )

    :: Fallback: Direkt-Download via PowerShell
    if !CHATBOX_INSTALLED!==0 (
        echo  Lade Chatbox Installer herunter...
        set CHATBOX_INSTALLER=%TEMP%\ChatboxSetup.exe
        powershell -Command "& { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri 'https://chatboxai.app/install.exe' -OutFile '!CHATBOX_INSTALLER!' -UseBasicParsing }" >nul 2>&1
        if exist "!CHATBOX_INSTALLER!" (
            echo  Installiere Chatbox...
            start /wait "" "!CHATBOX_INSTALLER!" /S
            del /f /q "!CHATBOX_INSTALLER!" >nul 2>&1
            if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" (
                echo  %GRN%[OK]%NC%   Chatbox installiert
                set CHATBOX_INSTALLED=1
            )
        )
    )

    :: Letzter Fallback: Browser oeffnen
    if !CHATBOX_INSTALLED!==0 (
        echo  %YLW%[MANUELL]%NC% Bitte Chatbox manuell installieren:
        echo             https://chatboxai.app/
        start https://chatboxai.app/
    )
) else (
    echo  %GRN%[OK]%NC%   Chatbox bereits installiert
)

:: --- Chatbox automatisch mit Ollama verbinden ---
echo.
echo  Verbinde Chatbox mit lokalem Ollama (http://localhost:11434)...

:: Chatbox speichert Einstellungen als JSON in AppData
set CHATBOX_SETTINGS=%APPDATA%\Chatbox AI\data\settings.json

:: Warte kurz falls Chatbox gerade frisch installiert wurde
timeout /t 3 /nobreak >nul

:: Verzeichnis anlegen falls nicht vorhanden
if not exist "%APPDATA%\Chatbox AI\data" (
    mkdir "%APPDATA%\Chatbox AI\data" >nul 2>&1
)

:: Pruefen ob settings.json bereits existiert
if exist "%CHATBOX_SETTINGS%" (
    :: Vorhandene Einstellungen: Ollama-URL patchen ohne andere Werte zu ueberschreiben
    powershell -Command ^
        "$s = Get-Content '%CHATBOX_SETTINGS%' -Raw | ConvertFrom-Json;" ^
        "if (-not $s.PSObject.Properties['ollamaHost']) { $s | Add-Member -NotePropertyName 'ollamaHost' -NotePropertyValue 'http://localhost:11434' } else { $s.ollamaHost = 'http://localhost:11434' };" ^
        "if (-not $s.PSObject.Properties['aiProvider']) { $s | Add-Member -NotePropertyName 'aiProvider' -NotePropertyValue 'ollama' } else { $s.aiProvider = 'ollama' };" ^
        "if (-not $s.PSObject.Properties['ollamaModel']) { $s | Add-Member -NotePropertyName 'ollamaModel' -NotePropertyValue 'llama3.2:3b' };" ^
        "$s | ConvertTo-Json -Depth 10 | Set-Content '%CHATBOX_SETTINGS%' -Encoding UTF8" >nul 2>&1
    echo  %GRN%[OK]%NC%   Chatbox-Einstellungen aktualisiert (Ollama verbunden)
) else (
    :: Neue settings.json mit Ollama als Standard-Provider anlegen
    powershell -Command ^
        "$cfg = [ordered]@{" ^
        "  aiProvider = 'ollama';" ^
        "  ollamaHost = 'http://localhost:11434';" ^
        "  ollamaModel = 'llama3.2:3b';" ^
        "  language = 'de';" ^
        "  sendMessageShortcut = 'Enter';" ^
        "  theme = 'system'" ^
        "};" ^
        "$cfg | ConvertTo-Json | Set-Content '%CHATBOX_SETTINGS%' -Encoding UTF8" >nul 2>&1
    echo  %GRN%[OK]%NC%   Chatbox-Konfiguration erstellt (Ollama als Standard)
)

:: ============================================================
:: SCHRITT 6: Desktop-Verknuepfungen erstellen
:: ============================================================
echo.
echo  %BLU%[6/6]%NC% Erstelle Desktop-Verknuepfungen...
echo.

:: Open WebUI Verknuepfung
powershell -Command ^
    "$ws = New-Object -ComObject WScript.Shell;" ^
    "$sc = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Open WebUI.lnk');" ^
    "$sc.TargetPath = 'C:\Windows\explorer.exe';" ^
    "$sc.Arguments = 'http://localhost:3000';" ^
    "$sc.Description = 'Open WebUI -- Lokales KI Interface';" ^
    "$sc.IconLocation = 'C:\Windows\System32\shell32.dll,14';" ^
    "$sc.Save()" >nul 2>&1
echo  %GRN%[OK]%NC%   Verknuepfung: "Open WebUI" (Desktop)

:: Chatbox Verknuepfung (falls installiert)
if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" (
    powershell -Command ^
        "$ws = New-Object -ComObject WScript.Shell;" ^
        "$sc = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Chatbox AI.lnk');" ^
        "$sc.TargetPath = '%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe';" ^
        "$sc.Description = 'Chatbox AI -- Desktop Client fuer Ollama';" ^
        "$sc.Save()" >nul 2>&1
    echo  %GRN%[OK]%NC%   Verknuepfung: "Chatbox AI" (Desktop)
)

:: KI Stack starten Verknuepfung
powershell -Command ^
    "$ws = New-Object -ComObject WScript.Shell;" ^
    "$sc = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\KI Stack starten.lnk');" ^
    "$sc.TargetPath = '%~dp0start.bat';" ^
    "$sc.WorkingDirectory = '%~dp0';" ^
    "$sc.Description = 'Ollama + Open WebUI starten';" ^
    "$sc.IconLocation = 'C:\Windows\System32\shell32.dll,137';" ^
    "$sc.Save()" >nul 2>&1
echo  %GRN%[OK]%NC%   Verknuepfung: "KI Stack starten" (Desktop)

:: ============================================================
:: FERTIG -- Statuspruefung
:: ============================================================
echo.
echo  %BLU%Fuehre finale Statuspruefung durch...%NC%
echo.

:: Ollama API pruefen
set CHECK_OLLAMA=0
curl -sf http://localhost:11434/api/tags >nul 2>&1
if !errorlevel!==0 set CHECK_OLLAMA=1

:: Open WebUI pruefen
set CHECK_WEBUI=0
curl -sf http://localhost:3000 >nul 2>&1
if !errorlevel!==0 set CHECK_WEBUI=1

:: Chatbox pruefen
set CHECK_CHATBOX=0
if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" set CHECK_CHATBOX=1

:: Chatbox-Konfiguration pruefen
set CHECK_CONFIG=0
if exist "%APPDATA%\Chatbox AI\data\settings.json" (
    powershell -Command "if ((Get-Content '%APPDATA%\Chatbox AI\data\settings.json' -Raw) -match 'localhost:11434') { exit 0 } else { exit 1 }" >nul 2>&1
    if !errorlevel!==0 set CHECK_CONFIG=1
)

:: Desktop-Verknuepfungen pruefen
set CHECK_LINKS=0
if exist "%USERPROFILE%\Desktop\Open WebUI.lnk" set CHECK_LINKS=1

echo  %GRN%============================================================%NC%
echo  %GRN%   SETUP-CHECKLISTE%NC%
echo  %GRN%============================================================%NC%
echo.

if !CHECK_OLLAMA!==1 (
    echo   %GRN%[OK]%NC% Ollama API laeuft       -^> http://localhost:11434
) else (
    echo   %RED%[XX]%NC% Ollama API NICHT erreichbar
    echo       Pruefe mit: docker compose logs ollama
)

if !CHECK_WEBUI!==1 (
    echo   %GRN%[OK]%NC% Open WebUI laeuft       -^> http://localhost:3000
) else (
    echo   %RED%[XX]%NC% Open WebUI NICHT erreichbar
    echo       Pruefe mit: docker compose logs open-webui
)

if !CHECK_CHATBOX!==1 (
    echo   %GRN%[OK]%NC% Chatbox AI installiert
) else (
    echo   %YLW%[!!]%NC% Chatbox AI nicht gefunden -^> manuell: https://chatboxai.app/
)

if !CHECK_CONFIG!==1 (
    echo   %GRN%[OK]%NC% Chatbox mit Ollama verbunden (localhost:11434)
) else (
    echo   %YLW%[!!]%NC% Chatbox-Konfiguration fehlt
    echo       Manuell: Chatbox -^> Einstellungen -^> AI Provider -^> Ollama
    echo       Ollama Host: http://localhost:11434
)

if !CHECK_LINKS!==1 (
    echo   %GRN%[OK]%NC% Desktop-Verknuepfungen erstellt
) else (
    echo   %YLW%[!!]%NC% Desktop-Verknuepfungen fehlen
)

echo.

:: Gesamtstatus
set /a TOTAL=CHECK_OLLAMA+CHECK_WEBUI+CHECK_CHATBOX+CHECK_CONFIG+CHECK_LINKS
if !TOTAL!==5 (
    echo   %GRN%^>^> Alles erfolgreich! Setup vollstaendig abgeschlossen.%NC%
) else if !TOTAL! geq 3 (
    echo   %YLW%^>^> Teilweise erfolgreich ^(!TOTAL!/5^). Siehe Hinweise oben.%NC%
) else (
    echo   %RED%^>^> Fehler aufgetreten ^(!TOTAL!/5^). Bitte Hinweise oben beachten.%NC%
)

echo.
echo   %CYN%Erste Schritte:%NC%
echo    1. http://localhost:3000 oeffnen
echo    2. Account registrieren (erster Account = Admin)
echo    3. Chatbox AI starten -^> direkt mit Ollama verbunden
echo.
echo   %CYN%Stack steuern:%NC%
echo    Starten:  start.bat
echo    Stoppen:  stop.bat
echo    Logs:     docker compose logs -f
echo.
echo  %GRN%============================================================%NC%
echo.

set /p _BROWSER="  Open WebUI im Browser oeffnen? (J/N): "
if /i "!_BROWSER!"=="J" start http://localhost:3000

:: Chatbox starten falls installiert
if exist "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe" (
    set /p _CHATBOX="  Chatbox AI jetzt starten? (J/N): "
    if /i "!_CHATBOX!"=="J" (
        start "" "%LOCALAPPDATA%\Programs\Chatbox AI\Chatbox AI.exe"
    )
)

echo.
pause
exit /b 0
