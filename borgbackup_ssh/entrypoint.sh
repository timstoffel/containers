#!/bin/sh

# Zeitzone setzen, falls über ENV übergeben
if [ -n "$TZ" ]; then
  export TZ
  ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
  echo "$TZ" > /etc/timezone
fi

# Falls das Borg-Repository noch nicht initialisiert ist, initialisiere es (ohne Verschlüsselung)
if [ ! -f "$BORG_REPO/config" ]; then
  echo "Initialisiere Borg-Repository im $BORG_REPO ..."
  borg init --encryption=none "$BORG_REPO"
fi

# Schreibe den Cronjob mit Zeitplan aus ENV
echo "$CRON_SCHEDULE /backup.sh" > /etc/crontabs/root

# Starte Cron im Vordergrund
crond -f -d 8
