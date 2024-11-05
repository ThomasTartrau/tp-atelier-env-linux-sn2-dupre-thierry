#!/bin/bash

# Local ssh public key
LOCAL_SSH_PUBLIC_KEY="~/.ssh/id_ed25519.pub"

ssh_jobs()
{
    MACHINES=$1
    SUDOPASS=$2

    if [ -z "$MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    if [ -z "$SUDOPASS" ]; then
        echo "No root password found exiting"
        exit 1
    fi

    for MACHINE in $MACHINES; do
        # Add the public key to the authorized_keys file on the remote machine
        ssh-copy-id -i ~/.ssh/id_ed25519.pub $MACHINE
        # Disable the password authentication on the remote machine and restart the sshd service
        echo $SUDOPASS | ssh -tt $MACHINE "sudo -S sed -i 's/^#\?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"
    done
}

# Helper function to display the usage of the script
help()
{
    echo "Usage: ./script.sh [web|bdd|deploywp|all]"
}

deploy_web()
{
    MACHINES=$1
    SUDOPASS=$2

    if [ -z "$MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    if [ -z "$SUDOPASS" ]; then
        echo "No root password found exiting"
        exit 1
    fi

    for MACHINE in $MACHINES; do
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S apt update && sudo apt install apache2 ghostscript libapache2-mod-php php php-bcmath php-curl php-imagick php-intl php-json php-mbstring php-mysql php-xml php-zip -y && sudo systemctl start apache2 && sudo systemctl enable apache2"
    done
}

deploy_bdd()
{
    BDD_MACHINES=$1
    WEB_MACHINES=$2
    SUDOPASS=$3
    MARIADB_USERNAME=$4
    MARIADB_PASSWORD=$5
    MYSQL="/usr/bin/mysql"

    if [ -z "$BDD_MACHINES" ]; then
        echo "No bdd machines found exiting"
        exit 1
    fi

    if [ -z "$WEB_MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    if [ -z "$SUDOPASS" ]; then
        echo "No root password found exiting"
        exit 1
    fi

    if [ -z "$MARIADB_USERNAME" ]; then
        echo "No username found exiting"
        exit 1
    fi

    if [ -z "$MARIADB_PASSWORD" ]; then
        echo "No password found exiting"
        exit 1
    fi

    for MACHINE in $BDD_MACHINES; do
        # Install the MariaDB server on the remote machine
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S apt update && sudo apt install mariadb-server -y"

        # Allow the remote machine to connect to the database server
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf"

        # Commandes SQL pour créer une base de données, un utilisateur et accorder des privilèges
        Q1="CREATE DATABASE IF NOT EXISTS web;"
        WEB_MACHINES_SQL=()
        for WEB_MACHINE in $WEB_MACHINES; do
            WEB_MACHINE_IP=$(echo $WEB_MACHINE | cut -d'@' -f2)
            Q2="CREATE USER IF NOT EXISTS '${MARIADB_USERNAME}'@'${WEB_MACHINE_IP}' IDENTIFIED BY '${MARIADB_PASSWORD}';"
            Q3="GRANT ALL PRIVILEGES ON ${MARIADB_USERNAME}.* TO '${MARIADB_USERNAME}'@'${WEB_MACHINE_IP}';"
        
            WEB_MACHINES_SQL+=("${Q2} ${Q3}")
        done
        Q4="FLUSH PRIVILEGES;"
        SQL="${Q1} ${WEB_MACHINES_SQL[@]} ${Q4}"

        # Execute the SQL commands on the database server
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S $MYSQL -uroot -p$SUDOPASS -e \"$SQL\""

        # Restart the MariaDB service
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S systemctl restart mariadb"
    done
}

# Thanks to (https://github.com/jasewarner/wordpress-installer/blob/master/wordpress.sh)
deploy_wordpress()
{
    WEB_MACHINES=$1
    BDD_MACHINES=$2
    SUDOPASS=$3
    WP_USERNAME=$4
    WP_PASSWORD=$5
    WP_DBNAME="wordpress"

    if [ -z "$WEB_MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    if [ -z "$BDD_MACHINES" ]; then
        echo "No bdd machines found exiting"
        exit 1
    fi

    if [ -z "$SUDOPASS" ]; then
        echo "No root password found exiting"
        exit 1
    fi

    if [ -z "$WP_USERNAME" ]; then
        echo "No username found exiting"
        exit 1
    fi

    if [ -z "$WP_PASSWORD" ]; then
        echo "No password found exiting"
        exit 1
    fi

    FIRST_BDD_MACHINE=$(echo $BDD_MACHINES | cut -d' ' -f1)
    IP_BDD_MACHINE=$(echo $FIRST_BDD_MACHINE | cut -d'@' -f2)

    for MACHINE in $WEB_MACHINES; do
        # Download and extract the latest version of WordPress
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S apt install curl -y && cd /var/www/html/ && sudo curl -O https://wordpress.org/latest.tar.gz && sudo tar -xvf latest.tar.gz && sudo mv wordpress/* . && sudo rm -rf wordpress/ latest.tar.gz index.html"

        # Copy the wp-config-sample.php file to wp-config.php
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php"

        # Update the database details in the wp-config.php file
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S sed -i 's/database_name_here/$WP_DBNAME/g' /var/www/html/wp-config.php"
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S sed -i 's/username_here/$WP_USERNAME/g' /var/www/html/wp-config.php"
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S sed -i 's/password_here/$WP_PASSWORD/g' /var/www/html/wp-config.php"
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S sed -i 's/localhost/$IP_BDD_MACHINE/g' /var/www/html/wp-config.php"

        # Applying folder and file permissions
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S chown -R www-data:www-data /var/www/html/"
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S chmod -R 755 /var/www/html/"

        # Deploy WP database
        word_press_database "$BDD_MACHINES" "$MACHINE" "$SUDOPASS" "$WP_USERNAME" "$WP_PASSWORD" "$WP_DBNAME"
    done
}

word_press_database()
{
    BDD_MACHINES=$1
    WEB_MACHINE=$2
    SUDOPASS=$3
    WP_DBUSER=$4
    WP_DBPASS=$5
    WP_DBNAME=$6
    MYSQL="/usr/bin/mysql"

    MACHINE_IP=$(echo $MACHINE | cut -d'@' -f2)

    for MACHINE in $BDD_MACHINES; do
        MYSQL_VERSION=$(ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "mysql --version")
        IS_MYSQL=$(echo $MYSQL_VERSION | grep -c "mysql")

        if [ -z "$IS_MYSQL" ]; then
            BDD_MACHINES=($MACHINE)
            WEB_MACHINE=($WEB_MACHINE)
            deploy_bdd "$BDD_MACHINES" "$WEB_MACHINE" "$SUDOPASS"
        fi

        # SQL commands to create a database, user, and grant privileges
        Q1="CREATE DATABASE IF NOT EXISTS $WP_DBNAME;"
        Q2="CREATE USER IF NOT EXISTS '$WP_DBUSER'@'${MACHINE_IP}' IDENTIFIED BY '$WP_DBPASS';"
        Q3="GRANT ALL PRIVILEGES ON $WP_DBNAME.* TO '$WP_DBUSER'@'${MACHINE_IP}';"
        Q4="FLUSH PRIVILEGES;"
        SQL="${Q1} ${Q2} ${Q3} ${Q4}"

        # Execute the SQL commands on the database server
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S $MYSQL -uroot -p'$SUDOPASS' -e \"$SQL\""
        
        # Restart the MariaDB service
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S systemctl restart mariadb"
    done
}

# Check if the user has provided minimum 1 argument
if [ $# -eq 0 ]; then
    help
    exit 1
fi

case $1 in
    "web")
        WEB_MACHINES=$(./get_machines.sh web)

        if [ -z "$WEB_MACHINES" ]; then
            echo "No web machines found exiting"
            exit 1
        fi

        SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)

        ssh_jobs "$WEB_MACHINES" "$SUDOPASS"
        deploy_web "$WEB_MACHINES" "$SUDOPASS"
        ;;
    "bdd")
        BDD_MACHINES=$(./get_machines.sh bdd)

        if [ -z "$BDD_MACHINES" ]; then
            echo "No bdd machines found exiting"
            exit 1
        fi

        WEB_MACHINES=$(./get_machines.sh web)

        if [ -z "$WEB_MACHINES" ]; then
            echo "No web machines found exiting"
            exit 1
        fi

        SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)

        BDD_USERNAME=$(whiptail --inputbox "Please enter the mysql username" 8 78 --title "Mysql Username" 3>&1 1>&2 2>&3)
        BDD_PASSWORD=$(whiptail --passwordbox "Please enter mysql password" 8 78 --title "Mysql Password" 3>&1 1>&2 2>&3)

        ssh_jobs "$BDD_MACHINES" "$SUDOPASS"
        deploy_bdd "$BDD_MACHINES" "$WEB_MACHINES" "$SUDOPASS" "$BDD_USERNAME" "$BDD_PASSWORD"
        ;;
    "deploywp")
        WEB_MACHINES=$(./get_machines.sh web)

        if [ -z "$WEB_MACHINES" ]; then
            echo "No web machines found exiting"
            exit 1
        fi

        BDD_MACHINES=$(./get_machines.sh bdd)

        if [ -z "$BDD_MACHINES" ]; then
            echo "No bdd machines found exiting"
            exit 1
        fi

        SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)

        WP_USERNAME=$(whiptail --inputbox "Please enter the wordpress username" 8 78 --title "WP Username" 3>&1 1>&2 2>&3)
        WP_PASSWORD=$(whiptail --passwordbox "Please enter the wordpress password" 8 78 --title "WP Password" 3>&1 1>&2 2>&3)

        deploy_wordpress "$WEB_MACHINES" "$BDD_MACHINES" "$SUDOPASS" "$WP_USERNAME" "$WP_PASSWORD"
        ;;
    "all")

        WEB_MACHINES=$(./get_machines.sh web)

        if [ -z "$WEB_MACHINES" ]; then
            echo "No web machines found exiting"
            exit 1
        fi

        BDD_MACHINES=$(./get_machines.sh bdd)

        if [ -z "$BDD_MACHINES" ]; then
            echo "No bdd machines found exiting"
            exit 1
        fi

        SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)

        BDD_USERNAME=$(whiptail --inputbox "Please enter your username" 8 78 --title "Username" 3>&1 1>&2 2>&3)
        BDD_PASSWORD=$(whiptail --passwordbox "Please enter your password" 8 78 --title "Password" 3>&1 1>&2 2>&3)

        WP_USERNAME=$(whiptail --inputbox "Please enter your username" 8 78 --title "Username" 3>&1 1>&2 2>&3)
        WP_PASSWORD=$(whiptail --passwordbox "Please enter your password" 8 78 --title "Password" 3>&1 1>&2 2>&3)

        ssh_jobs "$WEB_MACHINES" "$SUDOPASS"
        ssh_jobs "$BDD_MACHINES" "$SUDOPASS"

        deploy_web "$WEB_MACHINES" "$SUDOPASS"
        deploy_bdd "$BDD_MACHINES" "$WEB_MACHINES" "$SUDOPASS" "$BDD_USERNAME" "$BDD_PASSWORD"
        deploy_wordpress "$WEB_MACHINES" "$BDD_MACHINES" "$SUDOPASS" "$WP_USERNAME" "$WP_PASSWORD"
        ;;
    *)
        help
        ;;
esac