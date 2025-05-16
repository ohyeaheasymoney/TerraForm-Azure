#!/bin/bash

# Update system packages
sudo dnf update -y

# Install required packages
sudo dnf install -y python3-devel redhat-rpm-config gcc git

# Configure firewall for PostgreSQL
sudo firewall-cmd --new-zone=postgresqlrule --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --permanent --zone=postgresqlrule --add-port=5432/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --add-port=10445/tcp
sudo firewall-cmd --runtime-to-permanent
sudo firewall-cmd --state
sudo firewall-cmd --list-all
# Enable SSH in firewall
sudo firewall-cmd --permanent --zone=public --add-service=ssh
sudo firewall-cmd --reload
# Setup PostgreSQL
sudo dnf install postgresql-server -y
sudo postgresql-setup --initdb
sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service
sudo systemctl status postgresql.service
sudo netstat -tuln | grep 5432

# Install and configure libvirt
sudo dnf install libvirt libvirt-daemon-kvm qemu-kvm -y
sudo systemctl status libvirtd
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
sudo usermod -aG libvirt eca

# Create necessary directories
mkdir -p /home/eca/Documents/ansible
mkdir -p /home/eca/Downloads/DellAuto
mkdir -p /home/eca/DellFirmware

# Clone Ansible repository
cd /home/eca/Documents/ansible/
sudo git clone https://github.com/ansible/ansible.git

# Install Ansible dependencies
sudo pip install -r /home/eca/Documents/ansible/ansible/requirements.txt
pip3 install --upgrade --user pip
pip3 install --upgrade --user ansible{,-lint,-builder,-navigator}
pip install --upgrade ansible

# Install resolvelib with version constraint
pip install 'resolvelib<0.9.0,>=0.5.3'

# Install dellemc.openmanage collection
ansible-galaxy collection install dellemc.openmanage --force
cd /home/eca/Documents/ansible/dellemc-openmanage-ansible-modules
sudo pip install -r requirements.txt

# Clone and install OMSDK
cd /home/eca/Documents/ansible/
sudo git clone https://github.com/dell/omsdk.git
sudo pip3 install omsdk --force
cd /home/eca/Documents/ansible/omsdk
pip3 install -r requirements-python3x.txt
sudo python3 setup.py install

# Install NFS and CIFS utilities
sudo dnf install nfs-utils cifs-utils -y

# Install and configure Samba
sudo dnf install samba samba-client -y
sudo systemctl enable smb
sudo systemctl enable nmb
sudo systemctl start smb
sudo systemctl start nmb

# Configure Samba share
smb_conf="[shared_folder]
   path = /home/eca/Downloads/DellAuto
   valid users = @smbgroup
   browsable = yes
   writable = yes
   guest ok = no

[ShareName]
   path = /home/eca/Downloads/DellAuto
   valid users = eca
   read only = no
"
echo "$smb_conf" | sudo tee /etc/samba/smb.conf

# Set Samba user passwords
(echo '12'; echo '12') | sudo smbpasswd -a eca
sudo smbpasswd -e eca

# Restart Samba services
sudo systemctl restart smb
sudo systemctl restart nmb

# Set SELinux booleans for Samba
sudo setsebool -P samba_enable_home_dirs 1
sudo setsebool -P samba_export_all_rw 1

# Reload firewall and add Samba service
sudo firewall-cmd --reload
sudo firewall-cmd --permanent --zone=public --add-service=samba

# Enable and start NFS services
sudo systemctl enable nfs-mountd.service
sudo systemctl enable nfs-server.service
sudo systemctl start nfs-mountd.service
sudo systemctl start nfs-server.service

# Restart NFS services
sudo systemctl restart nfs-mountd.service
sudo systemctl restart nfs-server.service

# Configure NFS Share
nfs_export="/home/eca/Downloads    192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)"
echo "$nfs_export" | sudo tee -a /etc/exports

# Update firewall rules for NFS
sudo firewall-cmd --permanent --zone=public --add-service=nfs
sudo firewall-cmd --reload

# Mount NFS Share
sudo mount -t nfs 192.168.0.251:/home/eca/Downloads /home/eca/DellFirmware

# Update /etc/fstab with NFS entry
fstab_entry="192.168.0.251:/home/eca/Downloads    /home/eca/DellFirmware   nfs   defaults 0 0"
echo "$fstab_entry" | sudo tee -a /etc/fstab

# Reload systemd configuration
sudo systemctl daemon-reload

# Mount all entries in /etc/fstab
sudo mount -a

# Sleep before reboot
sleep 15
sudo reboot
