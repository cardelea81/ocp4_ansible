#!/bin/bash
#Remove control plane node from OCP cluster
#Vars
MASTER=master02.ocp4.example.com
ID=$(oc -n openshift-etcd exec etcd-master01.ocp4.example.com -c etcdctl -- etcdctl member list -w table | grep -F "$MASTER" | awk '{print $2}')

#Drain and poweroff the master node
oc adm cordon $MASTER 
oc adm drain $MASTER --delete-emptydir-data --ignore-daemonsets=true --timeout=15s --force
#master01.ocp4.example.com
ssh core@$MASTER "sudo init 0"
# Remove the member using its ID
oc -n openshift-etcd exec etcd-master01.ocp4.example.com -c etcdctl -- etcdctl member remove $ID

#Check if the master node was removed
oc -n openshift-etcd exec etcd-master01.ocp4.example.com -c etcdctl -- etcdctl member list -w table

#Reove master node from cluster
oc delete node $MASTER
oc -n openshift-etcd delete secrets etcd-peer-$MASTER etcd-serving-$MASTER etcd-serving-metrics-$MASTER

# Generate a text file with the keys to delete.
oc -n openshift-etcd exec etcd-master01.ocp4.example.com -c etcdctl -- etcdctl get --keys-only --prefix / | grep $MASTER > keys-to-delete.txt
# Delete the keys from the generated file
for i in `cat keys-to-delete.txt`; do oc -n openshift-etcd exec etcd-master01.ocp4.example.com -c etcdctl -- etcdctl del $i ;done
#Remove masternode from haproxy 
sed -i "s/server $MASTER/#server $MASTER/" /etc/haproxy/haproxy.cfg
#Restart haproxy service
systemctl restart haproxy.service
