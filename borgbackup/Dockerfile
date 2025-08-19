# Ignore Version Pinning
# hadolint ignore=DL3007
FROM alpine:latest

# Install required tools and create necessary directories
# Ignore Version Pinning
# hadolint ignore=DL3018
RUN apk add --no-cache borgbackup sshfs fuse bash curl tzdata \
 && mkdir -p /root/.ssh /mnt/remote /borg/repo /var/log/borgbackup

# Copy scripts into the container
COPY backup.sh /backup.sh
COPY entrypoint.sh /entrypoint.sh

# cheange permissions and FUSE configuration for sshfs
RUN chmod +x /backup.sh /entrypoint.sh \
 && echo "user_allow_other" > /etc/fuse.conf

ENTRYPOINT ["/entrypoint.sh"]
