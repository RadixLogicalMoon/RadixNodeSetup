#!/bin/bash

# Global Variables
LOGFILE=$PWD/log/radixNodeInstall.log

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

shout "Preparing to install SystemD Radix Node"
shout "This script should only be executed on a clean build"


# 1. Install dependencies 
shout  "Installing dependencies and initiate randomness to securely generate keys"
try sudo apt install -y rng-tools openjdk-17-jdk unzip jq docker.io
rngdPID=$(pgrep rngd)
if [ $rngdPID != "" ]; then
  shout "Killing process id $rngdPID found running for rngd"
  kill $rngdPID
fi
try sudo rngd -r /dev/random
shout "successfully installed dependencies and initiated randomness"

# 2. Configure Ports (Already Done as part of system build)

# 3. Create Radix User
shout "Creating radixdlt User. User is created with a locked password and can only be switched using 'sudo su - radixdlt'"
# 3.1 Create User 
try sudo useradd radixdlt -m -s /bin/bash

# 3.2 Allow Radix User to control node service
shout "Allow Radix User to control node service"
sudo sh -c 'cat > /etc/sudoers.d/radix-babylon << EOF
radixdlt ALL= NOPASSWD: /bin/systemctl enable radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl restart radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl stop radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl start radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl reload radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon.service
radixdlt ALL= NOPASSWD: /bin/systemctl enable radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl restart radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl stop radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl start radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl reload radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl status radix-babylon
radixdlt ALL= NOPASSWD: /bin/systemctl restart grafana-agent
radixdlt ALL= NOPASSWD: /bin/sed -i s/fullnode/validator/g /etc/grafana-agent.yaml
radixdlt ALL= NOPASSWD: /bin/sed -i s/validator/fullnode/g /etc/grafana-agent.yaml
EOF'


# 4. Create Config and Data Directories
shout "Create Config and Data Directories"
try sudo mkdir /etc/radix-babylon/
try sudo chown radixdlt:radixdlt -R /etc/radix-babylon
try sudo mkdir /babylon-ledger
try sudo chown radixdlt:radixdlt -R /babylon-ledger
try sudo mkdir -p /opt/radix-babylon/releases
try sudo chown -R radixdlt:radixdlt /opt/radix-babylon

# 5. Create System D Service File
shout "Installing Sytem D service"
try sudo curl -Lo /etc/systemd/system/radix-babylon.service https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/radix-babylon.service
sudo chown radixdlt:radixdlt /etc/systemd/system/radix-babylon.service

# 10  Enable Your Node at Startup
shout "Enabling node service at boot"
sudo systemctl enable radix-babylon.service

# 5.1 Add radixdlt to path
shout "Adding radixdlt to path" 
sudo sh -c 'cat > /etc/profile.d/radix-babylon.sh << EOF
PATH=$PATH:/opt/radix-babylon
EOF'

# 6. Download & Install the Radix Distribution (Node)
shout "Download & Installing the Radix Distribution (Node)"
sudo -u radixdlt curl -Lo /opt/radix-babylon/update-node https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/update-node && chmod +x /opt/radix-babylon/update-node
sudo -u radixdlt /opt/radix-babylon/./update-node


# 7. Create Keys Secrets Directories
#  7.1 Create Directories
shout "Creating Secret Directories"
cd /etc/radix-babylon/node
shout "Changed directory to $PWD"
sudo -u radixdlt mkdir /etc/radix-babylon/node/secrets-validator
sudo -u radixdlt mkdir /etc/radix-babylon/node/secrets-fullnode

#  7.2 Create Keys
read -r -p "Do you want to create a new full node key (y/n)? " createFullNodeKey
if [ "$createFullNodeKey" = "y" ]; then
  read -r -p "Enter Full Node Key Password: " fullNodeKeyPassword
  sudo docker run --rm  -v /etc/radix-babylon/node/secrets-fullnode/:/keygen/key radixdlt/keygen:v1.4.1   --keystore=/keygen/key/node-keystore.ks --password="$fullNodeKeyPassword" 
fi

