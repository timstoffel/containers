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

# SSHFS mounten
echo "[$(date)] Mount remote via SSHFS..."
if ! sshfs -o StrictHostKeyChecking=no,allow_other,IdentityFile=/root/.ssh/id_rsa $SSHFS /mnt/remote; then
  echo "[$(date)] Fehler beim Mounten von SSHFS."
  health_ping fail
  exit 1
fi

# Backup mit Borg
echo "[$(date)] Starte Borg-Backup..."
if ! borg create --files-cache=mtime,size --stats -v"$BORG_REPO"::"{hostname}-{now:%Y-%m-%d}" /mnt/remote; then
  echo "[$(date)] Fehler beim Borg-Backup."
  fusermount -u /mnt/remote || true
  health_ping fail
  exit 2
fi

# Alte Backups aufräumen
echo "[$(date)] Prune alte Backups..."
if ! borg prune -v --keep-daily=7 --keep-weekly=4 --keep-monthly=12 "$BORG_REPO"; then
  echo "[$(date)] Fehler beim Prune."
  fusermount -u /mnt/remote || true
  health_ping fail
  exit 3
fi

# SSHFS aushängen
echo "[$(date)] Unmount SSHFS..."
if ! fusermount -u /mnt/remote; then
  echo "[$(date)] Fehler beim Unmounten von SSHFS."
  health_ping fail
  exit 4
fi

# Healthchecks.io Erfolgsping
health_ping

echo "[$(date)] === Backup erfolgreich abgeschlossen ==="
exit 0
