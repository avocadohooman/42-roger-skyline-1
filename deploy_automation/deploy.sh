#!/bin/bash

DEBIAN_FRONTEND=noninteractive

#Install Sudo

apt -y update
apt -y upgrade

apt-get install sudo

#Create user and add to sudo

sudo adduser --disabled-password --gecos "" gmolin
echo "gmolin:test1234" | chpasswd
sudo adduser gmolin sudo
sudo usermod -aG sudo gmolin

#Remvoe DHCP and create static IP

cp assets/staticip/interfaces /etc/network/interfaces

#Install SSH and configure it properly with fixed port

apt -y install openssh-server

rm -rf /etc/ssh/sshd_config
cp assets/sshd/sshd_config /etc/ssh/

sudo mkdir /home/gmolin/.ssh/
sudo mkdir /home/gmolin/.ssh/
sudo mkdir /home/gmolin/.ssh/
cat assets/ssh/id_rsa.pub > /home/gmolin/.ssh/authorized_keys

sudo service ssh restart
sudo service sshd restart
sudo service networking restart
sudo ifup enp0s3

#Install and configure Fail2Ban
yes "y" | sudo apt -y install fail2ban

cp assets/fail2ban/jail.local /etc/fail2ban/jail.local

cp assets/fail2ban/nginx-dos.conf /etc/fail2ban/filter.d
cp assets/fail2ban/portscan.conf /etc/fail2ban/filter.d

sudo service fail2ban restart

#Stop services we don't need
sudo systemctl disable console-setup.service
sudo systemctl disable keyboard-setup.service
sudo systemctl disable apt-daily.timer
sudo systemctl disable apt-daily-upgrade.timer
sudo systemctl disable syslog.service

#Copy and set up cron scripts for updating packages and detecting crontab changes

sudo apt-get -y install mailx
sudo apt-get -y install mailutils

cp -r assets/scripts/ ~/

{ crontab -l -u root; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -u root -
{ crontab -l -u root; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -u root -

{ crontab -l -u root; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -u root -

{ crontab -l -u gmolin; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -u gmolin -
{ crontab -l -u gmolin; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -u gmolin -

{ crontab -l -u gmolin; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -u gmolin -

{ crontab -e; echo '0 4 * * SUN sudo ~/scripts/update.sh'; } | crontab -e -
{ crontab -e; echo '@reboot sudo ~/scripts/update.sh'; } | crontab -e -

{ crontab -e; echo '0 0 * * * SUN ~/scripts/monitor.sh'; } | crontab -e -

#Install Apache

sudo apt install apache2 -y
sudo systemctl enable apache2
yes "y" | rm -rf /var/www/html/
cp -r assets/apache/ /var/www/html/

#Generate & Setup SSL
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=FI/ST=HEL/O=Hive/OU=Project-roger/CN=10.12.166.177" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

cp assets/ssl/ssl-params.conf /etc/apache2/conf-available/ssl-params.conf
sudo cp /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf.bak
rm /etc/apache2/sites-available/default-ssl.conf
cp assets/ssl/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
rm /etc/apache2/sites-available/000-default.conf
cp assets/ssl/000-default.conf /etc/apache2/sites-available/000-default.conf

sudo a2enmod ssl
sudo a2enmod headers
sudo a2ensite default-ssl
sudo a2enconf ssl-params

#Set up Firewall; Default DROP connections
sudo apt-get update && sudo apt-get upgrade
yes "y" | sudo apt-get install ufw
sudo ufw enable
sudo ufw allow 50683/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
sudo ssh service sshd restart

#Reboot Apache server, hopefully we have a live website
systemctl reload apache2
sudo fail2ban-client status

