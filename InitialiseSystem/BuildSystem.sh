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

rm -r log
mkdir log

shout "This script should only be executed on a clean install of Ubuntu" 
shout "If the script fails part. Install the remaining steps manually" 
shout "Or start with a fresh install" 

# 1. User Setup
read -r -p "Name of default system user to create: " systemUser
shout "Creating user $systemUser" 
try adduser --gecos "admin" $systemUser
try passwd $systemUser
try adduser $systemUser sudo

if id "$systemUser" &>/dev/null; then
    shout "User $systemUser Successfully Created" 
else
    shout "User $systemUser not found" 
    die
fi

# 1. Lock Root User
shout "Locking root password to disable root login via password" 
try su -l $systemUser -c 'passwd -l root'

# 2. SSH Setup
read -r -p "Do you wish to setup an SSH key (y/n)? " createSSHKey
if [ "$createSSHKey" = "y" ]; then
    shout "Creating SSH Key" 
    try su -l $systemUser -c 'ssh-keygen -t ed25519 -f id_rsa'
    shout "Copying keys to /home/$systemUser/.ssh/authorized_keys" 
    shout "Current Directory is: " && pwd 
    mkdir -p "/home/$systemUser/.ssh"
    if [ -d "/home/$systemUser/.ssh" ]; then
        shout "Directory /home/$systemUser/.ssh successfully created" 
    else
        die "Directory /home/$systemUser/.ssh was not successfully created" 
    fi
    try su -l $systemUser -c 'touch "/home/$systemUser/.ssh/authorized_keys"'
    try su -l $systemUser -c 'chmod -R go= "/home/$systemUser/.ssh"'
    try su -l $systemUser -c 'cat id_rsa.pub >>"/home/$systemUser/.ssh/authorized_keys"'
fi
if [ "$createSSHKey" = "n" ]; then
    shout "You can manually copy generated ssh keys to /home/$systemUser/.ssh/authorized_keys if required"
fi

read -r -p "Enter new SSH Port (ensure cloud provider firewall has this port open): " sshPort

shout "Update SSH login to disable root login"
# Could these be added to the sshd_config.d override file instead???
try su -l $systemUser -c  'echo "
Port $sshPort
PasswordAuthentication no
PermitRootLogin no
AllowUsers $systemUser
" >>/etc/ssh/sshd_config' 

try su -l $systemUser -c 'chmod -R go= ~/.ssh'
try su -l $systemUser -c 'chown -R "$systemUser:$systemUser" ~/.ssh'

try su -l $systemUser -c  'systemctl restart sshd'
shout "Created SSH Key and copied to /.ssh/authorized_keys"

# 3. Firewall Setup
shout "Configuring Ports"
try su -l $systemUser -c 'ufw default deny incoming'
try su -l $systemUser -c 'ufw default allow outgoing'
try su -l $systemUser -c 'ufw allow "$sshPort/tcp"'
try su -l $systemUser -c 'ufw allow 30000/tcp'
try su -l $systemUser -c 'ufw allow 443/tcp'
try su -l $systemUser -c 'ufw enable'
try su -l $systemUser -c 'ufw status'
try su -l $systemUser -c 'try sudo ufw status'
shout "Successfully configured ports 30000, 443 & $sshPort.  Check you can login again before exiting the session"

# 4. System Update
shout "About to install system updates"
try su -l $systemUser -c 'apt update -y'
try su -l $systemUser -c 'apt-get dist-upgrade'
shout "Successfully installed system updates"

# 5 Shared Memory Read Only
shout "Setting shared memory to read only"
try su -l $systemUser -c 'echo "
none /run/shm tmpfs defaults,ro 0 0
" >>/etc/fstab'
try su -l $systemUser -c 'mount -a'

## 6 Install FIO (Test tool for IO)
shout "Installing FIO (Test tool for IO)"
try su -l $systemUser -c 'apt install fio'
shout "fio Install Complete. Run the following command to test 'fio --randrepeat=1 --ioengine=libaio --direct=1 --gtod_reduce=1 --name=test --filename=test --bs=4k --iodepth=64 --size=1G --readwrite=randrw --rwmixread=75'"

## 6 Install ZSTD (For uncompressing snapshots from https://snapshots.radix.live/)
shout "Installing zstd (For uncompressing snapshots from https://snapshots.radix.live/)"
try su -l $systemUser -c 'apt install zstd'
mkdir /backup
shout "zstd Install Complete and created /backup dir"

shout "A reboot is required, but first check you can login via user $systemUser and port $sshPort, before rebooting the system via 'sudo reboot'"
shout "Use command 'ssh <ip> -p $sshPort -l $systemUser'"
