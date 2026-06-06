#!/usr/bin/env bash
# ============================================================
#  Self-Hosted GitLab CE – Vollständiges Setup-Skript
#  Für Linux, macOS, WSL
#  Kommuniverse Setup
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Farben
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[HINT]${NC}  $1"; }
error()   { echo -e "${RED}[FEHLER]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}━━━ $1 ━━━${NC}"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     Self-Hosted GitLab CE  |  Kommuniverse       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Schritt 1: Systemprüfung ──────────────────────────────────
step "Schritt 1: Systemprüfung"

# RAM prüfen
TOTAL_RAM_MB=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
if [ "$TOTAL_RAM_MB" -lt 3800 ]; then
  warn "Weniger als 4 GB RAM erkannt (${TOTAL_RAM_MB} MB)."
  warn "GitLab läuft möglicherweise instabil. Empfohlen: 8 GB."
  read -rp "  Trotzdem fortfahren? (j/N): " CONT
  [[ "$CONT" =~ ^[jJyY]$ ]] || exit 0
else
  success "RAM: ${TOTAL_RAM_MB} MB"
fi

# Docker prüfen
command -v docker &>/dev/null    || error "Docker nicht gefunden! → https://docs.docker.com/get-docker/"
docker info &>/dev/null          || error "Docker läuft nicht! Bitte starten."
success "Docker bereit"

# Docker Compose prüfen
docker compose version &>/dev/null || error "Docker Compose V2 nicht gefunden!"
success "Docker Compose bereit"

# ── Schritt 2: Konfiguration ──────────────────────────────────
step "Schritt 2: Konfiguration"

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ""
  echo "  Wie soll GitLab erreichbar sein?"
  echo "  ─────────────────────────────────────────────"
  echo "  [1] Nur lokal (localhost:8929)      ← Standard"
  echo "  [2] Im Netzwerk (LAN IP)"
  echo "  [3] Mit eigenem Domainnamen"
  echo ""
  read -rp "  Wahl (1/2/3) [1]: " CHOICE
  CHOICE="${CHOICE:-1}"

  case "$CHOICE" in
    2)
      # LAN IP automatisch erkennen
      LAN_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1 | awk '{print $7}' | head -1)
      echo ""
      info "Erkannte LAN-IP: $LAN_IP"
      read -rp "  IP bestätigen oder andere eingeben [$LAN_IP]: " INPUT_IP
      HOST="${INPUT_IP:-$LAN_IP}"
      sed -i "s|GITLAB_HOSTNAME=localhost|GITLAB_HOSTNAME=$HOST|g" .env
      ;;
    3)
      read -rp "  Domain (z.B. git.meine-domain.at): " HOST
      sed -i "s|GITLAB_HOSTNAME=localhost|GITLAB_HOSTNAME=$HOST|g" .env
      ;;
    *)
      HOST="localhost"
      ;;
  esac

  read -rp "  HTTP-Port [8929]: " PORT
  PORT="${PORT:-8929}"
  sed -i "s|GITLAB_HTTP_PORT=8929|GITLAB_HTTP_PORT=$PORT|g" .env

  success ".env konfiguriert (Host: ${HOST:-localhost}, Port: $PORT)"
else
  success ".env bereits vorhanden"
  HOST=$(grep GITLAB_HOSTNAME .env | cut -d= -f2)
  PORT=$(grep GITLAB_HTTP_PORT .env | cut -d= -f2)
fi

# ── Schritt 3: Docker Stack starten ──────────────────────────
step "Schritt 3: GitLab Container starten"

info "Image herunterladen und starten (kann einige Minuten dauern)..."
docker compose up -d --pull always
success "Container gestartet"

# ── Schritt 4: Auf GitLab warten ─────────────────────────────
step "Schritt 4: Warten bis GitLab bereit ist"

echo ""
warn "GitLab braucht beim ERSTEN Start ca. 3–5 Minuten."
warn "Bitte Geduld — das ist normal."
echo ""

