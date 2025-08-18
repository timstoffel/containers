FROM alpine:latest

# Installiere benötigte Tools
RUN apk add --no-cache borgbackup sshfs fuse bash curl tzdata

# Erstelle notwendige Verzeichnisse
RUN mkdir -p /root/.ssh /mnt/remote /borg/repo /var/log/borgbackup

# Kopiere die Skripte in den Container
COPY backup.sh /backup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /backup.sh /entrypoint.sh

# FUSE-Konfiguration für sshfs
RUN echo "user_allow_other" > /etc/fuse.conf

ENTRYPOINT ["/entrypoint.sh"]
