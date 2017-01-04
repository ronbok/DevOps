#!/bin/sh
echo "toor      ALL=(ALL:ALL)   NOPASSWD:       ALL" >> /etc/sudoers
mkdir /datadrive
mkfs -L vol200G -t ext4 /dev/sdc -F -F
mount /dev/sdc /datadrive
df -BG

newUUID=`blkid -o full|grep vol200G|awk '{print $3}'|cut -d'"' -f 2`
cat /etc/fstab
echo -e "UUID="$newUUID" /datadrive\t\t  ext4    defaults\t  0 0">>/etc/fstab
cat /etc/fstab




