#!/bin/bash

# Local ssh public key
LOCAL_SSH_PUBLIC_KEY="~/.ssh/id_ed25519.pub"


help()
{
    echo "Usage: ./script.sh [web|bdd]"
}

Backup_BDD()
{
    MACHINES=$1
    SUDOPASS=$2
    MARIADB_USERNAME=$3
    MARIADB_PASSWORD=$4
    MYSQL="/usr/bin/mysql"
    LOCAL_BACKUP_DIR="/var/backups"
    DATE=$(date +%Y%m%d)
    BACKUP_DIRS=("/var/www/html" "/var/lib/mysql" "/etc/apache2")

    if [ -z "$BDD_MACHINES" ]; then
        echo "No bdd machines found exiting"
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
        
        # Connexion to the DB
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S mysql -u$MARIADB_USERNAME -p$MARIADB_PASSWORD -e 'SHOW DATABASES;'"

        # Creation of Backups dirs
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS |  sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        
        for dir in "${BACKUP_DIRS[@]}"; do
            # Make Backup of files
            ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
        done
    done
}

Backup_WEB()
{
    WEB_MACHINES=$1
    SUDOPASS=$2
    MYSQL="/usr/bin/mysql"
    LOCAL_BACKUP_DIR="/var/backups"
    DATE=$(date +%Y%m%d)
    BACKUP_DIRS=("/var/www/html" "/var/lib/mysql" "/etc/apache2")

    if [ -z "$WEB_MACHINES" ]; then
        echo "No web machines found exiting"
        exit 1
    fi

    if [ -z "$SUDOPASS" ]; then
        echo "No root password found exiting"
        exit 1
    fi

    for MACHINE in $WEB_MACHINES; do
        # Creation of Backups dirs
        ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS |  sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        
        for dir in "${BACKUP_DIRS[@]}"; do
            # Make Backup of files
            ssh -i $LOCAL_SSH_PUBLIC_KEY $MACHINE -tt "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
        done
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

        Backup_WEB "$WEB_MACHINES" "$SUDOPASS"
        ;;
    "bdd")
        BDD_MACHINES=$(./get_machines.sh bdd)

        if [ -z "$BDD_MACHINES" ]; then
            echo "No web machines found exiting"
            exit 1
        fi

        SUDOPASS=$(whiptail --passwordbox "Please enter your root password" 8 78 --title "Root Password" 3>&1 1>&2 2>&3)
        
        BDD_USERNAME=$(whiptail --inputbox "Please enter your DB username" 8 78 --title "Username" 3>&1 1>&2 2>&3)
        BDD_PASSWORD=$(whiptail --passwordbox "Please enter your DB password" 8 78 --title "Password" 3>&1 1>&2 2>&3)

        Backup_BDD "$BDD_MACHINES" "$SUDOPASS" "$BDD_USERNAME" "BDD_PASSWORD"
        ;;
esac