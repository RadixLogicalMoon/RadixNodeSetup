#!/bin/bash

# Global Variables
LOGFILE=log/radixNodeInstall.log

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

read -r -p "Do you want to create a new validator node key (y/n)? " babylonMigrationSetup
while [ !("$babylonMigrationSetup" == y || "$babylonMigrationSetup" == n)]; do
    read -r -p "Do you want to create a new validator node key (y/n)? " babylonMigrationSetup
done

# 1. Install dependencies 
shout  "Installing dependencies and initiate randomness to securely generate keys"
try sudo apt install -y rng-tools openjdk-17-jdk unzip jq curl wget docker.io
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


# 5. Create System D Service File
shout "Installing Sytem D service"
sudo curl -Lo /etc/systemd/system/radixdlt-node.service https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/radixdlt-node.service
shout "Enable node service at boot"
sudo systemctl enable radixdlt-node.service


# 6. Add radixdlt to path
shout "Adding radixdlt to path" 
sudo sh -c 'cat > /etc/profile.d/radixdlt.sh << EOF
PATH=$PATH:/opt/radixdlt
EOF'

# 7. Install the Radix Distribution (Node)
shout "Installing the Radix Distribution (Node)"
cd /home/radixdlt
#sudo -u radixdlt curl -Lo /opt/radixdlt/update-node https://gist.githubusercontent.com/katansapdevelop/d12f931f35faa35dbbe20d6793149e8b/raw/0927c1a68a5a83b5c368256443bcfe233e883869/update-node && chmod +x /opt/radixdlt/update-node
#sudo -u radixdlt /opt/radixdlt/./update-node

#Download the latest release from the CLI
export PLATFORM_NAME=arch-linux-x86_64
export VERSION=rcnet-v3.1-r5
wget https://github.com/radixdlt/babylon-node/releases/download/${VERSION}/babylon-node-${VERSION}.zip
wget https://github.com/radixdlt/babylon-node/releases/download/${VERSION}/babylon-node-rust-${PLATFORM_NAME}-release-${VERSION}.zip
unzip babylon-node-${VERSION}.zip
unzip babylon-node-rust-${PLATFORM_NAME}-release-${VERSION}.zip
mkdir -p /etc/radixdlt/node/
mv core-${VERSION} /etc/radixdlt/node/${VERSION}
# Move the java application into the systemd service directory
mkdir -p /etc/radixdlt/node/
mv core-${VERSION} /etc/radixdlt/node/${VERSION}


# 8. Create Secrets Directories
shout "Creating Secret Directories"
cd /etc/radixdlt/node
sudo -u radixdlt mkdir /etc/radixdlt/node/secrets-validator
sudo -u radixdlt mkdir /etc/radixdlt/node/secrets-fullnode

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

# 9. Set environment file
read -r -p "Enter validator key password? " validatorKeyPassword

NODE_JAVA_OPTS=JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
if [ "$babylonMigrationSetup" == "y" ]; then
    NODE_JAVA_OPTS="--enable-preview -server -Xms12g -Xmx12g  -XX:MaxDirectMemorySize=2048m -XX:+HeapDumpOnOutOfMemoryError -XX:+UseCompressedOops -Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts -Djavax.net.ssl.trustStoreType=jks -Djava.security.egd=file:/dev/urandom -DLog4jContextSelector=org.apache.logging.log4j.core.async.AsyncLoggerContextSelector"
fi
sudo -u radixdlt cat > /etc/radixdlt/node/secrets-validator/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$validatorKeyPassword
EOF

read -r -p "Enter full node key password? " fullNodeKeyPassword
sudo -u radixdlt cat > /etc/radixdlt/node/secrets-fullnode/environment << EOF
JAVA_OPTS=$NODE_JAVA_OPTS
RADIX_NODE_KEYSTORE_PASSWORD=$fullNodeKeyPassword
EOF


# 10. Restrict access to secrets
echo "Restrict access to secrets"
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-validator
sudo chown -R radixdlt:radixdlt /etc/radixdlt/node/secrets-fullnode
sudo -u radixdlt chmod 500 /etc/radixdlt/node/secrets-validator && chmod 400 /etc/radixdlt/node/secrets-validator/*
sudo -u radixdlt chmod 500 /etc/radixdlt/node/secrets-fullnode && chmod 400  /etc/radixdlt/node/secrets-fullnode/*

# 11. Node Configuration
shout "Download Node Configuration File or you can enter Florians https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/default.config"
read -r -p "Enter the URL to your Config file ? " configFileURL
sudo -u radixdlt curl -Lo /etc/radixdlt/node/default.config "$configFileURL"

shout "If using florian's script make sure you edit the file using 'sudo nano /etc/radixdlt/node/default.config' and update your host_ip address at a minimum" 

# 12. Install Switch Script 
shout "Installing the switch script"
sudo -u radixdlt curl -Lo /opt/radixdlt/switch-mode.sh https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && chmod +x /opt/radixdlt/switch-mode.sh
shout "If using NGINX this script needs to be updated to change the port from 3333 to 3334"

shout "Run 'sudo su - radixdlt' to switch to the radixdlt user"
shout "Run '. /opt/radixdlt/switch-mode.sh fullnode' to start the node as a full node"
shout "Run 'curl -s localhost:3333/system/health | jq' to check the node status"

# 13. Install Grafana SystemD Service
read -r -p "Install Grafana (y/n)? " installGrafana
if [ "$installGrafana" = "y" ]; then
  echo "Follow the steps from Florian's guide to setup Grafana 'https://github.com/fpieper/fpstaking/blob/main/docs/validator_guide.md#monitoring-with-grafana-cloud'"
fi