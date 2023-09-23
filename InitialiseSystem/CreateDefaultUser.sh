#!/bin/bash
# Global Variables
LOGFILE=$PWD/log/createUser.log

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
try adduser $systemUser
try adduser $systemUser sudo

if id "$systemUser" &>/dev/null; then
    shout "User $systemUser Successfully Created" 
else
    shout "User $systemUser not found" 
    die
fi

shout "Downloading script to build system"
try wget -O BuildSystem.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/development/InitialiseSystem/BuildSystem.sh
try mv BuildSystem.sh /home/$systemUser
try chmod u+x /home/$systemUser/BuildSystem.sh
shout "Run 'sudo ./BuildSystem.sh' as user $systemUser"
shout "Switching to user $systemUser"
su - $systemUser