#!/bin/bash

# Variables for the IP addresses of the machines
PUBLIC_WEB_IP="192.168.121.3"
PRIVATE_WEB_IP="192.168.56.10"
WEB_USERNAME="john"

PUBLIC_BDD_IP="192.168.121.81"
PRIVATE_BDD_IP="192.168.56.11"
BDD_USERNAME="john"

# Variable for the password of the user root
SUDOPASS="root"

# BDD
MARIADB_USERNAME="web"
MARIADB_PASSWORD="password"

# WordPress
WP_DBNAME="wordpress"
WP_DBUSER="wordpress"
WP_DBPASS="password"

IS_VAGRANT=true

ssh_jobs()
{
    # Add the public key to the authorized_keys file on the remote machine
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $WEB_USERNAME@$PUBLIC_WEB_IP
    ssh-copy-id -i ~/.ssh/id_ed25519.pub $BDD_USERNAME@$PUBLIC_BDD_IP

    if [ "$IS_VAGRANT" = true ]; then
        # Disable the password authentication on the remote machine and restart the sshd service
        vagrant ssh web -c "echo $SUDOPASS | sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
    else
        # Disable the password authentication on the remote machine and restart the sshd service
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
    fi
}

# Helper function to display the usage of the script
help()
{
    echo "Usage: ./script.sh [web|bdd|deploywp|all|undo]"
}

deploy_web()
{
    if [ "$IS_VAGRANT" = true ]; then
        vagrant ssh web -c "echo $SUDOPASS | sudo -S apt update && sudo apt install apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y"
    else
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S apt update && sudo apt install apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y"
    fi
}