GITLAB_URL="http://${HOST:-localhost}:${PORT:-8929}"
READY=0
for i in $(seq 1 24); do
  STATUS=$(curl -sf -o /dev/null -w "%{http_code}" "$GITLAB_URL/-/health" 2>/dev/null || echo "000")
  if [ "$STATUS" = "200" ]; then
    READY=1
    success "GitLab ist bereit!"
    break
  fi
  SECS=$((i * 15))
  echo -e "  ${YELLOW}Warte...${NC} ($SECS Sek.) [Status: $STATUS]"
  sleep 15
done

if [ "$READY" = "0" ]; then
  warn "GitLab noch nicht bereit nach 6 Minuten."
  warn "Logs prüfen mit: docker compose logs -f gitlab"
fi

# ── Schritt 5: Root-Passwort anzeigen ────────────────────────
step "Schritt 5: Root-Passwort abrufen"

echo ""
info "Versuche Root-Passwort abzurufen..."
sleep 5

ROOT_PW=$(docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password 2>/dev/null | awk '{print $2}' || echo "")

if [ -n "$ROOT_PW" ]; then
  echo ""
  echo -e "  ${GREEN}${BOLD}╔════════════════════════════════════╗${NC}"
  echo -e "  ${GREEN}${BOLD}║  GitLab Login-Daten               ║${NC}"
  echo -e "  ${GREEN}${BOLD}╠════════════════════════════════════╣${NC}"
  echo -e "  ${GREEN}${BOLD}║  URL:      ${GITLAB_URL}          ║${NC}"
  echo -e "  ${GREEN}${BOLD}║  Benutzer: root                    ║${NC}"
  echo -e "  ${GREEN}${BOLD}║  Passwort: ${ROOT_PW}  ║${NC}"
  echo -e "  ${GREEN}${BOLD}╚════════════════════════════════════╝${NC}"
  echo ""
  warn "Passwort nach erstem Login SOFORT ändern!"
  warn "Die Datei /etc/gitlab/initial_root_password wird nach 24h gelöscht."
else
  warn "Passwort noch nicht verfügbar. Nach dem Login-Bildschirm abrufen mit:"
  echo "  docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password"
fi

# ── Schritt 6: GitLab Runner registrieren ────────────────────
step "Schritt 6: CI/CD Runner (optional)"

echo ""
read -rp "  GitLab Runner jetzt registrieren? (j/N): " REG_RUNNER
if [[ "$REG_RUNNER" =~ ^[jJyY]$ ]]; then
  echo ""
  warn "Gehe zu: ${GITLAB_URL}/admin/runners"
  warn "Klicke auf 'New instance runner' und kopiere den Registration Token."
  echo ""
  read -rp "  Registration Token einfügen: " RUNNER_TOKEN
  if [ -n "$RUNNER_TOKEN" ]; then
    docker exec -it gitlab-runner gitlab-runner register \
      --url "$GITLAB_URL" \
      --token "$RUNNER_TOKEN" \
      --executor "docker" \
      --docker-image "alpine:latest" \
      --description "Local Docker Runner" \
      --non-interactive
    success "Runner registriert!"
  fi
else
  info "Runner kann später mit: bash register-runner.sh registriert werden."
fi

# ── Fertig ────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║         SETUP ABGESCHLOSSEN!                     ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  GitLab URL:    $GITLAB_URL"
echo "  SSH Clone:     git@${HOST:-localhost}:${PORT:-2222}"
echo ""
echo "  Nächste Schritte:"
echo "   1. $GITLAB_URL aufrufen"
echo "   2. Mit root + Passwort oben einloggen"
echo "   3. Passwort sofort ändern"
echo "   4. Neuen Benutzer für dich anlegen (optional)"
echo "   5. Erstes Projekt erstellen"
echo ""
echo "  Stack steuern:"
echo "    docker compose up -d      → starten"
echo "    docker compose down       → stoppen"
echo "    docker compose logs -f    → Logs"
echo "    bash backup.sh            → Backup erstellen"
echo ""

read -rp "  Browser jetzt öffnen? (j/N): " OPEN
[[ "$OPEN" =~ ^[jJyY]$ ]] && (xdg-open "$GITLAB_URL" 2>/dev/null || open "$GITLAB_URL" 2>/dev/null || true)
