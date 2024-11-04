#!/bin/bash

PUBLIC_WEB_IP="192.168.121.3"
PRIVATE_WEB_IP="192.168.56.10"
WEB_USERNAME="john"

PUBLIC_BDD_IP="192.168.121.81"
PRIVATE_BDD_IP="192.168.56.11"
BDD_USERNAME="john"

# Répertoires à sauvegarder
BACKUP_DIRS=("/var/www/html" "/var/lib/mysql" "/etc/apache2")
# Répertoire de sauvegarde
LOCAL_BACKUP_DIR="/var/backups"

# BDD
MARIADB_USERNAME="web"
MARIADB_PASSWORD="password"

SUDOPASS="root"

IS_VAGRANT=true


backup_remote() {
    if [ "$IS_VAGRANT" = true ]; then


        LISTEBDD= vagrant ssh bdd "echo 'show databases' | ${MARIADB_USERNAME} -u backup --password=< ${MARIADB_PASSWORD} >"

        echo "$LISTEBDD"

        vagrant ssh web -c "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        vagrant ssh web -c "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        # Sauvegarde des répertoires de WEB
        for dir in ${BACKUP_DIRS[@]}; do
            vagrant ssh web -c "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done

        # Sauvegarde des répertoires de BDD
        for dir in ${BACKUP_DIRS[@]}; do
            vagrant ssh bdd -c "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done


    else
        LISTEBDD=$( echo 'show databases' | $MARIADB_USERNAME -u backup --password=< $MARIADB_PASSWORD >)

        echo "$LISTEBDD"

        echo "Connexion SSH et Création de la sauvegarde des machines distantes"

        # Création du répertoire de sauvegarde sur WEB
        ssh -i "$SSH_KEY" "$USER@$WEB" "sudo mkdir -p $LOCAL_BACKUP_DIR"
        ssh -i "$SSH_KEY" "$USER@$WEB" "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        # Création du répertoire de sauvegarde sur BDD
        ssh -i "$SSH_KEY" "$USER@$WEB" "sudo mkdir -p $LOCAL_BACKUP_DIR"
        ssh -i "$SSH_KEY" "$USER@$WEB" "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        # Sauvegarde des répertoires de WEB
        for dir in ${BACKUP_DIRS[@]}; do
            ssh -i "$SSH_KEY" "$USER@$WEB" "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done

        # Sauvegarde des répertoires de BDD
        for dir in ${BACKUP_DIRS[@]}; do
            ssh -i "$SSH_KEY" "$USER@$BDD" "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done

        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo mkdir -p $LOCAL_BACKUP_DIR"
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_BDD_IP "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_WEB_IP "sudo mkdir -p $LOCAL_BACKUP_DIR"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $DIR)_^$DATE.tar.gz $DIR"

        for rule in "${web_rules[@]}"; do
            echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done
        for rule in "${bdd_rules[@]}"; do
            echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $DIR"
        done
    fi
}

backup_remote

echo "Fin de la sauvegarde"