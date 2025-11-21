# Server Setup

Automates the first bootstrap of a fresh Debian/Ubuntu server: updates the OS, creates a sudo user, locks down SSH, enables firewall, installs a custom MOTD, and can optionally wire up Pushover alerts and control panels.

## Quick start
Run as root on a new server:
```bash
curl -O https://rigslab.com/Rambo/server-setup/raw/branch/main/setup.sh
chmod +x setup.sh
./setup.sh hostname=HOSTNAME user=USERNAME usrkey=PUSHOVER_USER appkey=PUSHOVER_APP sshkey="ssh-rsa AAA..."
```
Only `hostname` and `user` are required; everything else is optional.

## Arguments
- `hostname` (required) – hostname/FQDN to set, also used as the Pushover title
- `user` (required) – sudo user to create
- `sshkey` (optional) – public key to add to `/root/.ssh/authorized_keys` before copying to the new user
- `usrkey` (optional) – Pushover user key (must accompany `appkey`)
- `appkey` (optional) – Pushover app token (must accompany `usrkey`)
- `panel` (optional) – `cloudpanel`, `webmin`, `dockge`, `portainer`, `openvpn`, or `steam`
- `proxmox` (optional) – set to `1` to install `qemu-guest-agent`

## What it does
- Updates/Upgrades packages, installs basics: `sudo`, `screen`, `curl`, `git`, `ufw`, `openssl`, `rsync`, `cron`, `neofetch`
- Creates the sudo user, copies SSH keys, disables root SSH and password auth
- Enables UFW (port 22 allowed), disables IPv6
- Installs MOTD extras (`lolcat`, `linuxlogo`, `toilet`, `figlet`, `cowsay`, `fortune`) and writes a custom MOTD
- Sets Tabby-friendly prompt bits in the user’s `.bashrc`
- Optional: installs Pushover CLI and sends SSH-login + completion notifications when `usrkey` and `appkey` are provided
- Optional: installs a control panel/tool when `panel` is set

## Pushover behavior
If `usrkey` **and** `appkey` are provided:
- Installs the Pushover CLI via `install-pushover.sh` with defaults: `title="$hostname"`, `sound="info"`, `url="ssh://<server-ip>:22"`.
- Adds a `.bashrc` snippet that sends `pushover message="SSH login: $(whoami) from <ip>" sound=sifi-lock` on SSH login (guarded against repeats).
- Sends a “Server Setup Complete” push at the end of the run.

## Panels/tools
- `panel=dockge` – installs Docker and [Dockge](https://github.com/louislam/dockge) (port 5001 bound to 127.0.0.1)
- `panel=portainer` – installs Docker and [Portainer CE](https://www.portainer.io/) (port 9443, UFW allowlist for the connecting IP if known)
- `panel=cloudpanel` – installs [CloudPanel](https://cloudpanel.io) with published installer hash (MariaDB 11.4)
- `panel=webmin` – installs [Webmin](https://webmin.com/)
- `panel=steam` – installs `steamcmd` and applies game-server sysctl/limits

## Notes
- UFW is enabled non-interactively (`ufw --force enable`).
- SSH keys are generated non-interactively (`/root/.ssh/id_rsa`) if none exist; provide `sshkey` to seed a client key.
- Keep backups of your `sshkey` and Pushover tokens; rerun the script with the same values if you need to reinstall.
