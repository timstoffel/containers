#!/bin/sh

set -eu

# Log file path
LOGFILE="/var/log/borgbackup/backup-$(date +'%Y-%m-%d').log"

# Write all output to logfile and stdout (POSIX compliant, no process substitution)
# All output will be piped through tee
{
  echo "[$(date)] === Backup started ==="
  echo "[$(date)] Script PID: $$"
  echo "[$(date)] Current user: $(id -u -n)"
  echo "[$(date)] Environment variables:"
  env | sort

  # Function to ping healthcheck endpoint
  health_ping() {
    if [ -n "${HEALTHCHECK_URL:-}" ]; then
      echo "[$(date)] Pinging healthcheck endpoint: $HEALTHCHECK_URL (status: ${1:-ok})"
      if [ "${1:-}" = "fail" ]; then
        curl -fsS "${HEALTHCHECK_URL}/fail" -m 10 || true
      else
        curl -fsS "$HEALTHCHECK_URL" -m 10 || true
      fi
    else
      echo "[$(date)] No HEALTHCHECK_URL set, skipping health ping."
    fi
  }

  SOURCES=""

  # Mount SSHFS and add to sources if SSHFS env is set
  if [ -n "${SSHFS:-}" ]; then
    echo "[$(date)] SSHFS variable detected: $SSHFS"
    echo "[$(date)] Attempting to mount SSHFS to /mnt/remote..."
    if ! sshfs -o StrictHostKeyChecking=no,allow_other,IdentityFile=/root/.ssh/id_rsa "$SSHFS" /mnt/remote; then
      echo "[$(date)] Error mounting SSHFS."
      health_ping fail
      exit 1
    fi
    echo "[$(date)] SSHFS mounted successfully."
    SOURCES="/mnt/remote"
  else
    echo "[$(date)] No SSHFS variable set, skipping SSHFS mount."
  fi

  # Add local sources if LOCAL_SOURCE env is set (comma separated, POSIX compliant)
  if [ -n "${LOCAL_SOURCE:-}" ]; then
    echo "[$(date)] LOCAL_SOURCE variable detected: $LOCAL_SOURCE"
    OLD_IFS=$IFS
    IFS=','
    for src in $LOCAL_SOURCE; do
      echo "[$(date)] Adding local source: '$src'"
      if [ -z "$SOURCES" ]; then
        SOURCES="$src"
      else
        SOURCES="$SOURCES $src"
      fi
    done
    IFS=$OLD_IFS
  else
    echo "[$(date)] No LOCAL_SOURCE variable set, skipping local sources."
  fi

  echo "[$(date)] Final SOURCES value: '$SOURCES'"

  # Check if sources are set
  if [ -z "$SOURCES" ]; then
    echo "[$(date)] ERROR: No sources specified for backup."
    health_ping fail
    exit 5
  fi

  # Use HOSTNAME env or fallback to output of hostname command (POSIX safe)
  if [ -n "${HOSTNAME:-}" ]; then
    BORG_HOSTNAME="$HOSTNAME"
    echo "[$(date)] Using HOSTNAME from environment: $BORG_HOSTNAME"
  else
    BORG_HOSTNAME="$(hostname)"
    echo "[$(date)] Using HOSTNAME from 'hostname' command: $BORG_HOSTNAME"
  fi

  echo "[$(date)] Starting Borg backup for sources: $SOURCES"
  echo "[$(date)] Borg repository: $BORG_REPO"
  echo "[$(date)] Borg archive name: ${BORG_HOSTNAME}-$(date +'%Y-%m-%d')"

  # Print the borg create command with resolved variables for debugging
  echo "[$(date)] borg create --files-cache=mtime,size --stats -v \"$BORG_REPO::${BORG_HOSTNAME}-$(date +'%Y-%m-%d')\" $SOURCES"

  if ! borg create --files-cache=mtime,size --stats -v "$BORG_REPO::${BORG_HOSTNAME}-$(date +'%Y-%m-%d')" "$SOURCES"; then
    echo "[$(date)] ERROR: Borg backup failed."
    if [ -n "${SSHFS:-}" ]; then
      echo "[$(date)] Attempting to unmount SSHFS after backup failure..."
      fusermount -u /mnt/remote || true
    fi
    health_ping fail
    exit 2
  fi

  echo "[$(date)] Borg backup completed successfully."

  echo "[$(date)] Pruning old backups..."
  echo "[$(date)] borg prune -v --keep-daily=7 --keep-weekly=4 --keep-monthly=12 \"$BORG_REPO\""

  if ! borg prune -v --keep-daily=7 --keep-weekly=4 --keep-monthly=12 "$BORG_REPO"; then
    echo "[$(date)] ERROR: Prune failed."
    if [ -n "${SSHFS:-}" ]; then
      echo "[$(date)] Attempting to unmount SSHFS after prune failure..."
      fusermount -u /mnt/remote || true
    fi
    health_ping fail
    exit 3
  fi

  echo "[$(date)] Prune completed successfully."

  # Unmount SSHFS if used
  if [ -n "${SSHFS:-}" ]; then
    echo "[$(date)] Attempting to unmount SSHFS..."
    if ! fusermount -u /mnt/remote; then
      echo "[$(date)] ERROR: Unmounting SSHFS failed."
      health_ping fail
      exit 4
    fi
    echo "[$(date)] SSHFS unmounted successfully."
  fi

  health_ping

  echo "[$(date)] === Backup completed successfully ==="

  exit 0
} | tee -a "$LOGFILE"
