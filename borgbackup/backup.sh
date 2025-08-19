#!/bin/sh

set -eu

# Log file path
LOGFILE="/var/log/borgbackup/backup-$(date +'%Y-%m-%d').log"

# Write all output to logfile and stdout (POSIX compliant, no process substitution)
# shellcheck disable=SC2094
# Use a subshell to tee output, since process substitution is not POSIX
# All output will be piped through tee
{
  echo "[$(date)] === Backup started ==="

  # Function to ping healthcheck endpoint
  health_ping() {
    if [ -n "${HEALTHCHECK_URL:-}" ]; then
      if [ "${1:-}" = "fail" ]; then
        curl -fsS "${HEALTHCHECK_URL}/fail" -m 10 || true
      else
        curl -fsS "$HEALTHCHECK_URL" -m 10 || true
      fi
    fi
  }

  SOURCES=""

  # Mount SSHFS and add to sources if SSHFS env is set
  if [ -n "${SSHFS:-}" ]; then
    echo "[$(date)] Mounting remote via SSHFS..."
    if ! sshfs -o StrictHostKeyChecking=no,allow_other,IdentityFile=/root/.ssh/id_rsa "$SSHFS" /mnt/remote; then
      echo "[$(date)] Error mounting SSHFS."
      health_ping fail
      exit 1
    fi
    SOURCES="/mnt/remote"
  fi

  # Add local sources if LOCAL_SOURCE env is set (comma separated, POSIX compliant)
  if [ -n "${LOCAL_SOURCE:-}" ]; then
    OLD_IFS=$IFS
    IFS=','
    for src in $LOCAL_SOURCE; do
      SOURCES="$SOURCES $src"
    done
    IFS=$OLD_IFS
  fi

  # Check if sources are set
  if [ -z "$SOURCES" ]; then
    echo "[$(date)] No sources specified for backup."
    health_ping fail
    exit 5
  fi

  # Use HOSTNAME env or fallback to output of hostname command (POSIX safe)
  if [ -n "${HOSTNAME:-}" ]; then
    BORG_HOSTNAME="$HOSTNAME"
  else
    BORG_HOSTNAME="$(hostname)"
  fi

  echo "[$(date)] Starting Borg backup for sources: $SOURCES"

  if ! borg create --files-cache=mtime,size --stats -v "$BORG_REPO::${BORG_HOSTNAME}-$(date +'%Y-%m-%d')" "$SOURCES"; then
    echo "[$(date)] Borg backup failed."
    if [ -n "${SSHFS:-}" ]; then
      fusermount -u /mnt/remote || true
    fi
    health_ping fail
    exit 2
  fi

  echo "[$(date)] Pruning old backups..."

  if ! borg prune -v --keep-daily=7 --keep-weekly=4 --keep-monthly=12 "$BORG_REPO"; then
    echo "[$(date)] Prune failed."
    if [ -n "${SSHFS:-}" ]; then
      fusermount -u /mnt/remote || true
    fi
    health_ping fail
    exit 3
  fi

  # Unmount SSHFS if used
  if [ -n "${SSHFS:-}" ]; then
    echo "[$(date)] Unmounting SSHFS..."
    if ! fusermount -u /mnt/remote; then
      echo "[$(date)] Error unmounting SSHFS."
      health_ping fail
      exit 4
    fi
  fi

  health_ping

  echo "[$(date)] === Backup completed successfully ==="

  exit 0
} | tee -a "$LOGFILE"
