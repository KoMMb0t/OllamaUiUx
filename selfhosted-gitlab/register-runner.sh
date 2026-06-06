#!/usr/bin/env bash
# ============================================================
#  GitLab Runner registrieren
#  Ausführen NACHDEM GitLab läuft
#
#  Token findest du unter:
#  GitLab → Admin → CI/CD → Runners → New instance runner
# ============================================================

cd "$(dirname "${BASH_SOURCE[0]}")"
source .env 2>/dev/null || true

GITLAB_URL="http://${GITLAB_HOSTNAME:-localhost}:${GITLAB_HTTP_PORT:-8929}"

echo ""
echo "GitLab Runner Registrierung"
echo "═══════════════════════════"
echo ""
echo "1. Gehe zu: ${GITLAB_URL}/admin/runners"
echo "2. Klicke auf 'New instance runner'"
echo "3. Kopiere den Registration Token"
echo ""
read -rp "Registration Token: " TOKEN

if [ -z "$TOKEN" ]; then
  echo "Kein Token eingegeben. Abbruch."
  exit 1
fi

docker exec -it gitlab-runner gitlab-runner register \
  --url "$GITLAB_URL" \
  --token "$TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "Local Docker Runner – $(hostname)" \
  --non-interactive

echo ""
echo "[OK] Runner erfolgreich registriert!"
echo "     Prüfen unter: ${GITLAB_URL}/admin/runners"
