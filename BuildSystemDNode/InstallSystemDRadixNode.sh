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
try sudo apt install -y rng-tools openjdk-17-jdk unzip jq curl wget docker.io
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
sudo sh -c "cat > /etc/sudoers.d/radixdlt << EOF
radixdlt ALL= NOPASSWD: /bin/systemctl enable radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl restart radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl stop radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl start radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl reload radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node.service
radixdlt ALL= NOPASSWD: /bin/systemctl enable radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl restart radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl stop radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl start radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl reload radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl status radixdlt-node
radixdlt ALL= NOPASSWD: /bin/systemctl restart grafana-agent
radixdlt ALL= NOPASSWD: /bin/sed -i s/fullnode/validator/g /etc/grafana-agent.yaml
radixdlt ALL= NOPASSWD: /bin/sed -i s/validator/fullnode/g /etc/grafana-agent.yaml
EOF"


# 4. Create Config and Data Directories
shout "Create Config and Data Directories"
try sudo mkdir /etc/radixdlt/
try sudo chown radixdlt:radixdlt -R /etc/radixdlt
try sudo mkdir /data
try sudo chown radixdlt:radixdlt /data
try sudo mkdir /babylon-ledger
try sudo chown radixdlt:radixdlt /babylon-ledger
try sudo mkdir -p /opt/radixdlt/releases
try sudo chown -R radixdlt:radixdlt /opt/radixdlt

# New Directories for Babylon Node
try sudo mkdir -p /etc/radixdlt/node/
try sudo chown -R radixdlt:radixdlt /etc/radixdlt/node
try sudo mkdir -p /usr/lib/jni



# 5. Create System D Service File
shout "Installing Sytem D service"
try sudo curl -Lo /etc/systemd/system/radixdlt-node.service https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/main/BuildSystemDNode/config/babylon/SystemD/radixdlt-node.service
sudo chown radixdlt:radixdlt /etc/systemd/system/radixdlt-node.service

# 10  Enable Your Node at Startup
shout "Enabling node service at boot"
sudo systemctl enable radixdlt-node.service

# 5.1 Add radixdlt to path
shout "Adding radixdlt to path" 
sudo sh -c 'cat > /etc/profile.d/radixdlt.sh << EOF
PATH=$PATH:/opt/radixdlt
EOF'

# 6. Download & Install the Radix Distribution (Node)
shout "Download & Installing the Radix Distribution (Node)"

#sudo -u radixdlt curl -Lo /opt/radixdlt/update-node https://gist.githubusercontent.com/katansapdevelop/d12f931f35faa35dbbe20d6793149e8b/raw/0927c1a68a5a83b5c368256443bcfe233e883869/update-node && chmod +x /opt/radixdlt/update-node
#sudo -u radixdlt /opt/radixdlt/./update-node

#Download the latest release from the CLI
shout "Changing directory to '/opt/radixdlt/releases'"
cd /opt/radixdlt/releases 
shout "Changed directory to $PWD"
shout "Downloading the Radix Distribution (Node)"
export PLATFORM_NAME=arch-linux-x86_64
export VERSION=v1.0.0
export LIBRARY_FILENAME=libcorerust.so
try sudo -u radixdlt wget https://github.com/radixdlt/babylon-node/releases/download/$VERSION/babylon-node-$VERSION.zip
try sudo -u radixdlt wget https://github.com/radixdlt/babylon-node/releases/download/$VERSION/babylon-node-rust-$PLATFORM_NAME-release-$VERSION.zip
try sudo -u radixdlt unzip babylon-node-$VERSION.zip
try sudo -u radixdlt unzip babylon-node-rust-$PLATFORM_NAME-release-$VERSION.zip

shout "Installing the Radix Node"
# 6.4 Move the java application into the systemd service directory
try sudo -u radixdlt mkdir /etc/radixdlt/node/$VERSION
try sudo -u radixdlt mv core-$VERSION /etc/radixdlt/node/$VERSION


# 6.5 Move the library into your Java Class Path
shout "Moving Rust Core to Java Class Path"
try sudo unzip babylon-node-rust-$PLATFORM_NAME-release-$VERSION.zip
try sudo mv $LIBRARY_FILENAME /usr/lib/jni/$LIBRARY_FILENAME


