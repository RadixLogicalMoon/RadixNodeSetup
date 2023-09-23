# BashScripts
Bash Scripts for SystemD Validator Node Install and Additionally Nginx install if you wish to but it is not required

## 1. Running InstallSystemDRadixNode.sh
This script must be run as the new root user that you created during the Initialise System process.  

Download the InstallSystemDRadixNode.sh script using command ```wget -O InstallSystemDRadixNode.sh <url to raw file>``` 
Then run ```chmod u+x InstallSystemDRadixNode.sh``` and then execute via ```sudo ./InstallSystemDRadixNode.sh```.  

### Transfer your keys
You will need to transfer your keys to the remote machine using the following commands
```scp -P <customer port> /file/to/send <username>@<remote>:/etc/radixdlt/node/secrets-validator```
or this for the full node
```scp  -P <customer port> /file/to/send <username>@<remote>:/etc/radixdlt/node/secrets-fullnode```

Note you may need to scp the files to the usere home directory and then ```cp``` the files to the directories above

### radixdlt user
After login you need to switch to the radixdlt user, which has no password. To switch to this user you need to run the command ```sudo su - radixdlt```.  
You will need this to run any scripts etc.  

### Starting the node 
To start the node we need to use Florians script and excure the command ```switch-mode fullnode``` to start a full node or ```switch-mode validator``` to start a validator.

if there are any issues check the log files using ```sudo nano /etc/radixdlt/node/logs/radixdlt-core.log```

### Stopping the node
To stop the node run ```sudo systemctl stop radixdlt-node.service```

## 2. Running InstallNginx.sh
This script must be run as the new root user that you created during the Initialise System process.  

Download the InstallSystemDRadixNode.sh script using command ```wget -O InstallNginx.sh <url to raw file>``` 
Then run ```chmod u+x InstallNginx.sh``` and then execute via ```sudo ./InstallNginx.sh```.  

After installing the script ensure that the file /etc/radixdlt/node/default.config has the use proxy protocol set to true and the network.p2p.listen_port as 30001 so as not to conflict with Nginx.  See [Validator Proxy Options Explained](https://radixtalk.com/t/validator-proxy-options-explained/493) on [Radix Talk](https://radixtalk.com).  Also don't forget to update the nginx config for the proxy_pass setting
```
network.p2p.use_proxy_protocol=true
network.p2p.listen_port=30001
```

To edit the file run ```sudo nano /etc/radixdlt/node/default.config```

### Resync the Node and Nginx
Restart the node and Nginx to resync them after an install if any issues
```
sudo su - radixdlt
sudo systemctl restart radixdlt-node.service
exit
sudo systemctl restart nginx
```

### Checking the Nginx Logs
Run the following to check for any issues with Nginx
```
tail -f /var/log/nginx/error.log
```

### Stopping Nginx
To stop the nginx run ```sudo systemctl stop nginx```

