# Node Install Scripts
Bash Scripts for SystemD Validator Node Install and Additionally Nginx install if you wish to but it is not required

## 1. Running InstallSystemDRadixNode.sh
This script must be run as the new root user that you created during the Initialise System process.  

Download the InstallSystemDRadixNode.sh script using command 
```
wget -O InstallSystemDRadixNode.sh https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/main/BuildSystemDNode/InstallSystemDRadixNode.sh
``` 

Then run the following to make it executable and execute it
```
chmod u+x InstallSystemDRadixNode.sh
sudo ./InstallSystemDRadixNode.sh
``` 

### Transfer your keys
You will need to transfer your keys to the remote machine using the following commands
```
scp -P <customer port> /file/to/send <username>@<remote>:/home/<admin user>
# Run this when the script prompts you too
sudo mv node-keystore.ks /etc/radixdlt/node/secrets-validator 
```
or this for the full node after you scp the file over
```
sudo mv node-keystore.ks /etc/radixdlt/node/secrets-fullnode 
```

Note you may need to scp the files to the usere home directory and then ```cp``` the files to the directories above

# 2. Running the Node

### radixdlt user
After login you need to switch to the radixdlt user, which has no password. To switch to this user you need to run the command ```sudo su - radixdlt```.  
You will need this to run any scripts etc.  

### Starting the node 
To start the node we need to use Florians script and excure the command ```switch-mode fullnode``` to start a full node or ```switch-mode validator``` to start a validator.

if there are any issues check the log files using ```sudo nano /etc/radixdlt/node/logs/radixdlt-core.log```

### Stopping the node
To stop the node run ```sudo systemctl stop radixdlt-node.service```

### Checking the Node is running
Use the following commands to check the health of the Node
```
# Check Node Health
curl -s localhost:3334/system/health | jq

# Check Node Sync Status
curl -s localhost:3334/system/network-sync-status | jq

# Check peers (must be both IN and OUT connections)
curl -s localhost:3334/system/peers | jq
```

##  3. Grafana Cloud Setup
