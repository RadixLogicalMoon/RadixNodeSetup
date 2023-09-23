# BashScripts
Bash Scripts to initialise the Validator Nodes prior to installing node software


## 1. Run CreateDefaultUser.sh
This script can be run to create the new default user.  Download the file using the following command
```
wget -O CreateDefaultUser.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/development/InitialiseSystem/CreateDefaultUser.sh
```

Now make script executable and execute it
```
chmod u+x CreateDefaultUser.sh
sudo ./CreateDefaultUser.sh
```


## 2. Run BuildSystem.sh
This script can be run as the new default user.  Once the previous script completes
it should have downloaded the script into the 'home' directory of the new default user  
and switched to that user.  So to kick off the system build run the following command

```
sudo ./BuildSystem.sh
``` 

### SSH Key
If you plan to setup an ssh key for the system user.  SCP the file to the home directory of the system user
```
##Template
scp -P <customer port> /file/to/send <username>@<remote>:/home/<default_user>

##Example
scp -P 1234 ~/.ssh/id_rsa admin@12.123.123.12:/home/admin
```