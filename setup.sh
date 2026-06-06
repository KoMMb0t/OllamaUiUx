#!/usr/bin/env bash
# ============================================================
#  Ollama + Open WebUI Setup für Linux/macOS/WSL
#  Kommuniverse Setup
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[HINT]${NC} $1"; }
error()   { echo -e "${RED}[FEHLER]${NC} $1"; exit 1; }

echo ""
echo "============================================================"
echo "  Ollama + Open WebUI Setup  |  Kommuniverse"
echo "============================================================"
echo ""

# ── Schritt 1: Voraussetzungen ────────────────────────────────
info "Prüfe Voraussetzungen..."

command -v docker &>/dev/null || error "Docker nicht installiert! → https://docs.docker.com/get-docker/"
docker info &>/dev/null      || error "Docker läuft nicht! Bitte starten."
success "Docker bereit"

command -v docker compose &>/dev/null || \
  docker-compose version &>/dev/null  || \
  error "Docker Compose nicht gefunden!"
success "Docker Compose bereit"

# ── Schritt 2: .env Datei ─────────────────────────────────────
info "Konfiguration einrichten..."

if [ ! -f ".env" ]; then
  cp .env.example .env
  echo ""
  echo "  ─────────────────────────────────────────────────"
  echo "  OpenRouter API Key eingeben (oder Enter überspringen)"
  echo "  https://openrouter.ai/keys"
  echo "  ─────────────────────────────────────────────────"
  read -rp "  OpenRouter API Key: " ORKEY
  if [ -n "$ORKEY" ]; then
    sed -i "s|sk-or-xxxxxxxxxxxxxxxxxxxx|$ORKEY|g" .env
    success "API Key gespeichert"
  else
    warn "Kein API Key eingegeben. Später in .env eintragen."
  fi
  # Zufälligen Secret Key generieren
  NEWKEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || date +%s%N | sha256sum | head -c 40)
  sed -i "s|mein-geheimer-schluessel-bitte-aendern|$NEWKEY|g" .env
  success "Sicherheitsschlüssel generiert"
else
  success ".env bereits vorhanden"
fi

# ── Schritt 3: Docker Stack starten ──────────────────────────
echo ""
info "Starte Docker Stack..."
docker compose up -d --pull always
success "Stack gestartet"

# ── Schritt 4: Warten bis bereit ─────────────────────────────
echo ""
info "Warte auf Open WebUI..."
for i in {1..12}; do
  if curl -sf http://localhost:3000 &>/dev/null; then
    success "Open WebUI ist bereit!"
    break
  fi
  echo "  Warte... ($((i*5)) Sek.)"
  sleep 5
done

# ── Schritt 5: Desktop App installieren ──────────────────────
echo ""
info "Desktop App installieren..."

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
  # macOS
  if command -v brew &>/dev/null; then
    info "Installiere Chatbox via Homebrew..."
    brew install --cask chatbox && success "Chatbox installiert!" || \
      warn "Homebrew-Installation fehlgeschlagen. Manuell: https://chatboxai.app/"
  else
    warn "Homebrew nicht gefunden. Chatbox manuell herunterladen: https://chatboxai.app/"
    open "https://chatboxai.app/" 2>/dev/null || true
  fi

elif [ "$OS" = "Linux" ]; then
  # Prüfen ob WSL
  if grep -qi microsoft /proc/version 2>/dev/null; then
    warn "WSL erkannt – Desktop App auf Windows-Seite installieren."
    warn "→ Chatbox: https://chatboxai.app/"
    warn "→ Open WebUI Desktop: https://github.com/open-webui/desktop/releases"
  else
    # Linux native
    info "Lade AnythingLLM Desktop AppImage herunter..."
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
    curl -fsSL https://cdn.anythingllm.com/latest/installer.sh -o /tmp/anythingllm-installer.sh
    chmod +x /tmp/anythingllm-installer.sh
    ANYTHING_LLM_INSTALL_DIR="$INSTALL_DIR" bash /tmp/anythingllm-installer.sh && \
      success "AnythingLLM Desktop installiert in $INSTALL_DIR" || \
      warn "Installation fehlgeschlagen. Manuell: https://anythingllm.com/desktop"
    rm -f /tmp/anythingllm-installer.sh
  fi
fi

# ── Desktop Verknüpfung für Open WebUI ───────────────────────
if [ "$OS" = "Linux" ] && [ -d "$HOME/.local/share/applications" ]; then
  cat > "$HOME/.local/share/applications/open-webui.desktop" << EOF
[Desktop Entry]
Name=Open WebUI
Comment=Lokales KI Interface
Exec=xdg-open http://localhost:3000
Icon=internet-web-browser
Terminal=false
Type=Application
Categories=Network;AI;
EOF
  success "Desktop-Eintrag erstellt (Open WebUI)"
fi

# ── Fertig ────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  SETUP ABGESCHLOSSEN!"
echo "============================================================"
echo ""
echo "  Open WebUI:    http://localhost:3000"
echo "  Ollama API:    http://localhost:11434"
echo ""
echo "  Stack steuern:"
echo "    Starten:  bash start.sh"
echo "    Stoppen:  bash stop.sh"
echo "    Logs:     docker compose logs -f"
echo ""
echo "  Beim ersten Öffnen: Account registrieren"
echo "  (erster Account = Admin)"
echo "============================================================"
echo ""

read -rp "  Browser jetzt öffnen? (j/N): " OPEN
if [[ "$OPEN" =~ ^[jJyY]$ ]]; then
  if [ "$OS" = "Darwin" ]; then
    open http://localhost:3000
  else
    xdg-open http://localhost:3000 2>/dev/null || \
    sensible-browser http://localhost:3000 2>/dev/null || \
    warn "Bitte http://localhost:3000 im Browser öffnen"
  fi
fi
