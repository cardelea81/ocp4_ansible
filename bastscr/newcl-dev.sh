#!/bin/bash

# This script automates the preparation of a User-Provisioned Infrastructure (UPI)
# OpenShift installation. It downloads necessary CoreOS images, generates ignition
# files, and restarts key services.

# --- Cleanup Phase ---
# Remove old ignition files from the web server directory and old CoreOS images
echo "--- Cleanup Phase ---"
echo "Removing old ignition files and CoreOS images..."
ls -latrh /var/www/html/ignition/*.ign
rm -rf /var/www/html/ignition/*.ign
rm -rf /var/lib/tftpboot/rhcos/*
rm -rf /usr/local/bin/oc
rm -rf /usr/local/bin/kubectl
rm -rf /usr/local/bin/openshift-install
echo "Cleanup complete."

# Download the OCP client
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.19.10/openshift-client-linux.tar.gz
tar xvf openshift-client-linux.tar.gz
mv oc kubectl /usr/local/bin
rm -f README.md LICENSE openshift-client-linux.tar.gz
oc version --client
sleep 3
kubectl version --client
#Download OpenShift installer binary
wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.19.10/openshift-install-linux.tar.gz
tar xvf openshift-install-linux.tar.gz
mv openshift-install /usr/local/bin
rm -f README.md LICENSE openshift-install-linux.tar.gz
openshift-install version
# --- CoreOS Image Download Phase ---
# Download the CoreOS kernel, initramfs, and rootfs images.
# These files are served via TFTP and HTTP respectively.
echo "--- CoreOS Image Download Phase ---"

# Download the CoreOS kernel file for TFTP booting
echo "Downloading CoreOS kernel..."
curl -v -o /var/lib/tftpboot/rhcos/kernel https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/rhcos-installer-kernel.x86_64

# Download the CoreOS Installer initramfs image
echo "Downloading CoreOS initramfs..."
curl -v -o /var/lib/tftpboot/rhcos/initramfs.img https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/rhcos-installer-initramfs.x86_64.img

# Download the Red Hat CoreOS rootfs image
echo "Downloading CoreOS rootfs image..."
curl -v -o /var/www/html/rhcos/rootfs.img https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/4.19/4.19.10/rhcos-live-rootfs.x86_64.img

echo "CoreOS image download complete."

# --- Ignition File Generation Phase ---
# Prepare the working directory and generate the ignition files.
echo "--- Ignition File Generation Phase ---"

# Clear the known_hosts file to prevent SSH errors
echo "Clearing SSH known_hosts..."
echo > ~/.ssh/known_hosts

# Remove and recreate the ocp4 directory to ensure a clean state
echo "Creating a clean working directory 'ocp4'..."
rm -rf ocp4
mkdir ocp4
ls -latr ocp4

# Copy the base install-config to the working directory
echo "Copying install-config-base.yaml to ocp4/..."
cp -v install-config-base.yaml ocp4/install-config.yaml

# Change into the ocp4 directory
cd ocp4

# Create Kubernetes manifests from the install-config.yaml with debug output
echo "Creating manifests with debug logs..."
openshift-install create manifests --log-level=debug

# Display the manifest file tree
sleep 5
echo "Manifests created. File tree:"
tree

# Create the ignition configuration files with debug output
echo "Creating ignition configuration files with debug logs..."
openshift-install create ignition-configs --log-level=debug

# Display the ignition file tree
echo "Ignition files created. File tree:"
tree

# List the newly created ignition files
echo "Listing new ignition files:"
ls -latrh /var/www/html/ignition/*.ign

# Copy the new ignition files to the web server directory
echo "Copying new ignition files to web server directory..."
cp -v *.ign /var/www/html/ignition

# Set the correct permissions for the ignition files
echo "Setting permissions for ignition files..."
chmod 644 /var/www/html/ignition/*.ign

echo "Ignition file generation complete."

# --- Service Restart Phase ---
# Restart key services to apply the changes.
echo "--- Service Restart Phase ---"
echo "Restarting haproxy, dhcpd, httpd, tftp, and named services..."
systemctl restart haproxy.service dhcpd httpd tftp named
echo "Service restart complete."

echo "Script finished successfully."

