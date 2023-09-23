#!/bin/bash

shout() { echo "$0: $*" >&2; }
die() { shout "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

echo "This script should only be executed on a clean build"

#1. Install NGINX

echo "Opening port 443 for https access"
sudo ufw allow 443/tcp
echo "Installing NGINX"
sudo apt install -y nginx apache2-utils
sudo rm -rf /etc/nginx/{sites-available,sites-enabled}

# 2. Download Config
echo "Download and copy latest config files"
wget "https://github.com/radixdlt/radixdlt-nginx/releases/latest/download/radixdlt-nginx-fullnode-conf.zip"
unzip radixdlt-nginx-fullnode-conf.zip

sudo cp -r conf.d/ /etc/nginx/
sudo cp nginx-fullnode.conf /etc/nginx/nginx.conf

# 3. Create Nginx Cache Directory
echo "Create Nginx Cache Directory"
sudo mkdir -p /var/cache/nginx/radixdlt-hot

# 4. Create the SSL Certificates
echo "Create the SSL Certificates"
sudo mkdir /etc/nginx/secrets
sudo openssl req  -nodes -new -x509 -nodes -subj '/CN=localhost' -keyout "/etc/nginx/secrets/server.key" -out "/etc/nginx/secrets/server.pem"

# 5. Check the keys
echo "Make sure the keys are in the correct form"
sudo openssl dhparam -out /etc/nginx/secrets/dhparam.pem  4096


# 6. Set Authentication Passswords
echo "Set Authentication Passwords for Nginx Users"
echo "Creating password for Admin"
sudo htpasswd -c /etc/nginx/secrets/htpasswd.admin admin
echo "Creating password for Super Admin"
sudo htpasswd -c /etc/nginx/secrets/htpasswd.superadmin superadmin
echo "Creating password for Metrics"
sudo htpasswd -c /etc/nginx/secrets/htpasswd.metrics metrics

# 6. Start NGINX
echo "Starting NGINX"
sudo systemctl start nginx
echo "Ensuring Nginx starts on reboot"
sudo systemctl enable nginx


# 7. Edit the config file
echo "Edit the Nginx config file via command 'sudo nano /etc/nginx/nginx.conf' and add a line for 'proxy_protocol on;' above the line 'proxy_pass 127.0.0.1:30001;'"

# 8. Update Florian's Switch Script
echo "If using NGINX this script needs to be updated to change the port from 3333 to 3334"
echo "run 'sudo nano /opt/radixdlt/switch-mode.sh' and change the port on line 3"

# 9. Reboot
echo "Run 'sudo reboot' to restart the system"