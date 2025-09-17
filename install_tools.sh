#!/usr/bin/env bash

set -x

curl -sSL -O https://packages.microsoft.com/config/$(source /etc/os-release && echo "$ID/$VERSION_ID")/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y aznfs awscli
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