deploy_bdd()
{
    if [ "$IS_VAGRANT" = true ]; then
        # Install the MariaDB server on the remote machine
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S apt update && sudo apt install mariadb-server -y"
        
        # Allow the remote machine to connect to the database server
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf"

        # Find the path of the mysql command
        MYSQL=$(vagrant ssh bdd -c "echo $SUDOPASS | sudo -S which mysql")

        # SQL commands to create a database, user, and grant privileges
        
        Q1="CREATE DATABASE IF NOT EXISTS web;"
        Q2="CREATE USER IF NOT EXISTS '${MARIADB_USERNAME}'@'${PRIVATE_WEB_IP}' IDENTIFIED BY '${MARIADB_PASSWORD}';"
        Q3="GRANT ALL PRIVILEGES ON ${MARIADB_USERNAME}.* TO '${MARIADB_USERNAME}'@'${PRIVATE_WEB_IP}';"
        Q4="FLUSH PRIVILEGES;"

        # Combine all the SQL commands into a single command
        SQL="${Q1} ${Q2} ${Q3} ${Q4}"

        # Execute the SQL commands on the database server
        vagrant ssh bdd -c "echo '$SUDOPASS' | sudo -S mysql -uroot -p'$SUDOPASS' -e \"$SQL\""

        # Restart the MariaDB service
        vagrant ssh bdd -c "echo $SUDOPASS | sudo systemctl restart mariadb"
    else
        # Install the MariaDB server on the remote machine
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo -S apt update && sudo apt install mariadb-server -y"

        # Allow the remote machine to connect to the database server
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo -S sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf"

        # Find the path of the mysql command
        MYSQL=$(echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo -S which mysql")

        # SQL commands to create a database, user, and grant privileges
        Q1="CREATE DATABASE IF NOT EXISTS web;"
        Q2="CREATE USER IF NOT EXISTS '${MARIADB_USERNAME}'@'${PRIVATE_WEB_IP}' IDENTIFIED BY '${MARIADB_PASSWORD}';"
        Q3="GRANT ALL PRIVILEGES ON ${MARIADB_USERNAME}.* TO '${MARIADB_USERNAME}'@'${PRIVATE_WEB_IP}';"
        Q4="FLUSH PRIVILEGES;"

        # Combine all the SQL commands into a single command
        SQL="${Q1} ${Q2} ${Q3} ${Q4}"

        # Execute the SQL commands on the database server
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "echo '$SUDOPASS' | sudo -S mysql -uroot -p'$SUDOPASS' -e \"$SQL\""
    
        # Restart the MariaDB service
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo systemctl restart mariadb"
    fi
}

# Thanks to (https://github.com/jasewarner/wordpress-installer/blob/master/wordpress.sh)
deploy_wordpress()
{
    
    if [ "$IS_VAGRANT" = true ]; then
        # Download and extract the latest version of WordPress
        vagrant ssh web -c "echo $SUDOPASS | sudo apt install curl -y && cd /var/www/html/ && sudo curl -O https://wordpress.org/latest.tar.gz && sudo tar -xvf latest.tar.gz && sudo mv wordpress/* . && sudo rm -rf wordpress/ latest.tar.gz index.html"

        # Copy the wp-config-sample.php file to wp-config.php
        vagrant ssh web -c "echo $SUDOPASS | sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php"

        # Update the database details in the wp-config.php file
        vagrant ssh web -c "echo $SUDOPASS | sudo sed -i 's/database_name_here/$WP_DBNAME/g' /var/www/html/wp-config.php"
        vagrant ssh web -c "echo $SUDOPASS | sudo sed -i 's/username_here/$WP_DBUSER/g' /var/www/html/wp-config.php"
        vagrant ssh web -c "echo $SUDOPASS | sudo sed -i 's/password_here/$WP_DBPASS/g' /var/www/html/wp-config.php"
        vagrant ssh web -c "echo $SUDOPASS | sudo sed -i 's/localhost/$PRIVATE_BDD_IP/g' /var/www/html/wp-config.php"

        # Applying folder and file permissions
        vagrant ssh web -c "echo $SUDOPASS | sudo chown -R www-data:www-data /var/www/html/"
        vagrant ssh web -c "echo $SUDOPASS | sudo chmod -R 755 /var/www/html/"

        # Deploy WP database
        word_press_database
    else
        # Download and extract the latest version of WordPress
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo apt install curl -y && cd /var/www/html/ && sudo curl -O https://wordpress.org/latest.tar.gz && sudo tar -xvf latest.tar.gz && sudo mv wordpress/* . && sudo rm -rf wordpress/ latest.tar.gz index.html"

        # Copy the wp-config-sample.php file to wp-config.php
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php"

        # Update the database details in the wp-config.php file
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo sed -i 's/database_name_here/$WP_DBNAME/g' /var/www/html/wp-config.php"
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo sed -i 's/username_here/$WP_DBUSER/g' /var/www/html/wp-config.php"
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo sed -i 's/password_here/$WP_DBPASS/g' /var/www/html/wp-config.php"
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo sed -i 's/localhost/$PRIVATE_BDD_IP/g' /var/www/html/wp-config.php"

        # Applying folder and file permissions
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo chown -R www-data:www-data /var/www/html/"
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo chmod -R 755 /var/www/html/"

        # Deploy WP database
        word_press_database
    fi
}

word_press_database()
{
    if [ "$IS_VAGRANT" = true ]; then
        MYSQL=$(vagrant ssh bdd -c "echo $SUDOPASS | sudo -S which mysql")

        if [ -z "$MYSQL" ]; then
            deploy_bdd
        fi

        # SQL commands to create a database, user, and grant privileges
        Q1="CREATE DATABASE IF NOT EXISTS $WP_DBNAME;"
        Q2="CREATE USER IF NOT EXISTS '$WP_DBUSER'@'${PRIVATE_WEB_IP}' IDENTIFIED BY '$WP_DBPASS';"
        Q3="GRANT ALL PRIVILEGES ON $WP_DBNAME.* TO '$WP_DBUSER'@'${PRIVATE_WEB_IP}';"
        Q4="FLUSH PRIVILEGES;"

        # Combine all the SQL commands into a single command
        SQL="${Q1} ${Q2} ${Q3} ${Q4}"

        # Execute the SQL commands on the database server
        vagrant ssh bdd -c "echo '$SUDOPASS' | sudo -S mysql -uroot -p'$SUDOPASS' -e \"$SQL\""
    else
        MYSQL=$(echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo -S which mysql")

        if [ -z "$MYSQL" ]; then
            deploy_bdd
        fi

        # SQL commands to create a database, user, and grant privileges
        Q1="CREATE DATABASE IF NOT EXISTS $WP_DBNAME;"
        Q2="CREATE USER IF NOT EXISTS '$WP_DBUSER'@'${PRIVATE_WEB_IP}' IDENTIFIED BY '$WP_DBPASS';"
        Q3="GRANT ALL PRIVILEGES ON $WP_DBNAME.* TO '$WP_DBUSER'@'${PRIVATE_WEB_IP}';"
        Q4="FLUSH PRIVILEGES;"

        # Combine all the SQL commands into a single command
        SQL="${Q1} ${Q2} ${Q3} ${Q4}"

        # Execute the SQL commands on the database server
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "echo '$SUDOPASS' | sudo -S mysql -uroot -p'$SUDOPASS' -e \"$SQL\""
    fi 
}

undo_all_the_work()
{
    if [ "$IS_VAGRANT" = true ]; then
        # WEB & WordPress
        # Remove the packages installed on the web server
        vagrant ssh web -c "echo $SUDOPASS | sudo -S apt remove apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y -y && sudo apt autoremove -y && sudo apt autoclean && sudo rm -rf /var/www/html/"


        # BDD
        # Remove the packages installed on the database server
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S apt remove mariadb-server -y && sudo apt autoremove -y && sudo apt autoclean"

        # Set the bind-address back to 127.0.0.1
        vagrant ssh bdd -c "echo '$SUDOPASS' | sudo -S sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf"
    else
        # WEB & WordPress
        # Remove the packages installed on the web server
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S apt remove apache2 libapache2-mod-php php php8.2-mysql php8.2-gd php8.2-imagick git -y && sudo apt autoremove -y && sudo apt autoclean && sudo rm -rf /var/www/html/"

        # Set the password authentication back to yes and restart the sshd service
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S sed -i 's/^#\?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo -S sed -i 's/^#\?PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && sudo systemctl restart sshd"


        # BDD
        # Remove the packages installed on the database server
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo -S apt remove mariadb-server -y && sudo apt autoremove -y && sudo apt autoclean"

        # Set the bind-address back to 127.0.0.1
        echo "$SUDOPASS" | ssh -tt "$BDD_USERNAME@$PUBLIC_BDD_IP" "sudo -S sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mariadb.conf.d/50-server.cnf"
    fi
}

# Check if the user has provided minimum 1 argument
if [ $# -eq 0 ]; then
    help
    exit 1
fi

# Execute the ssh_jobs function
if !($IS_VAGRANT); then
    ssh_jobs
fi

case $1 in
    "web")
        deploy_web
        ;;
    "bdd")
        deploy_bdd
        ;;
    "deploywp")
        deploy_wordpress
        ;;
    "all")
        deploy_web
        deploy_bdd
        deploy_wordpress
        ;;
    "undo")
        undo_all_the_work
        ;;
    *)
        help
        ;;
esac