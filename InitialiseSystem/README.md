# BashScripts
Bash Scripts to initialise the Validator Nodes prior to installing node software

## 1. Run CreateDefaultUser.sh 
Running this script is optional if you have already created a system user other than root and you can jump straight to script 2  

Download the CreateDefaultUser.sh script using command ```wget -O CreateDefaultUser.sh <url to raw file>``` 
Then run ```chmod u+x CreateDefaultUser.sh``` and then execute via ```./CreateDefaultUser.sh```
On completion you will automatically be logged in as the new root user 

## 2. Run BuildSystem.sh
This script can be run as the new root user.  

Download the BuildSystem.sh script using command ```wget -O BuildSystem.sh <url to raw file>``` 
Then run ```chmod u+x BuildSystem.sh``` and then execute via ```sudo ./BuildSystem.sh```.  This must be run as 'sudo'.

When running this script you will be prompted to enter Ubuntu Personal Token (Max 3 Machines for Free Tier). This is required to use the Ubuntu Live Patch Service.  Login to https://ubuntu.com/advantage to retrieve the access token.  (For testing purposes, leave this blank and hit enter to continue)

### If you don't have a livepatch token
Enter an empty token when requested and then run ```sudo canonical-livepatch enable``` with the token obtained from https://ubuntu.com/livepatch or ```sudo ua attach <TOKEN>```