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

shout "Defaulting system user based on current directory" 
systemUser=$(basename $PWD)
if id $systemUser &>/dev/null; then
    shout "Found User: $systemUser" 
else
  die "No user found based on current working directory: $PWD"
fi


# 4. System Update
shout "About to install system updates"
try sudo apt update -y
try sudo apt-get dist-upgrade
shout "Successfully installed system updates"


# 1. Lock Root User
shout "Locking root password to disable root login via password" 
try sudo passwd -l root

# 2. SSH Setup
read -r -p "Do you have an SSH key (y/n) you would like to use for $systemUser? " createSSHKey
if [ "$createSSHKey" = "y" ]; then
    shout "SCP your SSH Key to " && pwd

    read -r -p "Enter the filename " sshKeyFilePath

    while [ -d $sshKeyFilePath == false ]; do
        shout "File $sshKeyFilePath does not exist" 
        read -r -p "Enter the filename " sshKeyFilePath
    done 
fi

if [ "$createSSHKey" = "y" ]; then
    shout "Copying keys to /home/$systemUser/.ssh/authorized_keys" 
    shout "Current Directory is: " && pwd 
    mkdir -p "/home/$systemUser/.ssh"
    if [ -d "/home/$systemUser/.ssh" ]; then
        shout "Directory /home/$systemUser/.ssh successfully created" 
    else
        die "Directory /home/$systemUser/.ssh was not successfully created" 
    fi

    try sudo touch "/home/$systemUser/.ssh/authorized_keys"
    try sudo mv $sshKeyFilePath "/home/$systemUser/.ssh"
fi

try sudo chmod -R go= ~/.ssh
try sudo chown -R "$systemUser:$systemUser" ~/.ssh

shout "Setting up non standard SSH port"
read -r -p "Enter new SSH Port (ensure cloud provider firewall has this port open): " sshPort

shout "Update SSH login to disable root login"
# Could these be added to the sshd_config.d override file instead???
try sudo echo "
Port $sshPort
PasswordAuthentication no
PermitRootLogin no
AllowUsers $systemUser
" >>/etc/ssh/sshd_config

sudo systemctl restart sshd
shout "Created SSH Key and copied to /.ssh/authorized_keys"

# 3. Firewall Setup
shout "Configuring Ports"
try sudo ufw default deny incoming
try sudo ufw default allow outgoing
try sudo ufw allow "$sshPort/tcp"
try sudo ufw allow 30000/tcp
try sudo ufw allow 443/tcp
try sudo ufw enable
try sudo ufw status
try sudo ufw status
shout "Successfully configured ports 30000, 443 & $sshPort.  Check you can login again before exiting the session"


# 5 Shared Memory Read Only
shout "Setting shared memory to read only"
try sudo echo "
none /run/shm tmpfs defaults,ro 0 0
" >>/etc/fstab
try sudo mount -a

## 6 Install FIO (Test tool for IO)
shout "Installing FIO (Test tool for IO)"
try sudo apt install fio
shout "fio Install Complete. Run the following command to test 'fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75'"

## 6 Install ZSTD (For uncompressing snapshots from https://snapshots.radix.live/)
shout "Installing zstd (For uncompressing snapshots from https://snapshots.radix.live/)"
try sudo apt install zstd
mkdir /backup
shout "zstd Install Complete and created /backup dir"

shout "A reboot is required, but first check you can login via user $systemUser and port $sshPort, before rebooting the system via 'sudo reboot'"
shout "Use command 'ssh <ip> -p $sshPort -l $systemUser'"
