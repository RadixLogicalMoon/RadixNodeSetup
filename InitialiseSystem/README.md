# BashScripts
Bash Scripts to initialise the Validator Nodes prior to installing node software


## 1. Run CreateDefaultUser.sh
This script only needs to be run if you need to create a new default user.  Download the file using the following command
```
wget -O CreateDefaultUser.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/main/InitialiseSystem/CreateDefaultUser.sh
```

Now make script executable and execute it
```
chmod u+x CreateDefaultUser.sh
sudo ./CreateDefaultUser.sh
```


## 2. Run BuildSystem.sh
This script can be run as the default user.

If you did not run the default user script, you will need to download the build system script manually
```
wget -O BuildSystem.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/development/InitialiseSystem/BuildSystem.sh
```

Now make script executable
```
chmod u+x BuildSystem.sh
```

If you ran the default user script it should automatically download this script into the 'home' directory of the new default user  
and switched to that user.  So to kick off the system build run the following command

```
sudo ./BuildSystem.sh
``` 

### SSH Key
If you plan to setup an ssh key for the new system user.  SCP a copy of the public key file to the home directory of the new system user.  
(This is not rquired if you have already done this)
```
##Template
scp -P <customer port> /file/to/send <username>@<remote>:/home/<default_user>

##Example
scp -P 1234 ~/.ssh/id_rsa.pub admin@12.123.123.12:/home/admin
```