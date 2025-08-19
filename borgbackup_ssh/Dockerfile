FROM alpine:latest

# Install required tools
RUN apk add --no-cache borgbackup sshfs fuse bash curl tzdata

# Create necessary directories
RUN mkdir -p /root/.ssh /mnt/remote /borg/repo /var/log/borgbackup

# Copy scripts into the container
COPY backup.sh /backup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /backup.sh /entrypoint.sh

# FUSE configuration for sshfs
RUN echo "user_allow_other" > /etc/fuse.conf

ENTRYPOINT ["/entrypoint.sh"]
