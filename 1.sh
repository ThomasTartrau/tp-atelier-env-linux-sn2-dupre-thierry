#!/bin/bash

# Variables for the IP addresses of the machines
WEB=john@192.168.122.145
BDD=john@192.168.122.2

# Variable for the password of the user root
SUDOPASS="root"

ssh_jobs()
{
    # Add the public key to the authorized_keys file on the remote machine
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $WEB
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $BDD

    # Disable the password authentication on the remote machine and restart the sshd service
    echo $SUDOPASS | ssh -tt $WEB "sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
    echo $SUDOPASS | ssh -tt $BDD "sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
}

# Helper function to display the usage of the script
help()
{
    echo "Usage: ./script.sh [web|bdd|deploywp|undo]"
}

deploy_web()
{
    echo $SUDOPASS | ssh -tt $WEB "sudo -S apt update && sudo apt install apache2 libapache2-mod-php php php8.2-mysql php8.2-gd php8.2-imagick git -y"
}

deploy_bdd()
{
    # Install the MariaDB server on the remote machine
    echo $SUDOPASS | ssh -tt $BDD "sudo -S apt update && sudo apt install mariadb-server -y"

    # Allow the remote machine to connect to the database server
    echo $SUDOPASS | ssh -tt $BDD "sudo sed -i "s/bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf"

    # Find the path of the mysql command
    MYSQL=$(echo $SUDOPASS | ssh -tt $BDD "sudo -S which mysql")

    # SQL commands to create a database and a user
    # Thanks to https://github.com/fideloper/Vaprobash/blob/master/scripts/mariadb.sh
    Q1="CREATE DATABASE IF NOT EXISTS web;"
    Q2="CREATE USER '${WEB//@/\'@\'}' IDENTIFIED BY 'password';"
    Q3="GRANT ALL PRIVILEGES ON web.* TO '${WEB//@/\'@\'}';"
    Q4="FLUSH PRIVILEGES;"

    # Combine all the SQL commands into a single command
    SQL="${Q1}${Q2}${Q3}${Q4}"

    # Execute the SQL commands on the remote machine
    echo $SUDOPASS | ssh -tt $BDD "sudo -S $MYSQL -uroot -e \"$SQL\""
}

undo_all_the_work()
{
    # Remove the packages installed on the web server
    echo $SUDOPASS | ssh -tt $WEB "sudo -S apt remove apache2 libapache2-mod-php php php8.2-mysql php8.2-gd php8.2-imagick git -y && sudo apt autoremove -y && sudo apt autoclean && sudo rm -rf /var/www/html/"

    # Set the password authentication back to yes and restart the sshd service
    echo $SUDOPASS | ssh -tt $WEB "sudo -S sed -i 's/^#\?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
    echo $SUDOPASS | ssh -tt $BDD "sudo -S sed -i 's/^#\?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"

    # Remove the packages installed on the database server
    echo $SUDOPASS | ssh -tt $BDD "sudo -S apt remove mariadb-server -y && sudo apt autoremove -y && sudo apt autoclean"

    # Set the bind-address back to 127.0.0.1
    echo $SUDOPASS | ssh -tt $BDD "sudo sed -i "s/bind-address.*/bind-address = 127.0.0.1/" /etc/mysql/mariadb.conf.d/50-server.cnf"
}

# Check if the user has provided minimum 1 argument
if [ $# -eq 0 ]; then
    help
    exit 1
fi

# Execute the ssh_jobs function
ssh_jobs

case $1 in
    "web")
        deploy_web
        ;;
    "bdd")
        deploy_bdd
        ;;
    "deploywp")
        echo "Deploy WordPress"
        ;;
    "undo")
        undo_all_the_work
        ;;
    *)
        help
        ;;
esac