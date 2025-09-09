#!/bin/bash


#Remove old files
ls -latrh /var/www/html/ignition/*.ign
rm -rf /var/www/html/ignition/*.ign
rm -rf /var/lib/tftpboot/rhcos/*

#Download the CoreOS kernel file to this directory
curl -o /var/lib/tftpboot/rhcos/kernel  https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-installer-kernel.x86_64


#CoreOS Installer initramfs image
curl -o /var/lib/tftpboot/rhcos/initramfs.img  https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-installer-initramfs.x86_64.img

#Red Hat CoreOSrootfs image
curl -o /var/www/html/rhcos/rootfs.img  https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-live-rootfs.x86_64.img

echo > .ssh/known_hosts

rm -rf ocp4
mkdir ocp4
ls -latr ocp4
cp  -v install-config-base.yaml ocp4/install-config.yaml
cd ocp4
openshift-install create manifests
sleep 5
tree
sleep 2
openshift-install create ignition-configs
tree
ls -latrh /var/www/html/ignition/*.ign
cp -v *.ign /var/www/html/ignition
chmod 644 /var/www/html/ignition/*.ign


systemctl restart haproxy.service dhcpd httpd tftp named

