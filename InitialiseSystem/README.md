# BashScripts
Bash Scripts to initialise the Validator Nodes prior to installing node software


## 1. Run CreateDefaultUser.sh
This script can be run to create the new root user.  
```
# Download the file
wget -O BuildSystem.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/development/InitialiseSystem/CreateDefaultUser.sh

# Make script executable and execute it
chmod u+x CreateDefaultUser.sh
sudo ./CreateDefaultUser.sh
```


## 2. Run BuildSystem.sh
This script can be run as the new root user.  Once the previous script completes
it should have downloaded the script into the 'home' directory of the new admin user  
and switched to that user.  So to kick off the system build run the following command
```
sudo ./BuildSystem.sh
``` 

