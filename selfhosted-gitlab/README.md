# Self-Hosted GitLab CE

> Vollständiges Setup für ein eigenes GitLab — komplett lokal, keine Cloud, keine Abhängigkeiten.

---

## Mindestanforderungen

| Ressource | Minimum | Empfohlen |
|---|---|---|
| RAM | 4 GB | 8 GB |
| CPU | 2 Kerne | 4 Kerne |
| Speicher | 40 GB | 100 GB SSD |
| Docker | 24.0+ | aktuell |

> GitLab ist ressourcenhungrig — auf einem Raspberry Pi oder schwachen VMs wird es langsam.

---

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

Das Skript:
- prüft Docker & RAM
- fragt nach deiner gewünschten URL/IP
- startet GitLab + Runner in Docker
- wartet bis GitLab bereit ist
- zeigt Root-Passwort an

---

## Manuelle Installation

### 1. .env Datei anlegen
```bash
cp .env.example .env
# GITLAB_HOSTNAME auf deine IP oder Domain setzen
nano .env
```

### 2. Starten
```bash
docker compose up -d
```

### 3. Warten (~5 Minuten beim ersten Start)
```bash
docker compose logs -f gitlab
# Warten bis: "gitlab Reconfigured!"
```

### 4. Root-Passwort holen
```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

### 5. Einloggen
Öffne `http://localhost:8929` → Benutzer: `root` → Passwort aus Schritt 4

---

## Nächste Schritte nach der Installation

### Passwort ändern
`root` → Profil oben rechts → **Edit Profile** → **Password**

### Eigenen Account anlegen
**Admin Area** → **Users** → **New User**

### Ersten Repository anlegen
**New Project** → Name eingeben → **Create project**

### SSH Key hinzufügen (für bequemes Pushen)
```bash
# Lokaler SSH Key generieren (falls noch keiner vorhanden)
ssh-keygen -t ed25519 -C "deine@email.at"

# Public Key anzeigen
cat ~/.ssh/id_ed25519.pub
```
In GitLab: **Profil** → **SSH Keys** → Key einfügen

### Ersten Push
```bash
git clone git@localhost:root/mein-projekt.git
# oder per HTTPS:
git clone http://localhost:8929/root/mein-projekt.git
```

---

## CI/CD Runner einrichten

```bash
bash register-runner.sh
```

Oder manuell: **Admin Area** → **CI/CD** → **Runners** → **New instance runner** → Token kopieren

### Beispiel `.gitlab-ci.yml`
```yaml
stages:
  - build
  - test

build-job:
  stage: build
  image: node:20
  script:
    - echo "Build läuft..."
    - npm install
    - npm run build

test-job:
  stage: test
  script:
    - echo "Tests laufen..."
    - npm test
```

---

## Stack steuern

```bash
# Starten
docker compose up -d

# Stoppen
docker compose down

# Neustarten
docker compose restart gitlab

# Logs anzeigen
docker compose logs -f gitlab

# GitLab aktualisieren
docker compose pull
docker compose up -d

# Status prüfen
docker compose ps
```

---

## Ports

| Service | Port | Beschreibung |
|---|---|---|
| Web-Interface | 8929 | `http://localhost:8929` |
| HTTPS | 8443 | Optional, mit SSL-Zertifikat |
| SSH (Git) | 2222 | `git@localhost:2222` |

> Ports können in `.env` geändert werden.

---

## Backup & Restore

### Backup erstellen
```bash
bash backup.sh
# oder manuell:
docker exec gitlab gitlab-backup create
```

### Backup wiederherstellen
```bash
# Backup in Container kopieren
docker cp backup_file.tar gitlab:/var/opt/gitlab/backups/

# Restore ausführen
docker exec -it gitlab gitlab-backup restore BACKUP=timestamp_gitlab_backup
```

**Wichtig:** Immer auch `/etc/gitlab/gitlab-secrets.json` sichern!

---

## Häufige Probleme

### GitLab startet nicht / hängt beim Laden
```bash
docker compose logs gitlab | tail -50
# Häufigste Ursache: zu wenig RAM
```

### Passwort vergessen
```bash
docker exec -it gitlab gitlab-rails console
# In der Console:
user = User.find_by_username('root')
user.password = 'NeuesPasswort123!'
user.password_confirmation = 'NeuesPasswort123!'
user.save!
exit
```

### Port bereits belegt
```bash
# Anderen Port in .env setzen:
GITLAB_HTTP_PORT=9090
```

### Git push über SSH schlägt fehl
```bash
# SSH Config prüfen (~/.ssh/config)
Host localhost
  HostName localhost
  Port 2222
  User git
```

---

## Performance optimieren (für 4 GB RAM)

In `docker-compose.yml` im `GITLAB_OMNIBUS_CONFIG`-Block einkommentieren:
```ruby
puma['worker_processes'] = 2
sidekiq['concurrency'] = 5
postgresql['shared_buffers'] = "256MB"
postgresql['max_connections'] = 100
prometheus_monitoring['enable'] = false
```

Dann neu starten: `docker compose restart gitlab`

---

## Nützliche Befehle

```bash
# GitLab-Status prüfen
docker exec -it gitlab gitlab-ctl status

# GitLab neu konfigurieren (nach Änderungen)
docker exec -it gitlab gitlab-ctl reconfigure

# GitLab-Konsole öffnen (wie Rails console)
docker exec -it gitlab gitlab-rails console

# Speicherverbrauch anzeigen
docker stats gitlab
```

---

*Erstellt von [Kommuniverse](https://github.com/kommuniverse)*
