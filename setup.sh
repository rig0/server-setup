#!/bin/bash

# Server setup script by rig0. 
# Intended for Debian/Ubuntu systems.
# Run on a fresh system with root access

# Initiliaze possible arguments
user="" # username to create with sudo privelages
hostname="" # used as fqdn & notification title
sshkey="" # client public ssh key (optional)
usrkey="" # pushover user api key (optional)
appkey="" # pushover app api key (optional)
panel="" # control panel (optional)
proxmox="" # proxmox machine? 1 if true; else leave blank (optional)


# Loop through arguments
for arg in "$@"; do
  case $arg in
    user=*) 
      user="${arg#*=}"
      ;;
    hostname=*) 
      hostname="${arg#*=}"
      ;;
    sshkey=*) 
      sshkey="${arg#*=}"
      ;;
    usrkey=*) 
      usrkey="${arg#*=}"
      ;;
    appkey=*) 
      appkey="${arg#*=}"
      ;;
    panel=*) 
      panel="${arg#*=}"
      ;;
    proxmox=*) 
      proxmox="${arg#*=}"
      ;;
    *)
      # Ignore unknown arguments or handle them as needed
      ;;
  esac
done


# Check if required arguments are provided
if [[ -z $user || -z $hostname ]]; then
  printf "Usage: $0 user=username hostname=hostname usrkey=pushoveruserkey* appkey=pushoverappkey* panel=cloudpanel|webmin|dockge|portainer|steam* proxmox=1* sshkey=yourpubkey* \n *=optional"
  exit 1
fi

# Bash Styling
YELLOW='\033[1;33m'
NC='\033[0m' # no color
ST="\n${YELLOW}----------------------------------------------------------------------\n\n"
SB="\n----------------------------------------------------------------------\n\n${NC}"


printf "$ST Updating OS & Installing prerequisites \n $SB"
apt update && apt dist-upgrade -y
apt install sudo screen curl git ufw openssl rsync cron neofetch -y

# Installing qemu-guest-agent if server is a proxmox machine
if [[ "$proxmox" -eq 1 ]]; then
  apt install qemu-guest-agent -y
fi

printf "$ST Creating Main User. Set your password: \n $SB"
adduser "$user"
usermod -aG sudo "$user"
echo "$user   ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Check if pushover options were passed
if [[ -n $usrkey && -n $appkey ]]; then
        printf "$ST Downloading and configuring Pushover notifications. \n $SB"

        # Get main interface ip
        ip=$(ip route get 8.8.8.8 | awk '/src/ {print $7}')

        # Pushover notification options
        PO_SOUND="info"
        PO_URL="ssh://$ip:22"

        # Download pushover script
        tmpdir=$(mktemp -d)
        git clone https://rigslab.com/Rambo/pushover.git "$tmpdir/pushover"
        chmod +x "$tmpdir/pushover/install-pushover.sh"
        "$tmpdir/pushover/install-pushover.sh" title="$hostname" user="$usrkey" token="$appkey" sound="$PO_SOUND" url="$PO_URL"
        rm -rf "$tmpdir"

        printf "$ST Enabling SSH login notifications \n $SB"
        cat <<'EOF' >> "/home/$user/.bashrc"
# Pushover SSH login notification
if [[ -n "$SSH_CONNECTION" && -z "$PUSHOVER_LOGIN_SENT" ]]; then
  export PUSHOVER_LOGIN_SENT=1
  login_from="${SSH_CLIENT%% *}"
  pushover message="SSH login: $(whoami) from ${login_from:-unknown}" sound=sifi-lock
fi
EOF
elif [[ -n $usrkey || -n $appkey ]]; then
        printf "$ST Skipping Pushover install (both usrkey and appkey are required). \n $SB"
fi


printf "$ST Securing SSH and Generating keys \n $SB"

# Disable root login
sed -i -e 's/#PermitRootLogin\ prohibit-password/PermitRootLogin\ no/g' /etc/ssh/sshd_config # this covers proxmox cloud init defaults
sed -i -e 's/PermitRootLogin\ yes/PermitRootLogin\ no/g' /etc/ssh/sshd_config # this covers most vps' defaults

# Disable password auth
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication\ no/g' /etc/ssh/sshd_config 

# Generate ssh keys (non-interactive) and configure auth keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [[ ! -f /root/.ssh/id_rsa ]]; then
  ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa -q
fi
touch /root/.ssh/authorized_keys
if [[ -n "$sshkey" ]]; then
  echo "$sshkey" >> /root/.ssh/authorized_keys
fi
chmod 600 /root/.ssh/authorized_keys

# Copy keys to main user and set perms
mkdir -p "/home/$user/.ssh"
cp -a /root/.ssh/. "/home/$user/.ssh/"
chown -R "$user:$user" "/home/$user/.ssh/"
chmod 700 "/home/$user/.ssh/"
chmod 600 "/home/$user/.ssh/authorized_keys"
chmod 600 "/home/$user/.ssh/id_rsa"
chmod 644 "/home/$user/.ssh/id_rsa.pub"
service sshd restart

printf "$ST Setting hostname \n $SB"
hostnamectl set-hostname "$hostname"
echo "$hostname" >> /etc/hostname
hostname

printf "$ST Disabling ipv6 \n $SB"
sysctl -w net.ipv6.conf.all.disable_ipv6=1

printf "$ST Configuring and enabling Firewall \n $SB"
ufw allow 22/tcp
ufw --force enable

