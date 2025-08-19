#!/bin/sh

LOGFILE="/var/log/borgbackup/backup-$(date +'%Y-%m-%d').log"

# Schreibe alles in Logfile und auf stdout
exec > >(tee -a "$LOGFILE") 2>&1

echo "[$(date)] === Backup gestartet ==="

health_ping() {
  if [ -n "$HEALTHCHECK_URL" ]; then
    if [ "$1" = "fail" ]; then
      curl -fsS "$HEALTHCHECK_URL/fail" -m 10 || true
    else
      curl -fsS "$HEALTHCHECK_URL" -m 10 || true
    fi
  fi
}

SOURCES=""

# SSHFS mounten und zur Quelle hinzufügen
if [ -n "$SSHFS" ]; then
  echo "[$(date)] Mount remote via SSHFS..."
  if ! sshfs -o StrictHostKeyChecking=no,allow_other,IdentityFile=/root/.ssh/id_rsa $SSHFS /mnt/remote; then
    echo "[$(date)] Fehler beim Mounten von SSHFS."
    health_ping fail
    exit 1
  fi
  SOURCES="/mnt/remote"
fi

# Lokale Quellen zur Quelle hinzufügen
if [ -n "$LOCAL_SOURCE" ]; then
  IFS=',' read -ra ADDR <<< "$LOCAL_SOURCE"
  for src in "${ADDR[@]}"; do
    SOURCES="$SOURCES $src"
  done
fi

echo "[$(date)] Starte Borg-Backup für Quellen: $SOURCES"

if ! borg create --files-cache=mtime,size --stats -v "$BORG_REPO::${HOSTNAME}-$(date +'%Y-%m-%d')" $SOURCES; then
  echo "[$(date)] Fehler beim Borg-Backup."
  if [ -n "$SSHFS" ]; then
    fusermount -u /mnt/remote || true
  fi
  health_ping fail
  exit 2
fi

echo "[$(date)] Prune alte Backups..."

if ! borg prune -v --keep-daily=7 --keep-weekly=4 --keep-monthly=12 "$BORG_REPO"; then
  echo "[$(date)] Fehler beim Prune."
  if [ -n "$SSHFS" ]; then
    fusermount -u /mnt/remote || true
  fi
  health_ping fail
  exit 3
fi

# SSHFS aushängen, falls benutzt
if [ -n "$SSHFS" ]; then
  echo "[$(date)] Unmount SSHFS..."
  if ! fusermount -u /mnt/remote; then
    echo "[$(date)] Fehler beim Unmounten von SSHFS."
    health_ping fail
    exit 4
  fi
fi

health_ping

echo "[$(date)] === Backup erfolgreich abgeschlossen ==="

exit 0