# 7. Create Keys Secrets Directories
#  7.1 Create Directories
shout "Creating Secret Directories"
cd /etc/radixdlt/node
shout "Changed directory to $PWD"
sudo -u radixdlt mkdir /etc/radixdlt/node/secrets-validator
sudo -u radixdlt mkdir /etc/radixdlt/node/secrets-fullnode

#  7.2 Create Keys
read -r -p "Do you want to create a new full node key (y/n)? " createFullNodeKey
if [ "$createFullNodeKey" = "y" ]; then
  read -r -p "Enter Full Node Key Password: " fullNodeKeyPassword
  docker run --rm  -v /etc/radixdlt/node/secrets/:/keygen/key radixdlt/keygen:v1.4.1   --keystore=secrets-fullnode/node-keystore.ks --password="$fullNodeKeyPassword" 
fi

read -r -p "Do you want to create a new validator node key (y/n)? " createValidatorNodeKey
if [ "$createValidatorNodeKey" = "y" ]; then
  read -r -p "Enter Validator Node Key Password: " validatorNodeKeyPassword
  docker run --rm  -v /etc/radixdlt/node/secrets/:/keygen/key radixdlt/keygen:v1.4.1   --keystore=secrets-validator/node-keystore.ks --password="$validatorNodeKeyPassword"
fi


read -r -p "Copy the secret keys to the Node or you've created new ones. Is it done yet (y/n)? " keysCopied
while [ "$keysCopied" != y ]; do
    read -r -p "Copy the secret keys to the Node or you've created new ones. Is it done yet (y/n)? " keysCopied
done
sudo -u radixdlt chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator/
sudo -u radixdlt chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode/
cd /etc/radixdlt/node
shout "Changed directory to $PWD"

# 7.2. Set environment file
shout "Setting password and java opts in environment file"
read -r -p "Enter validator key password? " validatorKeyPassword

NODE_JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
sudo -u radixdlt cat > /etc/radixdlt/node/secrets-validator/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$validatorKeyPassword
EOF

read -r -p "Enter full node key password? " fullNodeKeyPassword
sudo -u radixdlt cat > /etc/radixdlt/node/secrets-fullnode/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$fullNodeKeyPassword
EOF


# 7.3. Restrict access to secrets (Not in standard docs)
shout  "Restricting access to secrets directories"
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode
sudo -u radixdlt chmod 500 /etc/radixdlt/node/secrets-validator && chmod 400 /etc/radixdlt/node/secrets-validator/*
sudo -u radixdlt chmod 500 /etc/radixdlt/node/secrets-fullnode && chmod 400  /etc/radixdlt/node/secrets-fullnode/*

# 8. Node Configuration
shout "Download Node Configuration File!!"
shout "You can enter our default one if required https://raw.githubusercontent.com/RadixLogicalMoon/RadixNodeSetup/main/BuildSystemDNode/config/babylon/NodeOnly/default.config"
shout "If using our script make sure you edit the file using 'sudo nano /etc/radixdlt/node/default.config' and update all missing sections" 
read -r -p "Enter the URL to your Config file ? " configFileURL
sudo -u radixdlt curl -Lo /etc/radixdlt/node/default.config "$configFileURL"



# 9. Install Switch Script 
shout "Installing the switch script"
sudo -u radixdlt curl -Lo /opt/radixdlt/switch-mode.sh https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && chmod +x /opt/radixdlt/switch-mode.sh
shout "If using NGINX this script needs to be updated to change the port from 3333 to 3334"

shout "Run 'sudo su - radixdlt' to switch to the radixdlt user"
shout "Run '. /opt/radixdlt/switch-mode.sh fullnode' to start the node as a full node"
shout "Run 'curl -s localhost:3333/system/health | jq' to check the node status"

# 10. Install Grafana SystemD Service
read -r -p "Install Grafana (y/n)? " installGrafana
if [ "$installGrafana" = "y" ]; then
  echo "Follow the steps from Florian's guide to setup Grafana 'https://github.com/fpieper/fpstaking/blob/main/docs/validator_guide.md#monitoring-with-grafana-cloud'"
fi