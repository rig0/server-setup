# Server Setup

***Must be ran as root on a fresh installation***

## Copy and Install

```bash
curl -O https://rigslab.com/Rambo/server-setup/raw/branch/main/setup.sh && chmod +x setup.sh && ./setup.sh hostname=HOSTNAME user=USERNAME
```

## Arguments

- **hostname:** Hostname
- **user:** User to be created with sudo privelages
- *sshkey*:* Your ssh client public sshkey
- *usrkey*:* Pushover user api key
- *appkey*:* Pushover app api key
- *panel*:* Software to install (cloudpanel, webmin, dockge, portainer, openvpn, steam)
- *proxmox*:* 1 if system is a proxmox virtual machine

*= Optional

## Summary

- Updates system then installs: ***screen, git, ufw, openssl, rsync, cron, neofetch***
- Creates a user with sudo privelages
- Copies root ssh keys & authorized_keys to created user
- Locks out root user from ssh access
- Disables password ssh logins
- Sets the hostname
- Disables IPV6
- Enables ufw and allows port 22 for ssh
- Configures env variables to play nice with Tabby ssh client
- Installs vanity software for custom motd: ***lolcat linuxlogo toilet figlet cowsay fortune***
- Customizes the motd to add a little life to logins 

## Optional

- ``usrkey=pushover_user_key`` & ``appkey=pushover_app_key``
Installs [Pushover script](https://rigslab.com/Rambo/Pushover) & Creates notifications on login

- ``proxmox=1``
Installs QEMU Guest Agent for proxmox virtual machines

- ``sshkey="ssh-rsa yourPublicKey user@host"``
Adds your ssh client's pubkey to authorized_keys if not pre-configured

**Panels/Software**
- ``panel=dockge``
Installs [Dockge](https://github.com/louislam/dockge)

- ``panel=portainer``
Installs Docker & [Portainer CE](https://www.portainer.io/) (UI on port 9443)

- ``panel=cloudpanel``
Installs [CloudPanel](https://cloudpanel.io) using the latest installer and checksum (auto-normalizes raw hash/checksum formats)

- ``panel=webmin``
Installs [Webmin](https://tinycp.com/)

- ``panel=openvpn``
Installs [OpenVPN](https://rigslab.com/Rambo/OpenVPN-Installer) 

- ``panel=steam``
Installs steamcmd and adjust system setttings to play nice with game servers


## To Do:
- Make user creation optional for the scenario where a user is pre configured and root has been pre disabled
- Make tabby envs optional (ex. tabby=1)
- Make motd and vanity stuff optional (ex. vanity=1)
