#!/bin/bash

DEBIAN_FRONTEND=noninteractive

apt -y update
apt -y upgrade

#Create user and add to sudo

useradd -p $(openssl passwd -1 password) gmolin
adduser gmolin sudo

#Remvoe DHCP and create static IP

sudo rm /etc/network/interfaces
cp assets/static/interfaces /etc/network/interfaces

#Install SSH and configure it properly with fixed port

apt -y install openssh-server

rm -rf /etc/ssh/sshd_config
cp assets/sshd/sshd_config /etc/ssh/
yes "y" | ssh-keygen -q -N "" > /dev/null
mkdir ~/.ssh
cat assets/ssh/id_rsa.pub > ~/.ssh/authorized_keys

service sshd restart

#Install and configure Fail2Ban
apt -y install fail2ban

rm -rf /etc/fail2ban/jail.local
cp assets/fail2ban/jail.local /etc/fail2ban/

cp assets/fail2ban/nginx-dos.conf /etc/fail2ban/filter.d
cp assets/fail2ban/portscan.conf /etc/fail2ban/filter.d

service fail2ban restart

#Copy and set up cron scripts for updating packages and detecting crontab changes

sudo apt -y install mailx
sudo apt install mailutils

cp -r assets/scripts ~/
{ crontab -e; echo '0 4 * * 7 sudo ~/update.sh'; } | crontab -e 
{ crontab -e; echo '@reboot sudo ~/update.sh'; } | crontab -e

{ crontab -e; echo '@midnight sudo ~/monitor.sh'; } | crontab -e

#Install Apache

sudo apt install apache2 -y
sudo systemctl enable apache2
rm -rf /var/www/html/*
cp assets/apache/index.apache-debian.html /var/www/html/

#Generate & Setup SSL
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=FI/ST=HEL/O=Hive/OU=Project-roger/CN=10.12.166.177" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

cp assets/ssl/ssl-params.conf /etc/apache2/conf-available/ssl-params.conf
rm /etc/apache2/sites-available/default-ssl.conf
cp assets/ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl
sudo a2enconf ssl-params

#Set up Firewall; Default DROP connections
ufw enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 50683
ufw allow 443
ufw allow 80
ufw allow 'Nginx Full'
ufw reload

#Reboot Apache server, hopefully we have a live website
systemctl reload apache2
