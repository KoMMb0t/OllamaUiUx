# OllamaUiUx

> Vollständiges Setup für lokale KI mit grafischem Interface — Ollama + Open WebUI + OpenRouter in einem Skript.

## Was ist das?

Ein All-in-One Setup-Paket, das folgende Komponenten installiert und konfiguriert:

| Komponente | Beschreibung |
|---|---|
| **[Ollama](https://ollama.com)** | Lokaler LLM-Server (läuft komplett offline) |
| **[Open WebUI](https://github.com/open-webui/open-webui)** | ChatGPT-artiges Browser-Interface |
| **[OpenRouter](https://openrouter.ai)** | Optionale Cloud-Modelle (Claude, GPT-4, etc.) |
| **Desktop App** | Chatbox (Win/Mac) oder AnythingLLM (Linux) |

## Schnellstart

### Windows
```bat
setup.bat
```

### Linux / macOS / WSL
```bash
chmod +x setup.sh
./setup.sh
```

Nach dem Setup: **http://localhost:3000** im Browser öffnen.

---

## Voraussetzungen

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installiert und gestartet
- Ca. 5–10 GB freier Speicherplatz (für Modelle)
- Optional: [OpenRouter API Key](https://openrouter.ai/keys) für Cloud-Modelle

---

## Konfiguration

### .env Datei
```bash
cp .env.example .env
# Dann in .env deinen OpenRouter API Key eintragen
```

### Standard-Modelle
Beim ersten Start werden automatisch heruntergeladen:
- `llama3.2:3b` (~2 GB, schnell, gut für Alltag)
- `mistral:7b` (~4 GB, stärker, mehr RAM nötig)

Weitere Modelle direkt in Open WebUI unter **Settings → Models** hinzufügen.

---

## Stack steuern

| Aktion | Windows | Linux/Mac |
|---|---|---|
| Starten | `start.bat` | `./start.sh` |
| Stoppen | `stop.bat` | `./stop.sh` |
| Logs anzeigen | `docker compose logs -f` | `docker compose logs -f` |
| Aktualisieren | `docker compose pull && docker compose up -d` | gleich |

---

## GPU-Support (NVIDIA)

In `docker-compose.yml` den `deploy`-Block beim `ollama`-Service einkommentieren:

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

---

## OpenRouter / Cloud-Modelle

In Open WebUI unter **Settings → Connections → OpenAI API**:
- URL: `https://openrouter.ai/api/v1`
- Key: Dein OpenRouter API Key

Dann alle verfügbaren Modelle (Claude, GPT-4o, Gemini, etc.) direkt im Interface nutzbar.

---

## Ports

| Service | Port | URL |
|---|---|---|
| Open WebUI | 3000 | http://localhost:3000 |
| Ollama API | 11434 | http://localhost:11434 |

---

## Troubleshooting

**Docker startet nicht:**
```bash
docker info  # Fehlermeldung anzeigen
```

**Modell lädt nicht:**
```bash
docker exec -it ollama ollama pull llama3.2:3b
```

**Open WebUI findet Ollama nicht:**
→ Sicherstellen dass beide Container im selben Docker-Netzwerk laufen (`docker compose up`)

---

## Lizenz

MIT – frei verwendbar, anpassbar, verteilbar.

---

*Erstellt von [Kommuniverse](https://github.com/kommuniverse)*
