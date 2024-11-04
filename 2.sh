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

# Informations pour la base de données
MARIADB_USERNAME="web"
MARIADB_PASSWORD="password"

# Mot de passe pour sudo
SUDOPASS="root"

IS_VAGRANT=true
DATE=$(date +%Y%m%d)  # Définition de la date

backup_remote() {
    if [ "$IS_VAGRANT" = true ]; then
        # Connexion à la base de données MySQL avec le mot de passe
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S mysql -u$MARIADB_USERNAME -p$MARIADB_PASSWORD -e 'SHOW DATABASES;'"

        # Création des répertoires de sauvegarde sur les serveurs Web et BDD
        vagrant ssh web -c "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        vagrant ssh bdd -c "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"

        # Sauvegarde des répertoires pour WEB et BDD
        for dir in "${BACKUP_DIRS[@]}"; do
            vagrant ssh web -c "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
            vagrant ssh bdd -c "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
        done

    else
        # Connexion SSH et accès MySQL à distance
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "sudo -S mysql -u$MARIADB_USERNAME -p$MARIADB_PASSWORD -e 'SHOW DATABASES;'"

        echo "Connexion SSH et Création de la sauvegarde des machines distantes"

        # Création des répertoires et sauvegarde
        echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"
        echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "echo $SUDOPASS | sudo -S mkdir -p $LOCAL_BACKUP_DIR"

        for dir in "${BACKUP_DIRS[@]}"; do
            echo $SUDOPASS | ssh -tt $WEB_USERNAME@$PUBLIC_WEB_IP "sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
            echo $SUDOPASS | ssh -tt $BDD_USERNAME@$PUBLIC_BDD_IP "echo $SUDOPASS | sudo -S tar czvf $LOCAL_BACKUP_DIR/$(basename $dir)_$DATE.tar.gz $dir"
        done
    fi
}

backup_remote

echo "Fin de la sauvegarde"
