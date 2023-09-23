#!/bin/bash

shout() { echo "$0: $*" >&2; }
die() { shout "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }

echo "Preparing to install SystemD Radix Node"
echo "This script should only be executed on a clean build"

read -r -p "Do you want to create a new validator node key (y/n)? " babylonMigrationSetup
while [ !("$babylonMigrationSetup" == y || "$babylonMigrationSetup" == n)]; do
             read -r -p "Do you want to create a new validator node key (y/n)? " babylonMigrationSetup
done

# 1. Install dependencies
echo "Installing dependencies and initiate randomness to securely generate keys"
sudo apt install -y rng-tools openjdk-17-jdk unzip jq curl wget docker.io
sudo rngd -r /dev/random
echo "successfully installed dependencies and initiated randomness"

# 2. Create Radix User
echo "Creating radixdlt User. User is created with a locked password and can only be switched using 'sudo su - radixdlt'"
sudo useradd radixdlt -m -s /bin/bash

# 3. Allow Radix User to control node service
echo "Allow Radix User to control node service"
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
echo "Create Config and Data Directories"
sudo mkdir /etc/radixdlt/
sudo chown radixdlt:radixdlt -R /etc/radixdlt
sudo mkdir /data
sudo chown radixdlt:radixdlt /data
sudo mkdir /babylon-ledger
sudo chown radixdlt:radixdlt /babylon-ledger
sudo mkdir -p /opt/radixdlt/releases
sudo chown -R radixdlt:radixdlt /opt/radixdlt


# 5. Install System D Service
echo "Installing Sytem D service"
sudo curl -Lo /etc/systemd/system/radixdlt-node.service https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/radixdlt-node.service
echo "Enable node service at boot"
sudo systemctl enable radixdlt-node.service


# 6. Add radixdlt to path
echo "Adding radixdlt to path" 
sudo sh -c 'cat > /etc/profile.d/radixdlt.sh << EOF
PATH=$PATH:/opt/radixdlt
EOF'

# 7. Install the Radix Distribution (Node)
echo "Installing the Radix Distribution (Node)"
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
echo "Creating Secret Directories"
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
echo "Download Node Configuration File or you can enter Florians https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/config/default.config"
read -r -p "Enter the URL to your Config file ? " configFileURL
sudo -u radixdlt curl -Lo /etc/radixdlt/node/default.config "$configFileURL"

echo "If using florian's script make sure you edit the file using 'sudo nano /etc/radixdlt/node/default.config' and update your host_ip address at a minimum" 

# 12. Install Switch Script 
echo "Installing the switch script"
sudo -u radixdlt curl -Lo /opt/radixdlt/switch-mode.sh https://raw.githubusercontent.com/fpieper/fpstaking/main/docs/scripts/switch-mode && chmod +x /opt/radixdlt/switch-mode.sh
echo "If using NGINX this script needs to be updated to change the port from 3333 to 3334"

echo "Run 'sudo su - radixdlt' to switch to the radixdlt user"
echo "Run '. /opt/radixdlt/switch-mode.sh fullnode' to start the node as a full node"
echo "Run 'curl -s localhost:3333/system/health | jq' to check the node status"

# 13. Install Grafana SystemD Service
read -r -p "Install Grafana (y/n)? " installGrafana
if [ "$installGrafana" = "y" ]; then
  echo "Follow the steps from Florian's guide to setup Grafana 'https://github.com/fpieper/fpstaking/blob/main/docs/validator_guide.md#monitoring-with-grafana-cloud'"
fi