read -r -p "Do you want to create a new validator node key (y/n)? " createValidatorNodeKey
if [ "$createValidatorNodeKey" = "y" ]; then
  read -r -p "Enter Validator Node Key Password: " validatorNodeKeyPassword
  sudo docker run --rm  -v /etc/radix-babylon/node/secrets-validator/:/keygen/key radixdlt/keygen:v1.4.1   --keystore=/keygen/key/node-keystore.ks --password="$validatorNodeKeyPassword"
fi


read -r -p "Copy the secret keys to the Node or you've created new ones. Is it done yet (y/n)? " keysCopied
while [ "$keysCopied" != y ]; do
    read -r -p "Copy the secret keys to the Node or you've created new ones. Is it done yet (y/n)? " keysCopied
done
sudo -u radixdlt chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-validator/
sudo -u radixdlt chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-fullnode/
cd /etc/radix-babylon/node
shout "Changed directory to $PWD"

# 7.2. Set environment file
shout "Setting password and java opts in environment file"
read -r -p "Enter validator key password? " validatorKeyPassword

NODE_JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector -Djava.library.path=/etc/radix-babylon/node/jni"
sudo -u radixdlt cat > /etc/radix-babylon/node/secrets-validator/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$validatorKeyPassword
EOF

read -r -p "Enter full node key password? " fullNodeKeyPassword
sudo -u radixdlt cat > /etc/radix-babylon/node/secrets-fullnode/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$fullNodeKeyPassword
EOF

# 7.3. Restrict access to secrets (Not in standard docs)
shout  "Restricting access to secrets directories"
sudo chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-validator
sudo chown -R radixdlt:radixdlt /etc/radix-babylon/node/secrets-fullnode
sudo -u radixdlt chmod 500 /etc/radix-babylon/node/secrets-validator && chmod 400 /etc/radix-babylon/node/secrets-validator/*
sudo -u radixdlt chmod 500 /etc/radix-babylon/node/secrets-fullnode && chmod 400  /etc/radix-babylon/node/secrets-fullnode/*

# 8. Node Configuration
shout "Download Node Configuration File!!"
shout "You can enter our default one if required https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/main/BuildSystemDNode/config/babylon/NodeOnly/default.config"
shout "If using our script make sure you edit the file using 'sudo nano /etc/radix-babylon/node/default.config' and update all missing sections" 
read -r -p "Enter the URL to your Config file ? " configFileURL
sudo -u radixdlt curl -Lo /etc/radix-babylon/node/default.config "$configFileURL"

# 9. Install Switch Script 
shout "Installing the switch script"
sudo -u radixdlt curl -Lo /opt/radix-babylon/switch-mode.sh https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && chmod +x /opt/radix-babylon/switch-mode.sh
shout "If using NGINX this script needs to be updated to change the port from 3333 to 3334"

# 10. Downloading & install latest ledger copy 
shout "Downloading latest ledger copy"
cd /backup
current_date=$(date +%Y-%m-%d)
sudo curl -O https://radix-snapshots.b-cdn.net/$current_date/RADIXDB.tar.zst 
shout "Unpacking latest ledger copy"
LEDGER_DIR=/babylon-ledger
sudo rm -rf $LEDGER_DIR/*
sudo tar --use-compress-program=zstdmt -xvf RADIXDB.tar.zst -C $LEDGER_DIR/
sudo chown -R radixdlt:radixdlt $LEDGER_DIR
shout "Deleting downloaded ledger copy"
sudo rm -rf /backup/*

shout "Run 'sudo su - radixdlt' to switch to the radixdlt user"
shout "Run '. /opt/radix-babylon/switch-mode.sh fullnode' to start the node as a full node"
shout "Run 'curl -s localhost:3334/system/health | jq' to check the node status"
shout "Run 'curl -s localhost:3334/system/network-sync-status | jq' to check the sync status"
shout "Run 'curl -s localhost:3334/system/peers | jq' to check peers.  Remember there should be both IN and OUT connections or ports are not open correctly or the default.config file is not setup properly"

# 11. Install Grafana SystemD Service
read -r -p "Install Grafana (y/n)? " installGrafana
if [ "$installGrafana" = "y" ]; then
  echo "Follow the steps from Florian's guide to setup Grafana 'https://github.com/fpieper/fpstaking/blob/main/docs/validator_guide.md#monitoring-with-grafana-cloud'"
fi