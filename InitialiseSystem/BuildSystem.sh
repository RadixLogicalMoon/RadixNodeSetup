#!/bin/bash
# Global Variables
LOGFILE=log/nodesetup.log

# Global Functions
shout() { 
    CURRENTDATETIME=$(date);
    echo "$*"
    echo "$CURRENTDATETIME: $*" >> $LOGFILE; }
die() { shout "$*"; exit 111; }
try() { 
    "$@" 2>&1 | tee -a $LOGFILE
    exit_status=${PIPESTATUS[0]}

    if [ $exit_status -ne 0 ]; then
        die "Error occurred while executing: $* (See $LOGFILE for details)"
    fi
}

mkdir log

shout "This script must only be executed as the default admin user created in the previous step" 
shout "If the script fails part. Install the remaining steps manually" 
shout "Or start with a fresh install" 


$systemUser = $(whoami)

# 1. Lock Root User
shout "Locking root password to disable root login via password" 
try sudo -u $systemUser passwd -l root

# 2. SSH Setup
read -r -p "Do you wish to setup an SSH key (y/n)? " createSSHKey
if [ "$createSSHKey" = "y" ]; then
    shout "Creating SSH Key" 
    sudo -u $systemUser ssh-keygen -t ed25519 -f id_rsa
    shout "Copying keys to /home/$systemUser/.ssh/authorized_keys" 
    shout "Current Directory is: " && pwd 
    mkdir -p "/home/$systemUser/.ssh"
    if [ -d "/home/$systemUser/.ssh" ]; then
        shout "Directory /home/$systemUser/.ssh successfully created" 
    else
        die "Directory /home/$systemUser/.ssh was not successfully created" 
    fi
    try sudo -u $systemUser touch "/home/$systemUser/.ssh/authorized_keys"
    try sudo -u $systemUser chmod -R go= "/home/$systemUser/.ssh"
    try sudo -u $systemUser cat id_rsa.pub >>"/home/$systemUser/.ssh/authorized_keys"
fi
if [ "$createSSHKey" = "n" ]; then
    shout "You can manually copy generated ssh keys to /home/$systemUser/.ssh/authorized_keys if required"
fi

read -r -p "Enter new SSH Port (ensure cloud provider firewall has this port open): " sshPort

shout "Update SSH login to disable root login"
# Could these be added to the sshd_config.d override file instead???
sudo -u $systemUser echo "
Port $sshPort
PasswordAuthentication no
PermitRootLogin no
AllowUsers $systemUser
" >>/etc/ssh/sshd_config

sudo -u $systemUser chmod -R go= ~/.ssh
sudo -u $systemUser chown -R "$systemUser:$systemUser" ~/.ssh

sudo -u $systemUser systemctl restart sshd
shout "Created SSH Key and copied to /.ssh/authorized_keys"

# 3. Firewall Setup
shout "Configuring Ports"
sudo -u $systemUser ufw default deny incoming
sudo -u $systemUser ufw default allow outgoing
sudo -u $systemUser ufw allow "$sshPort/tcp"
sudo -u $systemUser ufw allow 30000/tcp
sudo -u $systemUser ufw allow 443/tcp
sudo -u $systemUser ufw enable
sudo -u $systemUser ufw status
sudo -u $systemUser  try sudo ufw status
shout "Successfully configured ports 30000, 443 & $sshPort.  Check you can login again before exiting the session"

# 4. System Update
shout "About to install system updates"
sudo -u $systemUser apt update -y
sudo -u $systemUser apt-get dist-upgrade
shout "Successfully installed system updates"

# 5 Shared Memory Read Only
shout "Setting shared memory to read only"
sudo -u $systemUser echo "
none /run/shm tmpfs defaults,ro 0 0
" >>/etc/fstab
sudo -u $systemUser mount -a

## 6 Install FIO (Test tool for IO)
shout "Installing FIO (Test tool for IO)"
sudo -u $systemUser apt install fio
shout "fio Install Complete. Run the following command to test 'fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75'"

## 6 Install ZSTD (For uncompressing snapshots from https://snapshots.radix.live/)
shout "Installing zstd (For uncompressing snapshots from https://snapshots.radix.live/)"
sudo -u $systemUser apt install zstd
mkdir /backup
shout "zstd Install Complete and created /backup dir"

shout "A reboot is required, but first check you can login via user $systemUser and port $sshPort, before rebooting the system via 'sudo reboot'"
shout "Use command 'ssh <ip> -p $sshPort -l $systemUser'"