printf "$ST Configuring Tabby env variables \n $SB"
echo "#TABBY WORKING DIR SCRIPT" >> "/home/$user/.bashrc"
echo "export PS1=\"\$PS1\[\e]1337;CurrentDir=\"'/home/$user\a\]'" >> "/home/$user/.bashrc"
echo "Done."

printf "$ST Customizing motd \n $SB"

# Install prerequisites
apt install sudo lolcat linuxlogo toilet figlet cowsay fortune-mod -y

# Backup up original motd
mv /etc/motd /etc/motd.bak

# Comment out original linux os and kernel info
sed -i -e 's/uname -snrvm/#uname -snrvm/g' /etc/update-motd.d/10-uname

# Create custom message
touch /etc/update-motd.d/99-custom-motd
echo "#!/bin/bash" >> /etc/update-motd.d/99-custom-motd
echo "{" >> /etc/update-motd.d/99-custom-motd
echo "  /usr/games/fortune | /usr/games/cowsay -f tux" >> /etc/update-motd.d/99-custom-motd
echo "  toilet -f ivrit \"$HOSTNAME\"" >> /etc/update-motd.d/99-custom-motd
echo "  linuxlogo -a -g -u -d -s -k -F \"Debian $(cat /etc/debian_version) Bookworm \n#O Kernel #V \n#M #T #R RAM \n#U\"" >> /etc/update-motd.d/99-custom-motd
echo "} | /usr/games/lolcat -p 13 --force" >> /etc/update-motd.d/99-custom-motd
chmod +x /etc/update-motd.d/99-custom-motd

# Fallback: ensure MOTD shows even if pam_motd is skipped
cat <<'EOF' >/etc/profile.d/zz-show-motd.sh
# Show MOTD in interactive shells if pam_motd did not run
if [ -z "$MOTD_SHOWN" ] && [ -n "$PS1" ] && [ -t 1 ] && [ -r /run/motd.dynamic ]; then
  cat /run/motd.dynamic
fi
EOF

# Check for panel option
case $panel in
    cloudpanel)
        printf "$ST Installing CloudPanel \n $SB" #only debian 11

        # Get main interface ip
        ip=$(ip route get 8.8.8.8 | awk '/src/ {print $7}')

        # Add to hosts file
        echo "$ip $hostname" >> /etc/hosts

        # Install CloudPanel with published checksum
        curl -sS https://installer.cloudpanel.io/ce/v2/install.sh -o install.sh; \
        echo "19cfa702e7936a79e47812ff57d9859175ea902c62a68b2c15ccd1ebaf36caeb install.sh" | \
        sha256sum -c && sudo DB_ENGINE=MARIADB_11.4 bash install.sh

        # Get user ip and allow ufw access
        user_ip=$(echo "$SSH_CLIENT" | awk '{print $1}')
        ufw allow from $user_ip to any port 8443
        ;;
    webmin)
        printf "$ST Installing Webmin \n $SB"

        # Get latest version
        curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
        sudo sh webmin-setup-repo.sh
        apt install -y webmin --install-recommends
        ;;
    steam)
        printf "$ST Installing Steam and Configuring system for game servers \n $SB"

        # Install steamcmd
        apt install lib32gcc-s1 software-properties-common -y
        dpkg --add-architecture i386
        add-apt-repository -U http://deb.debian.org/debian -c non-free-firmware -c non-free
        apt update && apt install steamcmd -y

        # Pre-req settings for ac game servers
        sysctl -w net.core.wmem_default=2000000
        sysctl -w net.core.rmem_default=2000000
        sysctl -w net.core.wmem_max=2000000
        sysctl -w net.core.rmem_max=2000000

        # Increase number of open files to prevent errors when running game servers
        echo "fs.file-max=100000" >> /etc/sysctl.conf && sysctl -p
        echo "* soft nofile 1000000" >> /etc/security/limits.conf
        echo "* hard nofile 1000000" >> /etc/security/limits.conf
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
        ;;
    dockge)
        printf "$ST Installing Docker & Dockge \n $SB"

        # Install docker
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update && apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

        # Add user to docker group
        usermod -aG docker "$user"

        # Install dockge
        mkdir -p /opt/dockge /opt/stacks
        curl "https://dockge.kuma.pet/compose.yaml?port=5001&stacksPath=%2Fopt%2Fstacks" --output /opt/dockge/compose.yaml

        # Change port to only listen on 127.0.0.1. Will tunnel w/ cloudflare
        sed -i -e 's/-\ 5001:5001/-\ 127.0.0.1:5001:5001/g' /opt/dockge/compose.yaml

        # Start dockge
        docker compose -f /opt/dockge/compose.yaml up -d
        ;;
    portainer)
        printf "$ST Installing Docker & Portainer \n $SB"

        # Install docker
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt update && apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

        # Add user to docker group
        usermod -aG docker "$user"

        # Deploy portainer
        docker volume create portainer_data
        docker run -d --name portainer --restart=always -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

        # Allow access to the Portainer UI
        user_ip=$(echo $SSH_CLIENT | awk '{print $1}')
        if [[ -n "$user_ip" ]]; then
            ufw allow from $user_ip to any port 9443
        else
            ufw allow 9443/tcp
        fi
        ;;
    *)
        echo "No panel chosen."
        ;;
esac

printf "$ST Server Setup Complete! \n$SB"
if [[ -n $usrkey && -n $appkey ]]; then
  # Send notification if pushover installed
  pushover "Server Setup Complete" 
fi

# Show system info:
neofetch
