@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

echo.
echo ╔══════════════════════════════════════════════════╗
echo ║     Self-Hosted GitLab CE  ^|  Kommuniverse       ║
echo ╚══════════════════════════════════════════════════╝
echo.

cd /d "%~dp0"

:: ── Schritt 1: Docker prüfen ──────────────────────────────────
echo [1/5] Prüfe Docker...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [FEHLER] Docker nicht gefunden!
    echo Bitte Docker Desktop installieren: https://www.docker.com/products/docker-desktop/
    pause & exit /b 1
)
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [FEHLER] Docker Desktop läuft nicht! Bitte starten.
    pause & exit /b 1
)
echo [OK] Docker bereit

:: RAM-Warnung (nur Info, kein Block)
for /f "tokens=2" %%i in ('wmic OS get TotalVisibleMemorySize /value ^| findstr "="') do set /a RAM_MB=%%i/1024
echo [INFO] RAM: !RAM_MB! MB
if !RAM_MB! LSS 4000 (
    echo [WARNUNG] Weniger als 4 GB RAM - GitLab koennte instabil sein!
    echo Empfohlen: 8 GB RAM
    set /p CONT="Trotzdem fortfahren? (J/N): "
    if /i not "!CONT!"=="J" exit /b 0
)

:: ── Schritt 2: .env konfigurieren ────────────────────────────
echo.
echo [2/5] Konfiguration einrichten...

if not exist ".env" (
    copy ".env.example" ".env" >nul

    echo.
    echo Wie soll GitLab erreichbar sein?
    echo  [1] Nur lokal ^(localhost:8929^)  <- Standard
    echo  [2] Im Netzwerk ^(LAN-IP^)
    echo  [3] Eigener Domainname
    echo.
    set /p CHOICE="Wahl (1/2/3) [1]: "
    if "!CHOICE!"=="" set CHOICE=1

    if "!CHOICE!"=="2" (
        for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /r "IPv4.*[0-9]"') do (
            set LAN_IP=%%a
            set LAN_IP=!LAN_IP: =!
            goto :gotip
        )
        :gotip
        echo Erkannte IP: !LAN_IP!
        set /p HOST="IP bestaetigen oder andere eingeben [!LAN_IP!]: "
        if "!HOST!"=="" set HOST=!LAN_IP!
    ) else if "!CHOICE!"=="3" (
        set /p HOST="Domain ^(z.B. git.meine-domain.at^): "
    ) else (
        set HOST=localhost
    )

    set /p PORT="HTTP-Port [8929]: "
    if "!PORT!"=="" set PORT=8929

    :: .env aktualisieren
    powershell -Command "(Get-Content .env) -replace 'GITLAB_HOSTNAME=localhost', 'GITLAB_HOSTNAME=!HOST!' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'GITLAB_HTTP_PORT=8929', 'GITLAB_HTTP_PORT=!PORT!' | Set-Content .env"
    echo [OK] .env konfiguriert ^(Host: !HOST!, Port: !PORT!^)
) else (
    echo [OK] .env bereits vorhanden
    for /f "tokens=2 delims==" %%a in ('findstr "GITLAB_HOSTNAME" .env') do set HOST=%%a
    for /f "tokens=2 delims==" %%a in ('findstr "GITLAB_HTTP_PORT" .env') do set PORT=%%a
)

:: ── Schritt 3: Stack starten ──────────────────────────────────
echo.
echo [3/5] GitLab Container starten ^(Image-Download kann einige Minuten dauern^)...
docker compose up -d --pull always
if %errorlevel% neq 0 (
    echo [FEHLER] Docker Compose fehlgeschlagen!
    pause & exit /b 1
)
echo [OK] Container gestartet

:: ── Schritt 4: Warten ────────────────────────────────────────
echo.
echo [4/5] Warte auf GitLab...
echo [HINWEIS] Beim ersten Start dauert es 3-5 Minuten. Bitte warten!
echo.
set READY=0
set GITLAB_URL=http://!HOST!:!PORT!

for /l %%i in (1,1,24) do (
    if !READY!==0 (
        curl -sf -o nul -w "%%{http_code}" "!GITLAB_URL!/-/health" 2>nul | findstr "200" >nul
        if !errorlevel!==0 (
            set READY=1
            echo [OK] GitLab ist bereit!
        ) else (
            set /a SECS=%%i*15
            echo   Warte... ^(!SECS! Sek.^)
            timeout /t 15 /nobreak >nul
        )
    )
)

:: ── Schritt 5: Root-Passwort ──────────────────────────────────
echo.
echo [5/5] Root-Passwort abrufen...
timeout /t 5 /nobreak >nul

for /f "tokens=2" %%p in ('docker exec gitlab grep "Password:" /etc/gitlab/initial_root_password 2^>nul') do set ROOT_PW=%%p

if defined ROOT_PW (
    echo.
    echo ╔════════════════════════════════════════╗
    echo ║  GitLab Login-Daten                    ║
    echo ╠════════════════════════════════════════╣
    echo ║  URL:      !GITLAB_URL!
    echo ║  Benutzer: root                        ║
    echo ║  Passwort: !ROOT_PW!
    echo ╚════════════════════════════════════════╝
    echo.
    echo [WICHTIG] Passwort nach erstem Login SOFORT aendern!
) else (
    echo [HINWEIS] Passwort noch nicht verfuegbar. Spaeter abrufen mit:
    echo   docker exec -it gitlab grep "Password:" /etc/gitlab/initial_root_password
)

:: ── Fertig ────────────────────────────────────────────────────
echo.
echo ╔══════════════════════════════════════════════════╗
echo ║         SETUP ABGESCHLOSSEN!                     ║
echo ╚══════════════════════════════════════════════════╝
echo.
echo   GitLab URL:  !GITLAB_URL!
echo   SSH Port:    2222
echo.
echo   Naechste Schritte:
echo    1. !GITLAB_URL! aufrufen
echo    2. Mit root + Passwort einloggen
echo    3. Passwort sofort aendern
echo    4. Erstes Projekt anlegen
echo.

set /p OPEN="Browser jetzt oeffnen? (J/N): "
if /i "!OPEN!"=="J" start !GITLAB_URL!

pause
