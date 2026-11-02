#!/bin/bash

set -euo pipefail

TOKEN='${token}'
USER='${user}'

echo "Starting VM setup..."

export TOKEN
export USER

# install docker
apt-get update -y
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable --now docker
usermod -aG docker $USER

# Wait until Docker daemon is fully responsive before proceeding
while ! systemctl is-active --quiet docker; do sleep 2; done

# install knoxctl
curl -sfL https://knoxctl-cli.s3.us-east-2.amazonaws.com/install.sh | sudo sh -s -- -b /usr/local/bin

# onboard
sudo -i -u $USER /usr/local/bin/knoxctl onboard vm cp-node \
    --version v0.12.5 \
    --join-token="$TOKEN" \
    --spire-host=spire.demo.accuknox.com \
    --pps-host=pps.demo.accuknox.com \
    --knox-gateway=knox-gw.demo.accuknox.com:3000 \
    --sumengine-viz="process,network,file" \

echo "VM setup complete."