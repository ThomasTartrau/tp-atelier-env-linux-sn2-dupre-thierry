#!/bin/bash

# Local ssh public key
LOCAL_SSH_PUBLIC_KEY="~/.ssh/id_ed25519.pub"

Backup_BDD()
{
    BDD_MACHINES=$(./get_machines.sh bdd)
    SUDOPASS=$3
    MARIADB_USERNAME=$4
    MARIADB_PASSWORD=$5
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
    WEB_MACHINES=$(./get_machines.sh web)    
    SUDOPASS=$3
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

Backup_WEB
Backup_BDD

echo "Fin de la sauvegarde"
