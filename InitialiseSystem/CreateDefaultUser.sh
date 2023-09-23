#!/bin/bash

LOGFILE=log/nodesetup.log

shout() { echo "$0: $*" >&2; }
die() { shout "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }


mkdir log
echo "This script should only be executed on a clean build" >> $LOGFILE


# 1. User Setup
read -r -p "Name of default system user to create: " systemUser
echo "Creating user $systemUser" >> $LOGFILE
adduser "$systemUser"
adduser "$systemUser" sudo

if id "$systemUser" &>/dev/null; then
    echo "User $systemUser Successfully Created" >> $LOGFILE
else
    echo "User $systemUser not found" >> $LOGFILE
    die
fi

echo "Ensure you run the BuildSystem.sh script using sudo" >> $LOGFILE
echo "Switching to user $systemUser" >> $LOGFILE
su - "$systemUser"