#!/bin/bash

# Make a shared folder called "shared" in this directory
mkdir -p shared

# Make a vagrant file 
touch Vagrantfile

# Edit the vagrant file
cat <<EOF > Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :
 
Vagrant.configure ("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.synced_folder "shared", "/home/vagrant/shared"
  config.vm.define "master" do |master|
    master.vm.network "private_network", ip: "192.168.56.49"
    master.vm.hostname = "master"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = "1"
    end

    # Provisioning script for the master node
    master.vm.provision "shell", inline: <<-SHELL
      sudo apt-get -y update

      # Create a new group 'admin', add users into this group
      sudo groupadd admin
      sudo useradd -m -G sudo -s /bin/bash altschool
      echo "altschool:198991" | sudo chpasswd
      sudo usermod -aG admin altschool
      sudo usermod -aG admin vagrant

      # Allow 'altschool' user root privileges
      echo "altschool ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

      # Set up permissions so that we can use sudo without entering our password each time
      echo "%admin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin

      # Make an ssh key for the altschool user(without a passphrase)
      sudo -u altschool ssh-keygen -t ed25519 -N "" -f /home/altschool/.ssh/id_ed25519 -C "altschool" -q

      # Permission for the .ssh directory
      chmod 600 /home/altschool/.ssh/id_ed25519
      chmod 664 /home/altschool/.ssh/id_ed25519.pub

      # Copy the public key to the shared directory
      sudo cp /home/altschool/.ssh/id_ed25519.pub /home/vagrant/shared/id_ed25519.pub || true

      # Install lamp stack
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql 

      # Enable lamp stack
      sudo systemctl enable apache2 || true
      sudo systemctl enable mysql || true

      # Start lamp stack
      sudo systemctl start apache2 || true
      sudo systemctl start mysql || true

      # Secure mysql installation automatically
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password 1991'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password 1991'

      # Make a test php page to render lamp stack
      sudo echo "<?php phpinfo(); ?>" > /var/www/html/index.php

      # Make a /mnt/altschool directory
      sudo mkdir -p /mnt/altschool

      # Make a sample.txt file in /mnt/altschool
      sudo touch /mnt/altschool/master_data.txt

      # Make a sample content in master_data.txt
      sudo echo "Hello world ,no war please" > /mnt/altschool/master_data.txt

      # Copy the content of the /mnt/altschool to the shared folder
      sudo cp -r /mnt/altschool/* /home/vagrant/shared || true

      # Allow touch command to create the .txt file
      touch "/home/vagrant/shared/ps_master.txt"

      # Change the permissions for the .txt file
      chmod 644 /home/vagrant/shared/ps_master.txt 

      # Change the ownership of a directory and its contents
      chown -R altschool:admin /home/vagrant/shared/ps_master.txt

    SHELL
  end

  config.vm.define "slave" do |slave|
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.synced_folder "shared", "/home/vagrant/shared"
    slave.vm.network "private_network", ip: "192.168.56.50"
    slave.vm.hostname = "slave"
    slave.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = "1"
    end

    # Provisioning script for the slave node
    slave.vm.provision "shell", inline: <<-SHELL
     sudo apt-get -y update

      # Create a new group called 'admin', add users into this group
      sudo groupadd admin
      sudo useradd -m -G sudo -s /bin/bash altschool
      echo "altschool:198991" | sudo chpasswd
      sudo usermod -aG admin altschool
      sudo usermod -aG admin vagrant

      # Grant 'altschool' user root privileges
      echo "altschool ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers

      # Set up permissions so that we can use sudo without entering our password each time
      echo "%admin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin

      # Create the .ssh directory if it doesn't exist
      sudo -u altschool mkdir -p /home/altschool/.ssh || true

      # Copy the public key from the shared directory to the ~/vagrant/.ssh/authorized_keys
      sudo cp /home/vagrant/shared/id_ed25519.pub /home/altschool/.ssh/authorized_keys || true

      # Make /mnt/altschool/ directory
      sudo mkdir -p /mnt/altschool/

      # Permission for the /mnt/altschool/ directory
      sudo chmod 766 /mnt/altschool/

      # Imagine 'altschool' is the owner of the directory
      #sudo chown -R altschool:admin /mnt/altschool/

      # Copy the content of the shared folder to /mnt/altschool/ directory
      sudo cp -r /home/vagrant/shared/master_data.txt* /mnt/altschool/ || true

      # Install lamp stack
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y apache2 mysql-server php libapache2-mod-php php-mysql

      # Enable lamp stack
      sudo systemctl enable apache2 || true
      sudo systemctl enable mysql || true

      # Start lamp stack
      sudo systemctl start apache2 || true
      sudo systemctl start mysql || true

      # Secure mysql installation automatically
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password 198991'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password 198991'

      # Make a test php page to render lamp stack
      sudo echo "<?php phpinfo(); ?>" > /var/www/html/index.php

      # Specify the directory path and the file name
      directory_path="/home/vagrant/shared/"
      file_name="slave.txt"

      # Use the touch command to create the file
      touch "/home/vagrant/shared/slave.txt"

      # Copy the content of the shared folder to /mnt/altschool/ directory
      sudo cp -r /home/vagrant/shared/slave_data.txt* /mnt/altschool/ || true

      # Change the permissions for the file
      chmod 644 /home/vagrant/shared/slave.txt 

      # Change the ownership of the directory and its contents
      chown -R altschool:admin /home/vagrant/shared/slave.txt 

    SHELL
  end

  # Define the Ubuntu 22.04 box for the load balancer (Nginx)
  config.vm.define "loadbalancer" do |lb|
    lb.vm.box = "bento/ubuntu-22.04"
    lb.vm.network "private_network", type: "static", ip: "192.168.56.52"
    lb.vm.provider "virtualbox" do |vb|
      vb.memory = 1024 # 1GB RAM
      vb.cpus = 1
    end

    # provisioning script for the load balancer 
    lb.vm.provision "shell", inline: <<-SHELL
     
      # Install update
      sudo apt-get -y update

      # Create a load balancer with nginx
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y nginx
      
      # Install UFW (Uncomplicated Firewall)
      DEBIAN_FRONTEND=noninteractive sudo apt-get install -y ufw

      # Allow HTTP and HTTPS traffic
      sudo ufw allow http
      sudo ufw allow https
      sudo ufw --force enable

      # Enable Nginx to start on boot
      sudo systemctl enable nginx

      # Start Nginx
      sudo systemctl start nginx

      # Remove the default nginx configuration
      sudo rm /etc/nginx/sites-available/default
      sudo rm /etc/nginx/sites-enabled/default

      # Reload Nginx to apply changes
      sudo systemctl reload nginx

      # Create a new Nginx configuration file with the load balancing configuration
      echo "upstream backend {" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "    server 192.168.56.49 weight=3;" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "    server 192.168.56.50 weight=1;" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "}" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "server {" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "    listen 80;" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "    location / {" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "        proxy_pass http://backend;" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "    }" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf
      echo "}" | sudo tee -a /etc/nginx/sites-available/loadbalancer.conf

      # Make a page to render the load balancer
      sudo echo "<h1>Load Balancer</h1>" > /var/www/html/index.html || true

      # Symlink the nginx configuration
      # sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

      # Make a symbolic link to enable the configuration
      sudo ln -s /etc/nginx/sites-available/loadbalancer.conf /etc/nginx/sites-enabled/

      # Test Nginx configuration for syntax errors
      sudo nginx -t

      # Kindly Reload Nginx
      sudo systemctl reload nginx || true
    SHELL
  end
end
EOF

# start vagrant
vagrant up
