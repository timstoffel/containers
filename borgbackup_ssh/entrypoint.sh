#!/bin/sh

set -eu

# Set timezone if provided via ENV
if [ -n "${TZ:-}" ]; then
  export TZ
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# Initialize Borg repository if not already initialized (no encryption)
if [ ! -f "${BORG_REPO}/config" ]; then
  echo "Initializing Borg repository at $BORG_REPO ..."
  borg init --encryption=none "$BORG_REPO"
fi

# Write cronjob with schedule from ENV
echo "${CRON_SCHEDULE:-0 3 * * *} /backup.sh" > /etc/crontabs/root

# Start cron in foreground
crond -f -d 8