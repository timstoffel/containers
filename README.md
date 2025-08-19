# 🐳 containers

A curated collection of my own Docker containers for various infrastructure and automation tasks.

---

## 📦 Available Containers

### `borgbackup_ssh`

A minimal, production-ready Docker container for automated [BorgBackup](https://www.borgbackup.org/) backups, supporting both local and SSHFS-mounted remote sources.  
Features include:

- **Automated scheduled backups** via cron (configurable via environment variable)
- **SSHFS support** for remote backup sources
- **Healthcheck integration** (e.g. [healthchecks.io](https://healthchecks.io/))
- **Automatic pruning** of old backups
- **Logging** to `/var/log/borgbackup`
- **Timezone support**

#### Usage Example

```bash
docker run -d \
  -e BORG_REPO=/borg/repo \
  -e LOCAL_SOURCE="/data/to/backup" \
  -e CRON_SCHEDULE="0 2 * * *" \
  -e HEALTHCHECK_URL="https://hc-ping.com/your-uuid" \
  -v /your/data:/data/to/backup:ro \
  -v /your/borg/repo:/borg/repo \
  --name borgbackup \
  yourrepo/borgbackup_ssh:latest
```
For remote SSHFS backups, set the SSHFS environment variable instead of LOCAL_SOURCE and mount your SSH key into /root/.ssh/id_rsa.

## 🚀 Getting Started
* Clone this repository
git clone https://github.com/yourusername/containers.git

* Build a container
docker build -t yourrepo/borgbackup_ssh borgbackup_ssh/

* Configure and run
See usage example above.

## 🛠️ Contributing
Contributions, issues, and feature requests are welcome!
Feel free to open an issue or submit a pull request.

## 📄 License
This project is licensed under the MIT License.

