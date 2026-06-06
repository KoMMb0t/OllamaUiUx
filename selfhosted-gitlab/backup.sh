#!/usr/bin/env bash
# ============================================================
#  GitLab Backup-Skript
#  Erstellt ein vollständiges Backup von GitLab
#  Empfohlen: täglich per Cronjob ausführen
#
#  Cronjob einrichten (täglich um 2 Uhr nachts):
#    crontab -e
#    0 2 * * * /pfad/zu/diesem/backup.sh >> /var/log/gitlab-backup.log 2>&1
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${SCRIPT_DIR}/backups"
mkdir -p "$BACKUP_DIR"

echo "============================================"
echo "  GitLab Backup – $TIMESTAMP"
echo "============================================"

# ── GitLab Backup erstellen ───────────────────────────────────
echo "[1/3] Erstelle GitLab Backup..."
docker exec gitlab gitlab-backup create SKIP=registry GZIP_RSYNCABLE=yes
echo "[OK] GitLab Backup erstellt"

# ── Konfig-Dateien sichern (WICHTIG für Restore!) ────────────
echo "[2/3] Sichere Konfigurationsdateien..."
docker exec gitlab tar czf - \
  /etc/gitlab/gitlab.rb \
  /etc/gitlab/gitlab-secrets.json \
  2>/dev/null > "${BACKUP_DIR}/gitlab-config-${TIMESTAMP}.tar.gz"
echo "[OK] Konfiguration gesichert"

# ── Alte Backups aufräumen (älter als 7 Tage) ─────────────────
echo "[3/3] Räume alte Backups auf..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true
echo "[OK] Alte Backups entfernt"

echo ""
echo "Backup abgeschlossen: ${BACKUP_DIR}/gitlab-config-${TIMESTAMP}.tar.gz"
echo "GitLab-Daten-Backup: Im Docker Volume gitlab_data unter /var/opt/gitlab/backups/"
